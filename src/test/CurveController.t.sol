// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../CurveController.sol";
import "../SwapRouter.sol";

import {IAggregationRouter} from "../interface/IAggregationRouter.sol";
import {IChainlinkAggregatorV3} from "../interface/IChainlinkAggregatorV3.sol";
import {ICurvePool} from "../interface/ICurvePool.sol";
import {IConvexRewards} from "../interface/IConvexRewards.sol";

import "./utils/IWETH9.sol";
import "./utils/IUniswapSwapRouter.sol";

import "@ds-test/test.sol";

contract CurveControllerTest is DSTest {
    SwapRouter private swapRouter;
    CurveController private curveController;

    IUniswapSwapRouter private immutable UniswapRouter =
        IUniswapSwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IERC20Metadata private constant USDC =
        IERC20Metadata(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IWETH9 private constant WETH =
        IWETH9(payable(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)));

    function setUp() public {
        swapRouter = new SwapRouter(
            IAggregationRouter(0x1111111254fb6c44bAC0beD2854e76F90643097d),
            0x220bdA5c8994804Ac96ebe4DF184d25e5c2196D4,
            IChainlinkAggregatorV3(0xCd627aA160A6fA45Eb793D19Ef54f5062F20f33f),
            IChainlinkAggregatorV3(0xd962fC30A72A84cE50161031391756Bf2876Af5D),
            ICurvePool(0x9D0464996170c6B9e75eED71c68B99dDEDf279e8),
            ICurvePool(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7),
            self()
        );

        curveController = new CurveController(
            ISwapRouter(address(swapRouter)),
            IConvexRewards(0x3Fe65692bfCD0e6CF84cB1E7d24108E434A7587e),
            self()
        );

        swapAndGetBalances(2);

        emit log_named_address("Self", self());
    }

    function testSuccess() public pure {
        assert(true);
    }

    function swapAndGetBalances(uint256 _ethToSwap) internal {
        emit log_named_uint("ETH Balance", self().balance / 10**18);

        WETH.deposit{value: _ethToSwap * 10**18}();
        uint256 WETHBalance = WETH.balanceOf(self());
        WETH.approve(address(UniswapRouter), WETHBalance);

        IUniswapSwapRouter.ExactInputSingleParams
            memory params = IUniswapSwapRouter.ExactInputSingleParams({
                tokenIn: address(WETH),
                tokenOut: address(USDC),
                fee: 3000,
                recipient: self(),
                deadline: block.timestamp,
                amountIn: WETHBalance,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        UniswapRouter.exactInputSingle(params);

        emit log_named_uint(
            "USDC Balance",
            USDC.balanceOf(self()) / 10**USDC.decimals()
        );
    }

    function self() internal view returns (address) {
        return address(this);
    }
}
