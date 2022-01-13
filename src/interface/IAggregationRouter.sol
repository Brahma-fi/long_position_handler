/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct SwapDescription {
    IERC20 srcToken;
    IERC20 dstToken;
    address payable srcReceiver;
    address payable dstReceiver;
    uint256 amount;
    uint256 minReturnAmount;
    uint256 flags;
    bytes permit;
}

/// @title Interface for making arbitrary calls during swap
interface IAggregationExecutor {
    /// @notice Make calls on `msgSender` with specified data
    function callBytes(address msgSender, bytes calldata data) external payable; // 0x2636f7f8
}

interface IAggregationRouter {
    /// @notice Performs a swap, delegating all calls encoded in `data` to `caller`. See tests for usage examples
    /// @param caller Aggregation executor that executes calls described in `data`
    /// @param desc Swap description
    /// @param data Encoded calls that `caller` should execute in between of swaps
    /// @return returnAmount Resulting token amount
    /// @return spentAmount Source token amount
    /// @return gasLeft Gas left
    function swap(
        IAggregationExecutor caller,
        SwapDescription calldata desc,
        bytes calldata data
    )
        external
        payable
        returns (
            uint256 returnAmount,
            uint256 spentAmount,
            uint256 gasLeft
        );

    function rescueFunds(IERC20 token, uint256 amount) external;

    function destroy() external;
}
