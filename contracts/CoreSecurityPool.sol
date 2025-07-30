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

interface ERC1155 {
	function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes calldata _data) external;
	function safeBatchTransferFrom(address _from, address _to, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external;
	function balanceOf(address _owner, uint256 _id) external view returns (uint256);
	function balanceOfBatch(address[] calldata _owners, uint256[] calldata _ids) external view returns (uint256[] memory);
	function setApprovalForAll(address _operator, bool _approved) external;
	function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}
interface ERC1155TokenReceiver {
	function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data) external returns(bytes4);
	function onERC1155BatchReceived(address _operator, address _from, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external returns(bytes4);       
}

contract FeeCompleteSetToken is ERC20, Ownable {
	uint256 public lastUpdatedAccumulator;
	uint256 public feeAccumulator;
	uint256 public fee; // fee rate per second (e.g., 1e16 = 1% per second)
	IERC20 public completeSet;
	address public manager;

	constructor(address _completeSet, address _manager) ERC20("Fee Token", "FEE") {
		completeSet = IERC20(_completeSet);
		manager = _manager;
		lastUpdatedAccumulator = block.timestamp;
	}

	modifier onlyManager() {
		require(msg.sender == manager, "Not manager");
		_;
	}

	function setFee(uint256 _fee) external onlyManager {
		updateAccumulator();
		fee = _fee;
	}

	function updateAccumulator() public {
		uint256 timeElapsed = block.timestamp - lastUpdatedAccumulator;
		if (timeElapsed > 0) {
			feeAccumulator += timeElapsed * fee;
			lastUpdatedAccumulator = block.timestamp;
		}
	}

	function mintFeeTokens(uint256 amount) public {
		completeSet.transferFrom(msg.sender, address(this), amount);
		updateAccumulator();
		uint256 effectiveAmount = _applyFee(amount);
		_mint(msg.sender, effectiveAmount);
	}

	function redeem(uint256 tokenAmount) public {
		updateAccumulator();
		_burn(msg.sender, tokenAmount);
		uint256 redeemAmount = _applyFee(tokenAmount);
		completeSet.transfer(msg.sender, redeemAmount);
	}

	function claimFees() external onlyManager {
		updateAccumulator();
		uint256 totalBalance = completeSet.balanceOf(address(this));
		uint256 totalTokenSupply = totalSupply();
		uint256 claimableFees = totalBalance - _applyFee(totalTokenSupply);
		require(claimableFees > 0, "No fees to claim");
		completeSet.transfer(manager, claimableFees);
	}

	function _applyFee(uint256 amount) internal view returns (uint256) {
		if (feeAccumulator == 0) return amount;
		return (amount * 1e18) / (1e18 + feeAccumulator);
	}
}

enum MarketOutcome {
	Invalid,
	Yes,
	No,
}

contract Market {
	uint256 marketFinalizationDate;
	bool finalized = false;
	IERC20 cashToken;
	IERC20 completeSet;
	MarketOutcome outcome;
	Market[3] children;
	Market parent;

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

	function finalizeMarket(MarketOutcome outcome) public {
		require(finalized, 'Already finalized');
		require(block.timestamp > marketFinalizationDate, 'Not ended yet');
		finalized = true;
		this.outcome = outcome;
	}

	function redeemCompleteSet(uint256 amount) public {
		require(!finalized, 'market finalized');
		//only allow pool to do this?
		completeSet.transferFrom(msg.sender, address(this), amount);
		completeSet.burn(amount);
	}
}

contract Oracle {
	IERC20 reputationToken;
	private mapping(SecurityPool => boolean) validSecurityPools;
	private mapping(Market => boolean) validMarkets;
	Oracle[3] children;
	Oracle parent;
	MarketOutcome forkingMarketOutcome;

	constructor(Oracle parent, MarketOutcome forkingMarketOutcome) {
		this.parent = parent;
		this.forkingMarketOutcome = forkingMarketOutcome;
	}

	function deploySecurityPool(address manager) {
		address newPool = new SecurityPool(manager, this);
		validSecurityPools[newPool] = true;
		return newPool;
	}
	function reportAsValidSecurityPool() {
		require(parent.isValidSecurityPool(msg.sender), 'Parent said its not valid');
		validSecurityPools[msg.sender] = true;
	}
	function getRepEthPrice() {
		return 1;
	}
	function getReputationToken() returns(IERC20) {
		return reputationToken;
	}
	function isValidSecurityPool(SecurityPool securityPool) {
		return validSecurityPools[securityPool];
	}
	function createMarket(uint256 marketFinalizationDate, IERC20 cashToken) {
		Market market = new Market(marketFinalizationDate, cashToken);
		validMarkets[market] = true;
	}
	function isValidMarket(Market market) {
		return validMarkets[market];
	}
	function splitMarket() {

	}
	function split() {
		children[0] = new Oracle(this, MarketOutcome.Invalid);
		children[1] = new Oracle(this, MarketOutcome.Yes);
		children[2] = new Oracle(this, MarketOutcome.No);
	}
	function migrateRepFromParent(address fromWho, address to, uint256 amount) { // called from child
		// todo access rights
		parent.reputationToken.burn(fromWho, amount); // burn the old rep
		reputationToken.mint(to, amount); // mint us new tokens
	}
}

