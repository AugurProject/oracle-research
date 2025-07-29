// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

interface IERC20 {
	function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
	function approve(address _spender, uint256 _value) public returns (bool success);
	function transfer(address _to, uint256 _value) public returns (bool success);
	function balanceOf(address _owner) public view returns (uint256 balance);
	function totalSupply() public view returns (uint256);
	function mint(uint256 amount) public;
	function burn(uint256 amount) public;
}

contract Market {
	uint256 marketFinalizationDate;
	bool finalized = false;
	IERC20 cashToken;
	IERC20 completeSet;

	constructor(uint256 marketFinalizationDate, IERC20 cashToken) {
		this.completeSet = new ERC20();
		this.marketFinalizationDate = marketFinalizationDate;
	}

	function mintCompleteSet(address receiver, uint256 amount) public {
		require(oracle.isValidSecurityPool(msg.sender), 'Not a valid pool!');
		cashToken.transferFrom(msg.sender, address(this), amount);
		completeSet.mint();
		completeSet.transferFrom(address(this), msg.sender, amount);
	}

	function finalizeMarket() public {
		require(finalized, 'Already finalized');
		finalized = true;
	}

	function redeemCompleteSet(uint256 amount) public {
		require(!finalized, 'market finalized');
		//only allow pool to do this?
		completeSet.transferFrom(msg.sender, address(this), amount);
		completeSet.burn(amount);
		cashToken.transferFrom(address(this), msg.sender amount);
	}
}

contract Oracle {
	IERC20 ReputationToken;
	mapping(SecurityPool => boolean) validSecurityPools;

	function deploySecurityPool(address manager) {
		address newPool = new SecurityPool(manager, this);
		validSecurityPools[newPool] = true;
		return newPool;
	}
	function getRepEthPrice() {
		return 1;
	}
	function getReputationToken() returns(IERC20) {
		return ReputationToken;
	}
	function isValidSecurityPool(SecurityPool securityPool) {
		return validSecurityPools[securityPool];
	}
}

uint256 constant SECURITY_MULTIPLIER = 2;

// REP collateralized security pool that makes sure it mint less security tokens that its rep balance can handle, otherwise it can be slashed by keeper
contract SecurityPool {
	address manager;
	Oracle oracle;
	mapping(Market => uint256) marketDebt;
	uint256 totalSecurityTokenDebt = 0;
	constructor(address manager, Oracle oracle) {
		this.manager = manager;
		this.oracle = oracle;
	}
	modifier onlyManager() {
		require(msg.sender == manager, "Not manager");
		_;
	}

	function createCompleteSet(Market market, uint256 amount, uint256 addToDate) external onlyManager {
		require(market.marketFinalizationDate > block.timestamp, 'Market has already ended');
		address repToken = oracle.getReputationToken();
		totalSecurityTokenDebt += amount;
		// check we stay under the security bound
		require(repToken.balanceOf(market) / (oracle.getRepEthPrice() * SECURITY_MULTIPLIER) > totalSecurityTokenDebt, 'Cannot mint that much!');
		cashToken.transferFrom(msg.sender, address(market), amount); // send eth needed for complete set
		market.mintCompleteSet(msg.sender, amount);
		marketDebt[market] += amount;
	}

	function redeemCompleteSet(Market market, uint256 amount, uint256 subtractFromDate) external onlyManager {
		require(marketDebt[market] >= amount, 'Pool has no debt for this market');
		completeSet.transferFrom(msg.sender, address(this), amount);
		market.redeemCompleteSet(amount);
		marketDebt[market] -= amount;
		totalSecurityTokenDebt -= amount;
	}

	function clearFinalizedMarkets(Market[] memory markets) public {
		for (uint i = 0; i < markets.length; i++) {
			if (markets[i].isFinalized()) {
				continue;
			}
			totalSecurityTokenDebt -= marketDebt[markets[i]];
			marketDebt[markets[i]] = 0;
		}
	}

	function slash(Market[] memory markets) external {
		uint256 debt = 0;
		for (uint i = 0; i < markets.length; i++) {
			if (marketDebt[i].isFinalized()) {
				continue;
			}
			debt += marketDebt[markets[i]];
		}
		address repToken = oracle.getReputationToken();
		require(repToken.balanceOf(market) / (oracle.getRepEthPrice() * SECURITY_MULTIPLIER) < debt, 'Not enough debt to slash!');
		uint256 overDebt = debt - repToken.balanceOf(market) / (oracle.getRepEthPrice() * SECURITY_MULTIPLIER);
		repToken.burn(overDebt);
		repToken.transferFrom(address(this), msg.sender, debt / 10); // send 10% of the whole pool to caller
	}
	function sendRepToEscalationGame(address escalationGame, uint256 amount) external onlyManager {
		// you can join escalation game with pool, these won't reduce the rep balance of the pool, except later when its stolen from the losers
	}
	function stealRepByEscalationGame(address escalationGame) external {
		// test that proper escalation game calls and that can steal REP from this if the user lost
	}
	function claimRepFromEscalationGame(address escalationGame) external onlyManager {
		// you can claim proceedings from escalation game
	}
}
