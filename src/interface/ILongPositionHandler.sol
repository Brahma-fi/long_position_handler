/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./ISwapRouter.sol";
import "./IConvexRewards.sol";
import "./ICrvDepositor.sol";
import "./IPositionHandler.sol";

interface ILongPositionHandler is IPositionHandler {
    function swapRouter() external view returns (ISwapRouter);

    function baseRewardPool() external view returns (IConvexRewards);

    function crvDepositor() external view returns (ICrvDepositor);

    function governance() external view returns (address);

    function convertBalanceAndWithdraw(bytes memory _cvxcrvSwapData) external;

    function closePositionAndCompound(bool compoundRewards)
        external
        returns (uint256);

    function allBalances()
        external
        view
        returns (
            uint256 crvBalance,
            uint256 cvxcrvBalance,
            uint256 cvxBalance,
            uint256 _3crvBalance,
            uint256 usdcBalance
        );

    function balancesInUSDC()
        external
        view
        returns (
            uint256 _crv,
            uint256 _cvx,
            uint256 _cvxcrv,
            uint256 _3crv,
            uint256 _usdc
        );

    function positionInUSDC() external view returns (uint256);

    function positionInCRV() external view returns (uint256);
}
