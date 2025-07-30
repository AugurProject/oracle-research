// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

struct RepDeposit {
	uint256 rep;
	uint256 accumulator;
	uint256 pendingFees;
}

// a custom pool where you can buy true complete sets from security pool with fixed fee
contract OpenConstantPriceController is RepDepositAccountor { 
	SecurityPool public securityPool;
	uint256 public feePerTokenMinted; // fee rate (scaled by 1e18)

	constructor(Oracle oracle, uint256 _feePerTokenMinted, IERC20 _cashToken, IERC20 _repToken) 
		RepDepositAccountor(_repToken, _cashToken)
	{
		securityPool = oracle.deploySecurityPool(address(this));
		feePerTokenMinted = _feePerTokenMinted;
	}

	// -------------------------
	// BUY COMPLETE SETS WITH FEE
	// -------------------------
	function buyCompleteSets(Market market, uint256 amount) public {
		uint256 fee = (amount * feePerTokenMinted) / 1e18;
		uint256 totalCost = amount + fee;

		// Collect payment (CASH + Fee)
		cashToken.transferFrom(msg.sender, address(this), totalCost);

		// Mint complete sets
		securityPool.createCompleteSet(market, amount, 0);
		IERC20 completeSet = market.completeSet();
		completeSet.transfer(msg.sender, amount);

		// Deposit collected fee into RepFeeManager
		_depositFees(fee);
	}

	// -------------------------
	// REP DEPOSIT AND WITHDRAW
	// -------------------------

	function depositRep(uint256 amount) public override {
		super.depositRep(amount);
		securityPool.depositRep(amount);
	}

	function withdrawRep(uint256 amount) public override {
		super.withdrawRep(amount);
		securityPool.withdrawRep(amount);
	}
}

// a token that charges variable fee
contract FeeCompleteSetToken is ERC20 {
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

	function wrap(uint256 amount) public {
		completeSet.transferFrom(msg.sender, address(this), amount);
		updateAccumulator();
		uint256 effectiveAmount = _applyFee(amount);
		_mint(msg.sender, effectiveAmount);
	}

	// converts wrapped tokens back to complete sets, can only be called by manager as the token no longer have fee after this
	function unWrap(uint256 tokenAmount) external onlyManager {
		updateAccumulator();
		_burn(msg.sender, tokenAmount);
		uint256 redeemAmount = _applyFee(tokenAmount);
		completeSet.transfer(msg.sender, redeemAmount);
		return redeemAmount;
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

// a custom pool where users are charged variable fee
contract OpenVariableFeeController is RepDepositAccountor {
	SecurityPool public securityPool;
	mapping(Market => FeeCompleteSetToken) public feeCompleteSetTokens;

	constructor(Oracle oracle, IERC20 _repToken, IERC20 _cashToken)
		RepDepositAccountor(_repToken, _cashToken)
	{
		securityPool = oracle.deploySecurityPool(address(this));
	}

	// -------------------------
	// MARKET FEE MANAGEMENT
	// -------------------------

	function addMarket(Market market) public {
		feeCompleteSetTokens[market] = new FeeCompleteSetToken(market.completeSet(), address(this));
		feeCompleteSetTokens[market].setFee(10);
	}

	function changeMarketFee(Market market, uint256 newFee) private {
		feeCompleteSetTokens[market].setFee(newFee);
	}

	// -------------------------
	// REP DEPOSIT & WITHDRAW
	// -------------------------

	function depositRep(uint256 amount) public override {
		super.depositRep(amount);
		securityPool.depositRep(amount);
	}

	function withdrawRep(uint256 amount) public override {
		super.withdrawRep(amount);
		securityPool.withdrawRep(amount);
	}

	// -------------------------
	// FEE COLLECTION & DISTRIBUTION
	// -------------------------

	function collectMarketFees(Market market) public {
		uint256 feesBefore = cashToken.balanceOf(address(this));
		feeCompleteSetTokens[market].claimFees();
		uint256 feesCollected = cashToken.balanceOf(address(this)) - feesBefore;

		if (feesCollected > 0) {
			_depositFees(feesCollected); // use accumulator logic from RepFeeManager
		}
	}

	// -------------------------
	// FEE COMPLETE SET MANAGEMENT
	// -------------------------

	function redeemFeeCompleteSetFromMarket(Market market, uint256 amount) public {
		feeCompleteSetTokens[market].transferFrom(msg.sender, address(this), amount);
		uint256 redeemAmount = feeCompleteSetTokens[market].unWrap(amount);
		securityPool.redeemCompleteSet(market, redeemAmount, 0);
		cashToken.transfer(msg.sender, redeemAmount);
	}

	function createFeeCompleteSets(Market market, uint256 amount) public {
		cashToken.transferFrom(msg.sender, address(this), amount);
		securityPool.createCompleteSet(market, amount, 0);
		feeCompleteSetTokens[market].wrap(amount);
		feeCompleteSetTokens[market].transfer(msg.sender, amount);
	}
}
