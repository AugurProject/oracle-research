// SPDX-License-Identifier: UNICENSE
pragma solidity 0.8.30;

import { IOpenOracle } from './IOpenOracle.sol';

interface IERC20 {
	function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
	function approve(address _spender, uint256 _value) public returns (bool success);
	function transfer(address _to, uint256 _value) public returns (bool success);
	function balanceOf(address _owner) public view returns (uint256 balance);
	function totalSupply() public view returns (uint256);
	function mint(uint256 amount) public;
	function burn(uint256 amount) public;
}

interface Zoltar {
	function hasForked();
	function migrateREP(uint192 universeId, uint256 amount);
}

struct SecurityVault {
	uint256 securityBondAllowance;
	uint256 repDepositShare;
	uint256 feeAccumulator;
}

enum MarketOutcome {
	Invalid,
	Yes,
	No,
}

enum PriceQueryAction {
	WithdrawRep,
	SetSecurityBondAllowance,
	Liquidate,
}

struct PendingPriceQuery {
	PriceQueryAction priceQueryAction;
	uint256 amount;
	address targetVaultAddress;
	address callerVaultAddress;
}

uint256 constant MIGRATION_TIME = 2 months;
uint256 constant AUCTION_TIME = 1 weeks;

// fees
uint256 constant FEE_DIVISOR = 10000;
uint256 constant MIN_FEE = 200;
uint256 constant FEE_SLOPE1 = 200;
uint256 constant FEE_SLOPE2 = 600;
uint256 constant FEE_DIP = 80;
uint256 constant RAY = 10 ** 27;

function rpow(uint256 x, uint256 n, uint256 baseUnit) internal pure returns (uint256 z) {
	z = n % 2 != 0 ? x : baseUnit;
	for (n /= 2; n != 0; n /= 2) {
		x = (x * x) / baseUnit;
		if (n % 2 != 0) {
			z = (z * x) / baseUnit;
		}
	}
}

