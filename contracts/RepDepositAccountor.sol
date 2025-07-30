// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

abstract contract RepDepositAccountor {
	struct RepDeposit {
		uint256 rep;
		uint256 pendingFees;
		uint256 feeAccumulatorSnapshot;
	}

	mapping(address => RepDeposit) public repHolders;
	uint256 totalRepDeposits;
	uint256 public globalFeeAccumulator; // scaled by 1e18

	IERC20 public cashToken;

	constructor(IERC20 _repToken, IERC20 _cashToken) {
		cashToken = _cashToken;
	}

	// -------------------------
	// REP DEPOSIT AND WITHDRAWAL
	// -------------------------

	function depositRep(uint256 amount) public virtual {
		require(amount > 0, "Amount must be > 0");
		_updateUserFees(msg.sender);
		repToken.transferFrom(msg.sender, address(this), amount);
		totalRepDeposits += amount;
		repHolders[msg.sender].rep += amount;
		repHolders[msg.sender].feeAccumulatorSnapshot = globalFeeAccumulator;
	}

	function withdrawRep(uint256 amount) public virtual {
		require(repHolders[msg.sender].rep >= amount, "Insufficient REP balance");
		_updateUserFees(msg.sender);

		totalRepDeposits -= amount;
		repHolders[msg.sender].rep -= amount;
		repToken.transfer(msg.sender, amount);

		_claimUserFees(msg.sender);
	}

	function claimFees() public {
		_updateUserFees(msg.sender);
		_claimUserFees(msg.sender);
	}

	// -------------------------
	// FEE HANDLING
	// -------------------------

	function depositFees(uint256 feeAmount) internal {
		require(feeAmount > 0, "Fee must be > 0");
		require(totalRepDeposits > 0, "No REP stakers");

		cashToken.transferFrom(msg.sender, address(this), feeAmount);
		globalFeeAccumulator += (feeAmount * 1e18) / totalRepDeposits;
	}

	// -------------------------
	// INTERNAL LOGIC
	// -------------------------

	function _updateUserFees(address user) internal {
		RepDeposit storage deposit = repHolders[user];
		if (deposit.rep > 0) {
			uint256 delta = globalFeeAccumulator - deposit.feeAccumulatorSnapshot;
			uint256 owed = (deposit.rep * delta) / 1e18;
			deposit.pendingFees += owed;
		}
		deposit.feeAccumulatorSnapshot = globalFeeAccumulator;
	}

	function _claimUserFees(address user) internal {
		RepDeposit storage deposit = repHolders[user];
		uint256 claimable = deposit.pendingFees;
		require(claimable > 0, "No fees to claim");
		deposit.pendingFees = 0;
		cashToken.transfer(user, claimable);
	}
}
