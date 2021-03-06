/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./ICurvePool.sol";
import "./IAggregationRouter.sol";
import "./IChainlinkAggregatorV3.sol";

import {ERC20} from "@solmate/tokens/ERC20.sol";

interface ISwapRouter {
    /// CONSTANTS
    function USDC() external view returns (ERC20);

    function governance() external view returns (address);

    /// CURVE POOL (CRV/CVXCRV)
    function CRV() external view returns (ERC20);

    function CVX() external view returns (ERC20);

    function CVXCRV() external view returns (ERC20);

    function _3CRV() external view returns (ERC20);

    function crvcvxcrvPool() external view returns (ICurvePool);

    function _3crvPool() external view returns (ICurvePool);

    /// 1INCH AGGREGATORS
    function oneInchRouter() external view returns (IAggregationRouter);

    function aggregationExecutor() external view returns (address);

    /// CHAINLINK PRICE FEETS
    function CRVUSD() external view returns (IChainlinkAggregatorV3);

    function CVXUSD() external view returns (IChainlinkAggregatorV3);

    // Owner :: Long Position Handler
    function positionHandlers(address handler) external view returns (bool);

    /// FUNCTIONS
    function addPositionHandler(address _positionHandler) external;

    function estimateAndSwapTokens(
        bool direction,
        address token,
        uint256 amountToSwap,
        address recipient,
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

    function sweep(address _token) external;
}
