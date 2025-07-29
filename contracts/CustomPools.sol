// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

struct RepDeposit {
	uint256 rep;
	uint256 accumulator;
	uint256 pendingFees;
}

// a custom pool where you can buy true complete sets from security pool with fixed fee
contract ConstantPriceCustomSecurityPool { 
	SecurityPool securityPool;
	uint256 public feePerTokenMinted; // fee rate (scaled by 1e18)
	IERC20 public cashToken;
	IERC20 public repToken;

	mapping(address => RepDeposit) public repHolders;
	uint256 public totalRepDeposits;
	uint256 public globalFeePerRep; // scaled by 1e18

	constructor(Oracle oracle, uint256 _feePerTokenMinted, IERC20 _cashToken, IERC20 _repToken) {
		securityPool = oracle.deploySecurityPool(address(this));
		feePerTokenMinted = _feePerTokenMinted;
		cashToken = _cashToken;
		repToken = _repToken;
	}

	// -------------------------
	// BUY COMPLETE SETS WITH FEE
	// -------------------------
	function buyCompleteSets(uint256 amount) public {
		uint256 fee = (amount * feePerTokenMinted) / 1e18;
		uint256 totalCost = amount + fee;

		// Collect payment (CASH + Fee)
		cashToken.transferFrom(msg.sender, address(this), totalCost);

		// Mint complete sets
		securityPool.createCompleteSet(market, amount, 0);
		IERC20 completeSet = market.completeSet();
		completeSet.transfer(msg.sender, amount);

		// Distribute fee to REP holders
		_distributeFee(fee);
	}

	// -------------------------
	// REP FEE ACCOUNTING
	// -------------------------

	function depositRep(uint256 amount) public {
		require(amount > 0, "Amount must be > 0");
		_updateUserFees(msg.sender);
		repToken.transferFrom(msg.sender, address(this), amount);
		securityPool.depositRep(amount);
		repHolders[msg.sender].rep += amount;
		totalRepDeposits += amount;
	}

	function withdrawRep(uint256 amount) public {
		require(repHolders[msg.sender].rep >= amount, "Insufficient REP balance");
		_updateUserFees(msg.sender);
		repHolders[msg.sender].rep -= amount;
		totalRepDeposits -= amount;
		securityPool.withdrawRep(amount);
		repToken.transfer(msg.sender, amount);
		_claimUserFees(msg.sender);
	}

	function claimFees() public {
		_updateUserFees(msg.sender);
		_claimUserFees(msg.sender);
	}

	// -------------------------
	// INTERNAL FEE LOGIC
	// -------------------------

	function _distributeFee(uint256 fee) internal {
		if (fee > 0 && totalRepDeposits > 0) {
			globalFeePerRep += (fee * 1e18) / totalRepDeposits;
		}
	}

	function _updateUserFees(address user) internal {
		RepDeposit storage deposit = repHolders[user];
		if (deposit.rep > 0) {
			uint256 accumulated = (deposit.rep * (globalFeePerRep - deposit.accumulator)) / 1e18;
			deposit.pendingFees += accumulated;
		}
		deposit.accumulator = globalFeePerRep;
	}

	function _claimUserFees(address user) internal {
		RepDeposit storage deposit = repHolders[user];
		uint256 claimable = deposit.pendingFees;
		require(claimable > 0, "No fees to claim");
		deposit.pendingFees = 0;
		cashToken.transfer(user, claimable);
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
contract OpenVariableFeeCustomSecurityPool {
	SecurityPool securityPool;
	mapping(Market => FeeCompleteSetToken) feeCompleteSetTokens;
	mapping(address => RepDeposit) repHolders;
	IERC20 cashToken;
	IERC20 repToken;

	uint256 public totalRepDeposits;
	uint256 public globalFeePerRep; // scaled by 1e18 for precision

	constructor(Oracle oracle, IERC20 _repToken, IERC20 _cashToken) {
		this.securityPool = oracle.deploySecurityPool(address(this));
		repToken = _repToken;
		cashToken = _cashToken;
	}

	function addMarket(Market market) public {
		feeCompleteSetTokens[market] = new FeeCompleteSetToken(market.completeSet(), address(this));
		feeCompleteSetTokens[market].setFee(10);
	}

	function changeMarketFee(Market market, uint256 newFee) private {
		feeCompleteSetTokens[market].setFee(newFee);
	}

	// -------------------------
	// REP DEPOSIT & FEE TRACKING
	// -------------------------

	function depositRep(uint256 amount) public {
		require(amount > 0, "Amount must be > 0");
		_updateUserFees(msg.sender);
		repToken.transferFrom(msg.sender, address(this), amount);
		repHolders[msg.sender].rep += amount;
		securityPool.depositRep(amount);
		totalRepDeposits += amount;
	}

	function withdrawRep(uint256 amount) public {
		require(repHolders[msg.sender].rep >= amount, "Insufficient deposited REP");
		_updateUserFees(msg.sender);
		repHolders[msg.sender].rep -= amount;
		totalRepDeposits -= amount;
		securityPool.withdrawRep(amount);
		repToken.transfer(msg.sender, amount);
		_claimUserFees(msg.sender);
	}

	function claimFees() public {
		_updateUserFees(msg.sender);
		_claimUserFees(msg.sender);
	}

	function _updateUserFees(address user) internal {
		RepDeposit storage deposit = repHolders[user];
		if (deposit.rep > 0) {
			uint256 accumulated = (deposit.rep * (globalFeePerRep - deposit.accumulator)) / 1e18;
			deposit.pendingFees += accumulated;
		}
		deposit.accumulator = globalFeePerRep;
	}

	function _claimUserFees(address user) internal {
		RepDeposit storage deposit = repHolders[user];
		uint256 claimable = deposit.pendingFees;
		require(claimable > 0, "No fees to claim");
		deposit.pendingFees = 0;
		cashToken.transfer(user, claimable);
	}

	// -------------------------
	// FEE COLLECTION FROM MARKETS
	// -------------------------

	function collectMarketFees(Market market) public {
		uint256 feesBefore = cashToken.balanceOf(address(this));
		feeCompleteSetTokens[market].claimFees();
		uint256 feesCollected = cashToken.balanceOf(address(this)) - feesBefore;

		if (feesCollected > 0 && totalRepDeposits > 0) {
			globalFeePerRep += (feesCollected * 1e18) / totalRepDeposits;
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
