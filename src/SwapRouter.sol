/// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "./interface/ISwapRouter.sol";
import "./interface/IOneSplit.sol";
import "./interface/IAggregationRouter.sol";
import "./interface/IChainlinkAggregatorV3.sol";

import "./utils/Console.sol";

import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract SwapRouter is ISwapRouter {
    using SafeERC20 for IERC20Metadata;

    IERC20Metadata public immutable USDC =
        IERC20Metadata(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20Metadata public immutable CRV =
        IERC20Metadata(0xD533a949740bb3306d119CC777fa900bA034cd52);
    IERC20Metadata public immutable CVX =
        IERC20Metadata(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);

    // 0x1111111254fb6c44bAC0beD2854e76F90643097d
    IAggregationRouter public oneInchRouter;
    // 0x220bdA5c8994804Ac96ebe4DF184d25e5c2196D4
    address public aggregationExecutor;

    // 0xCd627aA160A6fA45Eb793D19Ef54f5062F20f33f
    IChainlinkAggregatorV3 public CRVUSD;
    // 0xd962fC30A72A84cE50161031391756Bf2876Af5D
    IChainlinkAggregatorV3 public CVXUSD;

    constructor(
        IAggregationRouter _oneInchRouter,
        address _aggregationExecutor,
        IChainlinkAggregatorV3 _crvusd,
        IChainlinkAggregatorV3 _cvxusd
    ) {
        oneInchRouter = _oneInchRouter;
        aggregationExecutor = _aggregationExecutor;

        CRVUSD = _crvusd;
        CVXUSD = _cvxusd;
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
    ) external returns (uint256 amountOut) {
        require(
            token != address(CRV) && token != address(CVX),
            "SwapRouter :: token"
        );
        require(amountToSwap > 0, "SwapRouter :: amountToSwap");
        require(slippage > 0 && slippage <= 100, "SwapRouter :: slippage");

        IERC20Metadata token0 = direction ? USDC : IERC20Metadata(token);
        IERC20Metadata token1 = direction ? IERC20Metadata(token) : USDC;

        token0.safeTransferFrom(recipient, address(this), amountToSwap);

        uint256 expectedAmountOut = _getTokenPriceInUSD(address(token1));

        _swapTokens(
            token0,
            token1,
            amountToSwap,
            expectedAmountOut,
            slippage,
            data
        );
        amountOut = token1.balanceOf(address(this));

        token1.safeTransferFrom(address(this), recipient, amountOut);
        token0.safeTransferFrom(
            address(this),
            recipient,
            token0.balanceOf(address(this))
        );
    }

    function _getTokenPriceInUSD(address token)
        internal
        view
        returns (uint256)
    {
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
        token0.approve(address(oneInchRouter), amount);

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
}
