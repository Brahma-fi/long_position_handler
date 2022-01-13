/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./interface/ISwapRouter.sol";
import "./interface/IOneSplit.sol";
import "./interface/IAggregationRouter.sol";
import "./interface/IChainlinkAggregatorV3.sol";
import "./interface/ICurvePool.sol";

import "./utils/Console.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SwapRouter is ISwapRouter {
    using SafeERC20 for IERC20Metadata;

    IERC20Metadata public immutable override USDC =
        IERC20Metadata(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20Metadata public immutable override CRV =
        IERC20Metadata(0xD533a949740bb3306d119CC777fa900bA034cd52);
    IERC20Metadata public immutable override CVX =
        IERC20Metadata(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    IERC20Metadata public immutable override CVXCRV =
        IERC20Metadata(0x62B9c7356A2Dc64a1969e19C23e4f579F9810Aa7);
    IERC20Metadata public immutable override _3CRV =
        IERC20Metadata(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);

    // 0x1111111254fb6c44bAC0beD2854e76F90643097d
    IAggregationRouter public override oneInchRouter;
    // 0x220bdA5c8994804Ac96ebe4DF184d25e5c2196D4
    address public override aggregationExecutor;

    // 0xCd627aA160A6fA45Eb793D19Ef54f5062F20f33f
    IChainlinkAggregatorV3 public override CRVUSD;
    // 0xd962fC30A72A84cE50161031391756Bf2876Af5D
    IChainlinkAggregatorV3 public override CVXUSD;

    // 0x9D0464996170c6B9e75eED71c68B99dDEDf279e8
    ICurvePool public override crvcvxcrvPool;
    // 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7
    ICurvePool public override _3crvPool;

    address public override governance;

    constructor(
        IAggregationRouter _oneInchRouter,
        address _aggregationExecutor,
        IChainlinkAggregatorV3 _crvusd,
        IChainlinkAggregatorV3 _cvxusd,
        ICurvePool _crvcvxcrvPool,
        ICurvePool __3crvPool,
        address _governance
    ) {
        oneInchRouter = _oneInchRouter;
        aggregationExecutor = _aggregationExecutor;

        CRVUSD = _crvusd;
        CVXUSD = _cvxusd;

        crvcvxcrvPool = _crvcvxcrvPool;
        _3crvPool = __3crvPool;

        governance = _governance;
    }

    /// @dev Direction => True => USDC -> Token
    /// @dev Direction => False =>  Token -> USDC
    function estimateAndSwapTokens(
        bool direction,
        address token,
        uint256 amountToSwap,
        address recipient,
        uint256 slippage,
        bytes memory data
    ) external override returns (uint256 amountOut) {
        require(
            token != address(CRV) && token != address(CVX),
            "SwapRouter :: token"
        );
        require(amountToSwap > 0, "SwapRouter :: amountToSwap");
        require(slippage > 0 && slippage <= 100, "SwapRouter :: slippage");

        IERC20Metadata token0 = direction ? USDC : IERC20Metadata(token);
        IERC20Metadata token1 = direction ? IERC20Metadata(token) : USDC;

        token0.safeTransferFrom(recipient, address(this), amountToSwap);

        uint256 expectedAmountOut = getTokenPriceInUSD(address(token1));

        _swapTokens(
            token0,
            token1,
            amountToSwap,
            expectedAmountOut,
            slippage,
            data
        );
        amountOut = token1.balanceOf(address(this));

        token1.safeTransfer(recipient, amountOut);
        token0.safeTransfer(recipient, token0.balanceOf(address(this)));
    }

    /// @dev Direction => True => CRV -> CVXCRV
    /// @dev Direction => False =>  CVXCRV -> CRV
    function swapOnCRVCVXCRVPool(
        bool direction,
        uint256 amount,
        address recipient
    ) external override returns (uint256 amountOut) {
        IERC20Metadata swapToken = direction ? CRV : CVXCRV;
        IERC20Metadata recievedToken = direction ? CVXCRV : CRV;

        require(
            amount > 0 && amount <= swapToken.balanceOf(msg.sender),
            "SwapRouter :: amount"
        );
        require(recipient != address(0), "SwapRouter :: recipient");

        swapToken.safeTransferFrom(msg.sender, address(this), amount);
        swapToken.safeApprove(address(crvcvxcrvPool), amount);
        crvcvxcrvPool.exchange(
            int8(direction ? 0 : 1),
            int8(direction ? 1 : 0),
            amount,
            0,
            address(this)
        );

        amountOut = recievedToken.balanceOf(address(this));

        swapToken.safeTransfer(recipient, swapToken.balanceOf(address(this)));
        recievedToken.safeTransfer(recipient, amountOut);
    }

    function burn3CRVForUSDC(uint256 amount, address recipient)
        external
        override
        returns (uint256 amountOut)
    {
        require(
            amount > 0 && amount <= _3CRV.balanceOf(msg.sender),
            "SwapRouter :: amount"
        );
        require(recipient != address(0), "SwapRouter :: recipient");

        _3CRV.safeTransferFrom(msg.sender, address(this), amount);
        _3CRV.safeApprove(address(_3crvPool), amount);
        /// @dev i = 1 --> USDC
        _3crvPool.remove_liquidity_one_coin(amount, 1, 0);

        amountOut = USDC.balanceOf(address(this));

        _3CRV.safeTransfer(recipient, amount);
        USDC.safeTransfer(recipient, amountOut);
    }

    function getTokenPriceInUSD(address token) public view returns (uint256) {
        require(
            token == address(CRV) || token == address(CVX),
            "SwapRouter :: token"
        );

        (, int256 answer, , , ) = (token == address(CRV) ? CRVUSD : CVXUSD)
            .latestRoundData();

        return (uint256(answer) / uint256(CRVUSD.decimals())) * USDC.decimals();
    }

    function _swapTokens(
        IERC20Metadata token0,
        IERC20Metadata token1,
        uint256 amount,
        uint256 minReturn,
        uint256 slippage,
        bytes memory data
    ) internal {
        token0.safeApprove(address(oneInchRouter), amount);

        SwapDescription memory desc = SwapDescription({
            srcToken: IERC20(address(token0)),
            dstToken: IERC20(address(token1)),
            srcReceiver: payable(aggregationExecutor),
            dstReceiver: payable(address(this)),
            amount: amount,
            minReturnAmount: (minReturn * (100 - slippage)) / 100,
            flags: 0,
            permit: "0x"
        });

        oneInchRouter.swap(
            IAggregationExecutor(aggregationExecutor),
            desc,
            data
        );
    }

    function sweep() external {
        require(msg.sender == governance, "SwapRouter :: onlyGovernance");

        USDC.transfer(governance, USDC.balanceOf(address(this)));
        CRV.transfer(governance, CRV.balanceOf(address(this)));
        CVX.transfer(governance, CVX.balanceOf(address(this)));
    }
}
