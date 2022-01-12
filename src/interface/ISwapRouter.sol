/// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "./IOneSplit.sol";
import "./IAggregationRouter.sol";
import "./IChainlinkAggregatorV3.sol";

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface ISwapRouter {
    /// CONSTANTS
    function USDC() external returns (IERC20Metadata);

    function CRV() external returns (IERC20Metadata);

    function CVX() external returns (IERC20Metadata);

    /// 1INCH AGGREGATORS
    function oneInchRouter() external returns (IAggregationRouter);

    function aggregationExecutor() external returns (address);

    /// CHAINLINK PRICE FEETS
    function CRVUSD() external returns (IChainlinkAggregatorV3);

    function CVXUSD() external returns (IChainlinkAggregatorV3);

    /// FUNCTIONS
    function estimateAndSwapTokens(
        bool direction,
        address token,
        uint256 amountToSwap,
        address recipient,
        uint256 slippage,
        bytes memory data
    ) external returns (uint256 amountOut);
}
