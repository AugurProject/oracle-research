// SPDX-License-Identifier: MIT
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

IERC20 repToken(0x...);
IERC20 securityBond(0x...);
LiquidationAuctions liquidationAuctions();

struct SecurityVault {
	uint256 securityBondsMinted;
	uint256 repDeposit;
	uint256 feeAccumulator;
}

enum MarketOutcome {
	Invalid,
	Yes,
	No,
}

enum PriceQueryAction {
	WithdrawRep,
	MintSecurityBonds,
	Liquidate,
}

struct PendingPriceQuery {
	PriceQueryAction priceQueryAction;
	uint256 amount;
	address vaultAddress;
}

uint256 constant MIGRATION_TIME = 2 months;
uint256 constant AUCTION_TIME = 1 weeks;

contract SecurityPool {
	Question question;
	IOpenOracle openOracle;
	Zoltar zoltar;
	uint256 securityBondsMinted;
	uint256 completeSetsMinted;
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

	constructor(SecurityPool parent, Zoltar zoltar, IOpenOracle openOracle, Question question, uint256 fee, uint256 securityMultiplier) {
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
		}
	}

	function requestRepEthPriceAndPerformAction(PriceQueryAction priceQueryAction, uint256 amount, address vaultAddress) {
		// allow only one pending request, otherwise join to old request?
		// allow also using just resolving reports?
		address callbackContract = address(this);
        bytes4 callbackSelector = this.openOracleReportPrice;
		uint256 priceQueryId = this.openOracle.createReportInstance(...);
		pendingPriceQueries[priceQueryId] = {
			priceQueryAction: priceQueryAction,
			amount: amount,
			vaultAddress: vaultAddress
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
		else if (pendingPriceQueries[reportId].priceQueryAction === PriceQueryAction.MintSecurityBonds) {
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
		requestRepEthPriceAndPerformAction(PriceQueryAction.WithdrawRep, amount, msg.sender);
	}

	function performWithdrawRep(priceQuery PendingPriceQuery, uint256 price) internal {
		require(!this.zoltar.hasForked(), 'already forked');
		require(!this.frozen, 'system frozen');
		// todo, check if price allows this
		updateAccumulator(msg.sender);
		securityVaults[msg.sender].repDeposit -= amount;
		repToken.transfer(msg.sender, address(this), amount);
	}
	
	function depositRep(uint256 amount) {
		updateAccumulator(msg.sender);
		securityVaults[msg.sender].repDeposit += repDeposit;
		repToken.transferFrom(msg.sender, address(this), amount);
	}


	////////////////////////////////////////
	// liquidating vault
	////////////////////////////////////////

	function initiateLiquidation() {
		require(!this.zoltar.hasForked(), 'already forked');
		require(!this.frozen, 'system frozen');
		requestRepEthPriceAndPerformAction(PriceQueryAction.Liquidate, amount, msg.sender);
	}
	function performLiquidation(priceQuery PendingPriceQuery, uint256 price) internal {
		liquidate....
	}

	////////////////////////////////////////
	// mint security bonds
	////////////////////////////////////////

	function initiateMintSecurityBonds(uint256 amount) {
		require(!this.zoltar.hasForked(), 'already forked');
		require(!this.frozen, 'system frozen');
		requestRepEthPriceAndPerformAction(PriceQueryAction.Liquidate, amount, msg.sender);
	}

	function performMintSecurityBonds(priceQuery PendingPriceQuery, uint256 price) internal {
		// todo, we need to check when this is allowed
		// - no liquidity auctions
		// - cannot trigger liquidity auction afterwards?
		revert(!canMintSecurityBonds(), 'cannot mint');
		securityBondsMinted += amount;
		securityVaults[msg.sender].securityBondsMinted += amount;
		securityBond.mint(amount);
		securityBond.transfer(msg.sender, amount);
	}

	function depositSecurityBonds(uint256 amount) {
		require(!this.zoltar.hasForked(), 'already forked');
		require(!this.frozen, 'system frozen');
		securityBond.transferFrom(msg.sender, address(this), amount);
		securityBond.burn(amount);
		securityVaults[msg.sender].securityBondsMinted -= amount;
		require(securityBondsMinted >= amount, 'Cannot burn that many');
		securityBondsMinted -= amount;
	}

	////////////////////////////////////////
	// Complete Sets
	////////////////////////////////////////
	function createCompleteSet() {
		// takes in security bond+ ETH and mints complete set
	}

	function redeemCompleteSet() {
		// takes in complete set and releases security bond and eth

	}

	function redeemShare() {
		//convertes yes,no or invalid share to 1 eth each, depending on market outcome
	}

	////////////////////////////////////////
	// FORKING (migrate vault (oi+rep), truth auction)
	////////////////////////////////////////
	function triggerFork() {
		require(!this.zoltar.hasForked(), 'already forked');
		require(!this.forkTriggeredTimestamp > 0, 'fork already triggered');
		this.forkTriggeredTimestamp = block.timestamp;
	}

	// migrates vault into outcome universe after fork
	function migrateVault(MarketOutcome outcome) {
		require(this.forkTriggeredTimestamp > 0, 'fork needs to be triggered');
		require(this.forkTriggeredTimestamp + MIGRATION_TIME <= block.timestamp, 'migration time passed');
		uint192 universe = getUniverse(outcome); // how does this work?
		zoltar.migrateREP(universe, amount);
		if (address(children[outcome]) === address(0x0)) {
			children[outcome] = new SecurityPool(this, ...);
		}
		children[outcome].migrateRepFromParent(msg.sender);
		children[outcome].migrateOpenInterestFromParent(msg.sender);
		todo...
	}

	function migrateRepFromParent(address vault) {
		require(msg.sender === this.parent, 'only parent can migrate');
		todo...
	}
	function migrateOpenInterestFromParent(address vault) {
		require(msg.sender === this.parent, 'only parent can migrate');
		todo...
	}

	// starts an auction on children 
	function startTruthAuction() {
		require(this.forkTriggeredTimestamp + MIGRATION_TIME > block.timestamp, 'migration time needs to pass first');
		require(this.truthAuctionStarted === 0, 'Auction already started');
		this.truthAuctionStarted = block.timestamp;

		auction off `this.parent.repLocked` worth of this universes REP for `this.parent.completeSetsMinted - this.migratedOpenInterest`
	}
	function finalizeTruthAuction() {
		require(this.truthAuctionStarted + AUCTION_TIME < block.timestamp, 'auction still ongoing');
		this.frozen = false;
	}
}
