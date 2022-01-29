// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../LongPositionHandler.sol";
import "../SwapRouter.sol";

import "../interface/IUniswapSwapRouter.sol";
import {IAggregationRouter} from "../interface/IAggregationRouter.sol";
import {IChainlinkAggregatorV3} from "../interface/IChainlinkAggregatorV3.sol";
import {ICurvePool} from "../interface/ICurvePool.sol";
import {IConvexRewards} from "../interface/IConvexRewards.sol";
import {ICrvDepositor} from "../interface/ICrvDepositor.sol";

import "./utils/IWETH9.sol";

import "@ds-test/test.sol";

contract LongPositionTest is DSTest {
    SwapRouter private swapRouter;
    LongPositionHandler private longPositionHandler;

    IUniswapSwapRouter private immutable UniswapRouter =
        IUniswapSwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    ERC20 private constant USDC =
        ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
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

        longPositionHandler = new LongPositionHandler(
            ISwapRouter(address(swapRouter)),
            IConvexRewards(0x3Fe65692bfCD0e6CF84cB1E7d24108E434A7587e),
            ICrvDepositor(0x8014595F2AB54cD7c604B00E9fb932176fDc86Ae),
            self()
        );

        swapRouter.addPositionHandler(self());
        swapAndGetBalances(2);

        emit log_named_address("Self", self());
    }

    function testSuccessfulOpenPosition() public {
        _openPosition();
    }

    function testSuccessfulClosePosition() public {
        _openPosition();
        uint256 initialCvxCRV = swapRouter.CVXCRV().balanceOf(self());
        longPositionHandler.baseRewardPool().withdraw(
            longPositionHandler.baseRewardPool().balanceOf(self()),
            true
        );

        emit log_string("--AFTER POSITION CLOSE--");

        emit log_named_uint("crvBalance", swapRouter.CRV().balanceOf(self()));
        emit log_named_uint(
            "cvxcrvBalance",
            swapRouter.CVXCRV().balanceOf(self())
        );
        emit log_named_uint("cvxBalance", swapRouter.CVX().balanceOf(self()));
        emit log_named_uint(
            "_3crvBalance",
            swapRouter._3CRV().balanceOf(self())
        );
        emit log_named_uint("usdcBalance", swapRouter.USDC().balanceOf(self()));
        emit log_named_uint(
            "Convex Pool Position",
            longPositionHandler.baseRewardPool().balanceOf(self())
        );

        assertEq(
            initialCvxCRV,
            longPositionHandler.baseRewardPool().balanceOf(self())
        );
    }

    function swapAndGetBalances(uint256 _ethToSwap) internal {
        emit log_named_uint("ETH Balance", self().balance / 10**18);

        WETH.deposit{value: _ethToSwap * 10**18}();
        uint256 WETHBalance = WETH.balanceOf(self());
        emit log_named_uint("WETH Balance", WETHBalance / 10**WETH.decimals());

        WETH.approve(address(UniswapRouter), WETHBalance);
    }

    function _openPosition() internal {
        _swapOnUniswap(
            address(WETH),
            address(swapRouter.CRV()),
            WETH.balanceOf(self())
        );

        emit log_string("--INITIAL BALANCE--");
        uint256 crvBalance = swapRouter.CRV().balanceOf(self());
        uint256 cvxcrvBalance = swapRouter.CVXCRV().balanceOf(self());
        emit log_named_uint("CRV Balance", crvBalance);
        emit log_named_uint("CVXCRV Balance", cvxcrvBalance);

        swapRouter.CRV().approve(address(swapRouter), type(uint256).max);
        swapRouter.swapOnCRVCVXCRVPool(true, crvBalance, self());

        emit log_string("--SWAP ON CVXCRV--");
        uint256 newCrvBalance = swapRouter.CRV().balanceOf(self());
        uint256 newCvxcrvBalance = swapRouter.CVXCRV().balanceOf(self());
        emit log_named_uint("CRV Balance", newCrvBalance);
        emit log_named_uint("CVXCRV Balance", newCvxcrvBalance);

        assertLt(newCrvBalance, crvBalance);
        assertGt(newCvxcrvBalance, cvxcrvBalance);

        emit log_string("--STAKE ON CONVEX--");
        uint256 convexPoolPosition = longPositionHandler
            .baseRewardPool()
            .balanceOf(self());
        swapRouter.CVXCRV().approve(
            address(longPositionHandler.baseRewardPool()),
            newCvxcrvBalance
        );
        require(
            longPositionHandler.baseRewardPool().stakeAll(),
            "longPositionHandler :: staking"
        );
        uint256 newConvexPoolPosition = longPositionHandler
            .baseRewardPool()
            .balanceOf(self());

        emit log_named_uint(
            "CVXCRV Balance",
            swapRouter.CVXCRV().balanceOf(self())
        );
        emit log_named_uint("Convex Pool Position", newConvexPoolPosition);
        assertLt(swapRouter.CVXCRV().balanceOf(self()), newCvxcrvBalance);
        assertGt(newConvexPoolPosition, convexPoolPosition);

        assertEq(newConvexPoolPosition, newCvxcrvBalance);
    }

    function _swapOnUniswap(
        address tokenIn,
        address tokenOut,
        uint256 amount
    ) internal {
        IUniswapSwapRouter.ExactInputSingleParams
            memory params = IUniswapSwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: 3000,
                recipient: self(),
                deadline: block.timestamp,
                amountIn: amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        UniswapRouter.exactInputSingle(params);
    }

    function self() internal view returns (address) {
        return address(this);
    }
}
