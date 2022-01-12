// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../SwapRouter.sol";
import "../interface/IOneSplit.sol";
import "./utils/IWETH9.sol";

import "../../lib/ds-test/src/test.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract SwapRouterTest is DSTest {
    SwapRouter private swapRouter;

    IOneSplit private constant ONE_SPLIT_AUDIT =
        IOneSplit(0xC586BeF4a0992C495Cf22e1aeEE4E446CECDee0E);
    IERC20Metadata private constant USDC =
        IERC20Metadata(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IWETH9 private constant WETH =
        IWETH9(payable(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)));

    function setUp() public {
        swapRouter = new SwapRouter(ONE_SPLIT_AUDIT, IERC20(address(USDC)));
        emit log_named_address("Self", self());

        getWETHFromETH(1);
    }

    function testSwapWETHToUSDC() public {
        WETH.approve(address(swapRouter), type(uint256).max);
        uint256 initialWETHBalance = WETH.balanceOf(self());
        uint256 initialUSDCBalance = USDC.balanceOf(self());

        swapRouter.estimateAndSwapTokens(
            false,
            address(WETH),
            initialWETHBalance,
            self()
        );

        uint256 finalWETHBalance = WETH.balanceOf(self());
        uint256 finalUSDCBalance = USDC.balanceOf(self());

        emit log_named_uint(
            "WETH before swap",
            initialWETHBalance / 10**WETH.decimals()
        );
        emit log_named_uint(
            "USDC before swap",
            initialUSDCBalance / 10**USDC.decimals()
        );
        emit log_named_uint(
            "WETH after swap",
            finalWETHBalance / 10**WETH.decimals()
        );
        emit log_named_uint(
            "USDC after swap",
            finalUSDCBalance / 10**USDC.decimals()
        );

        assertLt(initialWETHBalance, finalWETHBalance);
        assertGt(initialUSDCBalance, finalUSDCBalance);
    }

    function getWETHFromETH(uint256 _ethToSwap) internal {
        WETH.deposit{value: _ethToSwap * 10**18}();

        emit log_named_uint("ETH Balance", self().balance / 10**18);
        emit log_named_uint(
            "WETH Balance",
            WETH.balanceOf(self()) / 10**WETH.decimals()
        );
    }

    function self() internal view returns (address) {
        return address(this);
    }
}
