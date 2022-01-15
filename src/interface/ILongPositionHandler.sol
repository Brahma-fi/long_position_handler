/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./ISwapRouter.sol";
import "./IConvexRewards.sol";
import "./IPositionHandler.sol";

interface ILongPositionHandler is IPositionHandler {
    function swapRouter() external returns (ISwapRouter);

    function baseRewardPool() external returns (IConvexRewards);

    function governance() external returns (address);
}
