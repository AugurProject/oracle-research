// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IOpenOracle {
    struct disputeRecord {
        uint256 amount1;
        uint256 amount2;
        address tokenToSwap;
        uint48 reportTimestamp;
    }

    struct extraReportData {
        bytes32 stateHash;
        address callbackContract;
        uint32 numReports;
        uint32 callbackGasLimit;
        bytes4 callbackSelector;
        bool trackDisputes;
        bool keepFee;
    }

    struct ReportMeta {
        uint256 exactToken1Report;
        uint256 escalationHalt;
        uint256 fee;
        uint256 settlerReward;
        address token1;
        uint48 settlementTime;
        address token2;
        bool timeType;
        uint24 feePercentage;
        uint24 protocolFee;
        uint16 multiplier;
        uint24 disputeDelay;
    }

    struct ReportStatus {
        uint256 currentAmount1;
        uint256 currentAmount2;
        uint256 price;
        address payable currentReporter;
        uint48 reportTimestamp;
        uint48 settlementTimestamp;
        address payable initialReporter;
        uint48 lastReportOppoTime;
        bool disputeOccurred;
        bool isDistributed;
    }

    struct CreateReportParams {
        uint256 exactToken1Report;
        uint256 escalationHalt;
        uint256 settlerReward;
        address token1Address;
        uint48 settlementTime;
        uint24 disputeDelay;
        uint24 protocolFee;
        address token2Address;
        uint32 callbackGasLimit;
        uint24 feePercentage;
        uint16 multiplier;
        bool timeType;
        bool trackDisputes;
        bool keepFee;
        address callbackContract;
        bytes4 callbackSelector;
    }

    function createReportInstance(CreateReportParams calldata params) external payable returns (uint256 reportId);

    /* initial report overload with reporter */
    function submitInitialReport(
        uint256 reportId,
        uint256 amount1,
        uint256 amount2,
        bytes32 stateHash,
        address reporter
    ) external;

    function disputeAndSwap(
        uint256 reportId,
        address tokenToSwap,
        uint256 newAmount1,
        uint256 newAmount2,
        address disputer,
        uint256 amt2Expected,
        bytes32 stateHash
    ) external;

    function settle(uint256 id) external returns (uint256 price, uint256 settlementTimestamp);

    function nextReportId() external view returns (uint256);

    function reportMeta(uint256 id) external view returns (ReportMeta memory);

    function reportStatus(uint256 id) external view returns (ReportStatus memory);

    function extraData(uint256 id) external view returns (extraReportData memory);
}
