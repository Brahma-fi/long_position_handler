/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./ISwapRouter.sol";
import "./IConvexRewards.sol";
import "./ICrvDepositor.sol";
import "./IPositionHandler.sol";

interface ILongPositionHandler is IPositionHandler {
    function swapRouter() external returns (ISwapRouter);

    function baseRewardPool() external returns (IConvexRewards);

    function crvDepositor() external returns (ICrvDepositor);

    function governance() external returns (address);

    function swapBalanceToUSDC(
        bytes memory _crvSwapData,
        bytes memory _cvxSwapData,
        bytes memory _cvxcrvSwapData,
        uint256 _slippage
    ) external;

    function closePositionAndCompound(bool compoundOnlyRewards)
        external
        returns (uint256);

    function allBalances()
        external
        returns (
            uint256 crvBalance,
            uint256 cvxcrvBalance,
            uint256 cvxBalance,
            uint256 _3crvBalance,
            uint256 usdcBalance
        );

    function balancesInUSDC()
        external
        returns (
            uint256 _crv,
            uint256 _cvx,
            uint256 _cvxcrv,
            uint256 _3crv,
            uint256 _usdc
        );
}