contract SecurityPool {
	Question public question;
	IOpenOracle public openOracle;
	Zoltar public zoltar;
	uint256 public securityBondAllowance;
	uint256 public ethAmountForCompleteSets;
	uint256 public migratedRep;
	uint256 public repAtFork;
	uint256 public securityMultiplier;
	
	uint256 public cumulativeFeePerAllowance
	uint256 public lastUpdatedFeeAccumulator;
	uint256 public currentPerSecondFee;

	bool public forkTriggeredTimestamp;

	mapping(address => SecurityVault) public securityVaults;
	mapping(uint256 => PendingPriceQuery) public pendingPriceQueries;
	
	SecurityPool[3] public children;
	SecurityPool public parent;
	
	uint256 public truthAuctionStarted;
	bool public frozen;
	
	IERC20 public completeSet;
	CustomizedEasyAuction public auction;
	IERC20 public repToken;

	constructor(IERC20 repToken, SecurityPool parent, Zoltar zoltar, IOpenOracle openOracle, Question question, uint256 securityMultiplier, uint256 startingFee) {
		this.repToken = repToken;
		this.question = question;
		this.securityMultiplier = securityMultiplier;
		this.openOracle = openOracle;
		this.zoltar = zoltar;
		this.parent = parent;
		this.currentPerSecondFee = startingFee;
		if (this.parent === address(0x0)) { // origin universe never does auction
			this.truthAuctionStarted = 1;
			this.frozen = false;
		} else {
			this.frozen = true;
			this.auction = new CustomizedEasyAuction(); // craete auction instance that can start receive orders right away
		}
	}

	function updateFee() {
		uint256 timeDelta = block.timestamp - lastUpdatedFeeAccumulator;
		if (timeDelta == 0) return;
		uint256 retentionFactor = rpow(this.currentPerSecondFee, timeDelta, RAY);
		uint256 newEthAmountForCompleteSets = (this.ethAmountForCompleteSets * retentionFactor) / RAY;

		uint256 feesAccrued = this.ethAmountForCompleteSets - newEthAmountForCompleteSets;
		this.ethAmountForCompleteSets = newEthAmountForCompleteSets;
		if (completeSetsMinted > 0) {
			cumulativeFeePerAllowance += (feesAccrued * RAY) / newEthAmountForCompleteSets;
		}

		this.lastUpdatedFeeAccumulator = block.timestamp;
		uint256 utilization = this.ethAmountForCompleteSets * 100 / this.securityBondAllowance;
		if (utilization < FEE_DIP) {
			this.currentPerSecondFee = MIN_FEE + utilization * FEE_SLOPE1;
		} else {
			this.currentPerSecondFee = MIN_FEE + FEE_DIP * FEE_SLOPE1 + utilization * FEE_SLOPE2;
		}
	}

	function claimFees(address vault) external {
		updateFee();
		uint256 deltaIndex = cumulativeFeePerShare - securityVaults[vault].feeAccumulator;
		uint256 fees = (securityVaults[vault].securityBondAllowance * deltaIndex) / RAY;
		securityVaults[vault] = cumulativeFeePerShare;
		if (fees > 0) { //TODO, we probably want that this can never fail?
			(bool sent, bytes memory data) = payable(vault).call{value: fees}("");
        	require(sent, "Failed to send Ether");
		}
	}

	function requestRepEthPriceAndPerformAction(PriceQueryAction priceQueryAction, uint256 amount, address targetVaultAddress, address: callerVaultAddress) {
		// allow only one pending request, otherwise join to old request?
		// allow also using just resolving reports?
		address callbackContract = address(this);
        bytes4 callbackSelector = this.openOracleReportPrice;
		uint256 priceQueryId = this.openOracle.createReportInstance(...);
		pendingPriceQueries[priceQueryId] = {
			priceQueryAction: priceQueryAction,
			amount: amount,
			callerVaultAddress: callerVaultAddress,
			targetVaultAddress: targetVaultAddress,
		}
	}

	function openOracleReportPrice(uint256 callbackSelector, uint256 reportId, uint256 price, uint256 settlementTimestamp, address token1, address token2) {
		if (this.zoltar.hasForked()) return;
		if (this.frozen) return;
		require(msg.sender === address(this.openOracle), 'Only Open Oracle can report');
		require(pendingPriceQueries[reportId] > 0, 'Not a pending query');
		require(settlementTimestamp < block.timestamp + 6000, 'Settled too long ago');
		// check that the request is not too old?

		if (pendingPriceQueries[reportId].priceQueryAction === PriceQueryAction.WithdrawRep) {
			performWithdrawRep(pendingPriceQueries[reportId], price);
		}
		else if (pendingPriceQueries[reportId].priceQueryAction === PriceQueryAction.SetSecurityBondAllowance) {
			pendingMintBonds(pendingPriceQueries[reportId], price);
		}
		else if (pendingPriceQueries[reportId].priceQueryAction === PriceQueryAction.Liquidate) {
			pendingLiquidation(pendingPriceQueries[reportId], price);
		}
		return
	}
	////////////////////////////////////////
	// withdrawing rep
	////////////////////////////////////////

	function initiateWithdrawRep(uint256 amount)  {
		require(!this.zoltar.hasForked(), 'already forked');
		require(!this.frozen, 'system frozen');
		requestRepEthPriceAndPerformAction(PriceQueryAction.WithdrawRep, amount, msg.sender, msg.sender);
	}

	function performWithdrawRep(PendingPriceQuery priceQuery, uint256 price) internal {
		require(!this.zoltar.hasForked(), 'already forked');
		require(!this.frozen, 'system frozen');
		// todo, check if price allows this for this vault + whole protocol
		uint256 repAmount = amount * this.migratedRep / repToken.balanceOf(this);
		securityVaults[msg.sender].repDepositShare -= amount;
		repToken.transfer(address(this), repAmount);
	}
	
	function depositRep(uint256 amount) {
		require(!this.zoltar.hasForked(), 'already forked');
		require(!this.frozen, 'system frozen');
		uint256 repAmount = amount * repToken.balanceOf(this) / this.migratedRep;
		securityVaults[msg.sender].repDepositShare += amount;
		repToken.transferFrom(msg.sender, address(this), repAmount);
	}

	////////////////////////////////////////
	// liquidating vault
	////////////////////////////////////////

	function initiateLiquidation(address vaultToLiquidate) {
		require(!this.zoltar.hasForked(), 'already forked');
		require(!this.frozen, 'system frozen');
		requestRepEthPriceAndPerformAction(PriceQueryAction.Liquidate, amount, msg.sender, vaultToLiquidate);
	}
	//price = (amount1 * PRICE_PRECISION) / amount2;
	// price = REP * PRICE_PRECISION / ETH
	// liquidation moves share of debt and rep to another pool which need to remain non-liquidable
	// this is currently very harsh, as we steal all the rep and debt from the pool
	function performLiquidation(PendingPriceQuery priceQuery, uint256 price) internal {
		claimFees(priceQuery.targetVaultAddress);
		claimFees(priceQuery.callerVaultAddress);
		//TODO, add calculation that repshares are not rep directly, use: / this.migratedRep * repToken.balanceOf(this)

		uint256 vaultsSecurityBondAllowance = securityVaults[priceQuery.targetVaultAddress].securityBondAllowance;
		uint256 vaultsRepDeposit = securityVaults[priceQuery.targetVaultAddress].repDepositShare;
		require(vaultsSecurityBondAllowance * this.securityMultiplier * PRICE_PRECISION > vaultsRepDeposit * price, 'vault need to be liquidable');
		
		uint256 debtToMove = priceQuery.amount > securityVaults[priceQuery.callerVaultAddress].securityBondAllowance ? securityVaults[priceQuery.callerVaultAddress].securityBondAllowance : priceQuery.amount;
		require(debtToMove > 0, 'no debt to move');
		uint256 repToMove = securityVaults[priceQuery.callerVaultAddress].repDepositShare * debtToMove / securityVaults[priceQuery.callerVaultAddress].securityBondAllowance
		require((securityVaults[priceQuery.callerVaultAddress].securityBondAllowance+debtToMove) * this.securityMultiplier * PRICE_PRECISION <= (securityVaults[priceQuery.callerVaultAddress].repDepositShare + repToMove) * price, 'New pool would be liquidable!');
		securityVaults[priceQuery.targetVaultAddress].securityBondAllowance -= debtToMove;
		securityVaults[priceQuery.targetVaultAddress].repDepositShare -= repToMove;

		securityVaults[priceQuery.callerVaultAddress].securityBondAllowance += debtToMove;
		securityVaults[priceQuery.callerVaultAddress].repDepositShare += repToMove;
	}

	////////////////////////////////////////
	// mint security bonds
	////////////////////////////////////////

	function initiateSetSecurityBondAllowance(uint256 amount) {
		require(!this.zoltar.hasForked(), 'already forked');
		require(!this.frozen, 'system frozen');
		updateFee();
		requestRepEthPriceAndPerformAction(PriceQueryAction.SetSecurityBondAllowance, amount, msg.sender);
		this.securityBondsMinted += amount;
		securityVaults[msg.sender].securityBondAllowance += amount;
	}

	function performSetSecurityBondsAllowance(priceQuery PendingPriceQuery, uint256 price) internal {
		revert(!canSetSecurityBondAllowance(), 'cannot mint');
		claimFees(priceQuery.callerVaultAddress);
		// check price if we allow this, check  / this.migratedRep * repToken.balanceOf(this) too
		require(this.securityBondAllowance+priceQuery.amount < this.ethAmountForCompleteSets, 'minted too many compete sets to allow this');
		uint256 oldAllowance = securityVaults[msg.sender].securityBondAllowance;
		this.securityBondAllowance += amount;
		this.securityBondAllowance -= oldAllowance;
		securityVaults[msg.sender].securityBondAllowance += amount;
		securityVaults[msg.sender].securityBondAllowance -= oldAllowance;
	}

	////////////////////////////////////////
	// Complete Sets
	////////////////////////////////////////
	function createCompleteSet() payable {
		require(msg.value > 0, 'need to send eth');
		require(securityBondsMinted - ethAmountForCompleteSets > msg.value, 'no capacity to create that many sets');
		updateFee();
		uint256 amountToMint = msg.value * address(this).balance / ethAmountForCompleteSets;
		completeSet.mint(amountToMint);
		completeSet.transfer(msg.sender, amountToMint);
		ethAmountForCompleteSets += msg.value;
	}

	function redeemCompleteSet(uint256 amount) {
		updateFee();
		// takes in complete set and releases security bond and eth
		completeSet.transferFrom(msg.sender, address(this), amount);
		completeSet.burn(amount);
		uint256 ethValue = amount * ethAmountForCompleteSets / address(this).balance;
		(bool sent, bytes memory data) = payable(msg.sender).call{value: ethValue}("");
        require(sent, "Failed to send Ether");
		ethAmountForCompleteSets -= ethValue;
	}

	function redeemShare() {
		require(question.finalized(), 'Question has not finalized!');
		//convertes yes,no or invalid share to 1 eth each, depending on market outcome
	}

	////////////////////////////////////////
	// FORKING (migrate vault (oi+rep), truth auction)
	////////////////////////////////////////
	function triggerFork() {
		require(!this.zoltar.hasForked(), 'already forked');
		require(!this.forkTriggeredTimestamp > 0, 'fork already triggered');
		this.forkTriggeredTimestamp = block.timestamp;
		this.repAtFork = repToken.balanceOf(this);
		zoltar.splitREP(universe, amount); // converts origin rep to rep_true, rep_false and rep_invalid
	}

	// migrates vault into outcome universe after fork
	function migrateVault(MarketOutcome outcome) {
		require(this.forkTriggeredTimestamp > 0, 'fork needs to be triggered');
		require(this.forkTriggeredTimestamp + MIGRATION_TIME <= block.timestamp, 'migration time passed');
		require(securityVaults[msg.sender].repDepositShare > 0, 'Vault has no rep to migrate');
		claimFees(msg.sender);
		if (address(children[outcome]) === address(0x0)) {
			uint192 universe = getUniverse(outcome); // how does this work?
			// first vault migrater creates new pool and transfers all REP to it
			RepToken repToken = zoltar.getRepToken(universe);
			children[outcome] = new SecurityPool(RepToken, this, ...);
			children[outcome].ethAmountForCompleteSets = this.ethAmountForCompleteSets;
			RepToken.transfer(repToken.balanceOf(this), children[outcome]);
		}
		children[outcome].migrateRepFromParent(msg.sender);

		// migrate open interest
		(bool sent, bytes memory data) = payable(msg.sender).call{value: ethAmountForCompleteSets * securityVaults[msg.sender].repDepositShare / this.repAtFork, }("");
        require(sent, "Failed to send Ether");

		securityVaults[msg.sender].repDepositShare = 0;
		securityVaults[msg.sender].securityBondAllowance = 0;
	}

	function migrateRepFromParent(address vault) {
		require(msg.sender === this.parent, 'only parent can migrate');
		securityVaults[vault].securityBondAllowance = this.parent.securityVaults(vault).securityBondAllowance;
		securityVaults[vault].repDepositShare = this.parent.securityVaults(vault).repDepositShare;
		securityBondAllowance += securityVaults[vault].securityBondAllowance;
		migratedRep += this.parent.securityVaults(vault).repDepositShare;
	}

	// starts an auction on children
	function startTruthAuction() {
		require(this.forkTriggeredTimestamp + MIGRATION_TIME > block.timestamp, 'migration time needs to pass first');
		require(this.truthAuctionStarted === 0, 'Auction already started');
		this.truthAuctionStarted = block.timestamp;
		if (address(this).balance >= this.parent.ethAmountForCompleteSets) {
			// we have acquired all the ETH already, no need auction
			this.frozen = false;
			this.auction.finalizeAuction();
		} else {
			uint256 ethToBuy = this.parent.ethAmountForCompleteSets - address(this).balance;
			repToken.transfer(address(this.auction), repToken.balanceOf(address(this)));
			this.auction.startAuction(ethToBuy);
		}
	}
	function finalizeTruthAuction() {
		require(this.truthAuctionStarted + AUCTION_TIME < block.timestamp, 'auction still ongoing');
		this.frozen = false;
		this.auction.finalizeAuction();

		uint256 ourRep = repToken.balanceOf(address(this))
		if (this.migratedRep > ourRep) {
			// we migrated more rep than we go back. This means this pools holders need to take a haircut, this is acounted with repricing pools reps
		} else {
			// we migrated less rep that we got back from auction, this means we can give extra REP to our pool holders, this is acounted with repricing pools reps
		}
	}
}
