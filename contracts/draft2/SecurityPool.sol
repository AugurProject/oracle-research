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

contract SecurityPool {
	Question question;
	IOpenOracle openOracle;
	Zoltar zoltar;
	uint256 securityBondAllowance;
	uint256 completeSetsMinted;
	uint256 migratedRep;
	uint256 repAtFork;
	uint256 securityMultiplier;
	uint256 fee;
	uint256 feeAccumulator;
	bool forkTriggeredTimestamp;
	mapping(address => SecurityVault) securityVaults;
	mapping(uint256 => PendingPriceQuery) pendingPriceQueries;
	SecurityPool[3] children;
	SecurityPool parent;
	uint256 truthAuctionStarted;
	bool frozen;
	IERC20 completeSet;
	CustomizedEasyAuction auction;
	IERC20 repToken; // rep token of this universe

	constructor(IERC20 repToken, SecurityPool parent, Zoltar zoltar, IOpenOracle openOracle, Question question, uint256 fee, uint256 securityMultiplier) {
		this.repToken = repToken;
		this.question = question;
		this.fee = fee;
		this.securityMultiplier = securityMultiplier;
		this.openOracle = openOracle;
		this.zoltar = zoltar;
		this.parent = parent;
		if (this.parent === address(0x0)) { // origin universe never does auction
			this.truthAuctionStarted = 1;
			this.frozen = false;
		} else {
			this.frozen = true;
			this.auction = new CustomizedEasyAuction(); // craete auction instance that can start receive orders right away
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
		updateAccumulator(msg.sender);
		uint256 repAmount = amount * this.migratedRep / repToken.balanceOf(this);
		securityVaults[msg.sender].repDepositShare -= amount;
		repToken.transfer(address(this), repAmount);
	}
	
	function depositRep(uint256 amount) {
		updateAccumulator(msg.sender);
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
		requestRepEthPriceAndPerformAction(PriceQueryAction.SetSecurityBondAllowance, amount, msg.sender);
		this.securityBondsMinted += amount;
		securityVaults[msg.sender].securityBondAllowance += amount;
	}

	function performSetSecurityBondsAllowance(priceQuery PendingPriceQuery, uint256 price) internal {
		revert(!canSetSecurityBondAllowance(), 'cannot mint');
		// check price if we allow this, check  / this.migratedRep * repToken.balanceOf(this) too
		require(this.securityBondAllowance+priceQuery.amount < this.completeSetsMinted, 'minted too many compete sets to allow this');
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
		require(securityBondsMinted - completeSetsMinted > msg.value, 'no capacity to create that many sets');
		completeSet.mint(msg.value);
		completeSet.transfer(msg.sender, msg.value);
		completeSetsMinted += msg.value;
	}

	function redeemCompleteSet(uint256 amount) {
		// takes in complete set and releases security bond and eth
		completeSet.transferFrom(msg.sender, address(this), amount);
		completeSet.burn(amount);
		(bool sent, bytes memory data) = payable(msg.sender).call{value: msg.value}("");
        require(sent, "Failed to send Ether");
		completeSetsMinted -= amount;
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
		if (address(children[outcome]) === address(0x0)) {
			uint192 universe = getUniverse(outcome); // how does this work?
			// first vault migrater creates new pool and transfers all REP to it
			RepToken repToken = zoltar.getRepToken(universe);
			children[outcome] = new SecurityPool(RepToken, this, ...);
			children[outcome].completeSetsMinted = this.completeSetsMinted;
			RepToken.transfer(repToken.balanceOf(this), children[outcome]);
		}
		children[outcome].migrateRepFromParent(msg.sender);

		// migrate open interest
		(bool sent, bytes memory data) = payable(msg.sender).call{value: completeSetsMinted * securityVaults[msg.sender].repDepositShare / this.repAtFork, }("");
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
		if (address(this).balance >= this.parent.completeSetsMinted) {
			// we have acquired all the ETH already, no need auction
			this.frozen = false;
			this.auction.finalizeAuction();
		} else {
			uint256 ethToBuy = this.parent.completeSetsMinted - address(this).balance;
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
