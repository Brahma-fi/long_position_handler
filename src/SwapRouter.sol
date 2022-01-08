/// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "./interface/IOneSplit.sol";

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract SwapRouter {
    using SafeERC20 for IERC20;

    // 0xC586BeF4a0992C495Cf22e1aeEE4E446CECDee0E
    IOneSplit public oneSplitSwap;
    // 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    IERC20 public USDC;

    constructor(IOneSplit _oneSplitSwap, IERC20 _USDC) {
        oneSplitSwap = _oneSplitSwap;
        USDC = _USDC;
    }

    /// @dev Direction => True => USDC -> Token
    /// @dev Direction => False =>  Token -> USDC
    function estimateAndSwapTokens(
        bool direction,
        address token,
        uint256 amountToSwap,
        address recipient
    ) public returns (uint256 amountOut) {
        require(token != address(0x0), "Invalid token");
        require(amountToSwap > 0, "Invalid swap amount");

        IERC20 token0 = direction ? USDC : IERC20(token);
        IERC20 token1 = direction ? IERC20(token) : USDC;

        token0.safeTransferFrom(recipient, address(this), amountToSwap);

        (
            uint256 expectedAmountOut,
            uint256[] memory distribution
        ) = _estimateSwapResults(token0, token1, amountToSwap);

        amountOut = _swapTokens(
            token0,
            token1,
            amountToSwap,
            expectedAmountOut,
            distribution
        );

        token1.safeTransferFrom(address(this), recipient, amountOut);
        token0.safeTransferFrom(
            address(this),
            recipient,
            token0.balanceOf(address(this))
        );
    }

    function _estimateSwapResults(
        IERC20 token0,
        IERC20 token1,
        uint256 amount
    )
        internal
        view
        returns (uint256 expectedAmountOut, uint256[] memory distribution)
    {
        (expectedAmountOut, distribution) = oneSplitSwap.getExpectedReturn(
            token0,
            token1,
            amount,
            3,
            0
        );
    }

    function _swapTokens(
        IERC20 token0,
        IERC20 token1,
        uint256 amount,
        uint256 minReturn,
        uint256[] memory distribution
    ) internal returns (uint256 _swappedAmount) {
        token0.approve(address(oneSplitSwap), amount);

        _swappedAmount = oneSplitSwap.swap(
            token0,
            token1,
            amount,
            minReturn,
            distribution,
            0
        );
    }
}
