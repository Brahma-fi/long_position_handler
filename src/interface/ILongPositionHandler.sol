/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./ISwapRouter.sol";
import "./IConvexRewards.sol";
import "./IPositionHandler.sol";

interface ILongPositionHandler is IPositionHandler {
    function swapRouter() external returns (ISwapRouter);

    function baseRewardPool() external returns (IConvexRewards);

    function governance() external returns (address);

    function swapAllTokensToUSDC(
        bytes memory _crvSwapData,
        bytes memory _cvxSwapData,
        uint256 _slippage
    ) external;

    function allBalances()
        external
        returns (
            uint256 crvBalance,
            uint256 cvxcrvBalance,
            uint256 cvxBalance,
            uint256 _3crvBalance,
            uint256 usdcBalance
        );
}
