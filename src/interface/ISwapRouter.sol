/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./ICurvePool.sol";
import "./IAggregationRouter.sol";
import "./IChainlinkAggregatorV3.sol";

import {ERC20} from "@solmate/tokens/ERC20.sol";

interface ISwapRouter {
    /// CONSTANTS
    function USDC() external returns (ERC20);

    function governance() external returns (address);

    /// CURVE POOL (CRV/CVXCRV)
    function CRV() external returns (ERC20);

    function CVX() external returns (ERC20);

    function CVXCRV() external returns (ERC20);

    function _3CRV() external returns (ERC20);

    function crvcvxcrvPool() external returns (ICurvePool);

    function _3crvPool() external returns (ICurvePool);

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

    function swapOnCRVCVXCRVPool(
        bool direction,
        uint256 amount,
        address recepient
    ) external returns (uint256 amountOut);

    function burn3CRVForUSDC(uint256 amount, address recipient)
        external
        returns (uint256 amountOut);

    // Only CRV & CVX
    function getTokenPriceInUSD(address token) external view returns (uint256);

    function sweep() external;
}