uint256 SECURITY_MULTIPLIER = 2;

interface ISecurityPoolManager {
	function getPurchasePrice(uint256 amount, uint256 marketLength) external view returns (uint256 price, uint256 canMint);
	function getSellPrice(uint256 amount, uint256 marketLength) external view returns (uint256 price, uint256 accept);
}

contract SecurityPool {
	ISecurityPoolManager manager;
	Oracle oracle;
	SecurityPool[3] children;
	SecurityPool parent;
	bool hasSplit;
	
	private mapping(Market => uint256) marketDebt;
	uint256 totalSecurityTokenDebt = 0;
	constructor(SecurityPool parent, ISecurityPoolManager manager, Oracle oracle) {
		this.parent = parent;
		this.manager = manager;
		this.oracle = oracle;
		if (address(parent) !== address(0x0)) {
			this.oracle.reportAsValidSecurityPool();
			this.totalSecurityTokenDebt = parent.totalSecurityTokenDebt;
		}
	}

	function split() {
		hasSplit = true;
		children[0] = new SecurityPool(this, manager, oracle.children[0]);
		children[1] = new SecurityPool(this, manager, oracle.children[1]);
		children[2] = new SecurityPool(this, manager, oracle.children[2]);
	}

	function updateMarketDebtThroughtSplit(Market market) {
		require(parent.marketDebt[market] > 0, 'parent has no debt there');
		market ourBranchMarket = market.children[oracle.forkingMarketOutcome];
		marketDebt[ourBranchMarket] = parent.marketDebt[market];
	}

	function createCompleteSet(Market market, uint256 amount, uint256 addToDate) public {
		require(!hasSplit, 'Pool has split and is thus frozen');
		require(oracle.isValidmarket(market), 'Not a valid market');
		require(market.marketFinalizationDate > block.timestamp, 'Market has already ended');
		address repToken = oracle.getReputationToken();
		totalSecurityTokenDebt += amount;
		// check we stay under the security bound
		require(repToken.balanceOf(market) / (oracle.getRepEthPrice() * SECURITY_MULTIPLIER) > totalSecurityTokenDebt, 'Cannot mint that much!');
		cashToken.transferFrom(msg.sender, address(market), amount); // send eth needed for complete set
		(uint256 price, uint256 canMint) = manager.getPurchasePrice(amount, market.marketFinalizationDate - block.timestamp + addToDate);
		require(canMint, 'Pool did not allow to mint');
		cashToken.transferFrom(msg.sender, address(this), price); // send cost premium to us
		market.mintCompleteSet(msg.sender, amount);
		marketDebt[market] += amount;
	}

	function redeemCompleteSet(Market market, uint256 amount, uint256 subtractFromDate) public {
		require(!hasSplit, 'Pool has split and is thus frozen');
		require(marketDebt[market] >= amount, 'Pool has no debt for this market');
		require(oracle.isValidmarket(market), 'Not a valid market');
		completeSet.transferFrom(msg.sender, address(this), amount);
		(uint256 price, uint256 canMint) = manager.getSellPrice(amount, market.marketFinalizationDate - block.timestamp - subtractFromDate);
		require(accept, 'Pool did not allow redeeming');
		cashToken.transferFrom(address(this), msg.sender, price);
		market.redeemCompleteSet(amount);
		marketDebt[market] -= amount;
		totalSecurityTokenDebt -= amount;
	}

	function clearFinalizedMarkets(Market[] memory markets) public {
		for (uint i = 0; i < markets.length; i++) {
			if (!markets[i].isFinalized()) {
				continue;
			}
			totalSecurityTokenDebt -= marketDebt[markets[i]];
			marketDebt[markets[i]] = 0;
		}
	}

	function slash(Market[] memory markets) {
		require(!hasSplit, 'Pool has split and is thus frozen');
		uint256 debt = 0;
		for (uint i = 0; i < markets.length; i++) {
			if (!oracle.isValidmarket(market)) continue;
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
	function managerClaimFunds() public {
		cashToken.transferFrom(address(this), address(manager), cashToken.balanceOf(address(this)));
	}
	function sendToEscalationGame(address escalationGame, uint256 amount) public {
		require(!hasSplit, 'Pool has split and is thus frozen');
		require(msg.sender === address(manager), 'Only manager can call');
		// you can join escalation game with pool, these won't reduce the rep balance of the pool(?)
	}
	function claimFromEscalationGame(address escalationGame) public {
		require(!hasSplit, 'Pool has split and is thus frozen');
		require(msg.sender === address(manager), 'Only manager can call');
		// you can claim proceedings from escalation game
	}
	function depositRep(uint256 amount) public {
		require(!hasSplit, 'Pool has split and is thus frozen');
	}
	function withdrawRep(uint256 amount) public {
		require(!hasSplit, 'Pool has split and is thus frozen');
	}

	function migrateRepFromParent() public {
		// todo access rights
		oracle.migrateRepFromParent(parent, parent.getReputationToken().balanceOf(parent));
	}
}