/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./interface/IHarvester.sol";
import "./interface/ISwapRouter.sol";
import "./interface/IUniswapSwapRouter.sol";
import "./interface/IUniswapV3Factory.sol";
import "./interface/IQuoter.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract Harvester is IHarvester {
    uint256 private immutable MAX_BPS = 10000;

    IUniswapV3Factory private immutable uniswapFactory =
        IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    IUniswapSwapRouter private immutable uniswapRouter =
        IUniswapSwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IQuoter public immutable quoter =
        IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);

    ISwapRouter public swapRouter;

    address public strategist;

    IERC20Metadata public wantToken;
    address[] public override swapTokens;
    uint256 public override numTokens;

    uint256 public slippage;

    constructor(
        address _strategist,
        IERC20Metadata _wantToken,
        ISwapRouter _swapRouter,
        uint256 _slippage
    ) {
        strategist = _strategist;
        swapRouter = _swapRouter;
        wantToken = _wantToken;
        slippage = _slippage;

        swapRouter._3CRV().approve(address(swapRouter), type(uint256).max);
    }

    function setWantToken(address _addr) external override validAddress(_addr) {
        wantToken = IERC20Metadata(_addr);
    }

    function setSlippage(uint256 _slippage) external override onlyStrategist {
        slippage = _slippage;
    }

    function addSwapToken(address _addr) external override validAddress(_addr) {
        swapTokens.push(_addr);
        numTokens++;
    }

    function removeSwapToken(address _addr)
        external
        override
        validAddress(_addr)
    {
        uint256 _initialNumTokens = numTokens;

        for (uint256 idx = 0; idx < _initialNumTokens; idx++) {
            if (swapTokens[idx] == _addr) {
                delete swapTokens[idx];
                numTokens--;
            }
        }

        if (numTokens == _initialNumTokens) {
            revert("_addr does not exist");
        }
    }

    function swap(address sourceToken) public override {
        require(sourceToken != address(0), "sourceToken invalid");

        uint16[3] memory fees = [500, 3000, 10000];
        uint256 sourceTokenBalance = IERC20Metadata(sourceToken).balanceOf(
            address(this)
        );

        if (sourceTokenBalance > 0) {
            uint24 fee;
            for (uint256 idx = 0; idx < fees.length; idx++) {
                if (
                    uniswapFactory.getPool(
                        sourceToken,
                        address(wantToken),
                        fees[idx]
                    ) != address(0)
                ) {
                    fee = fees[idx];
                    break;
                }
            }

            _estimateAndSwap(sourceToken, sourceTokenBalance, fee);
        }
    }

    function harvest() external override {
        for (uint256 idx = 0; idx < swapTokens.length; idx++) {
            IERC20 _token = IERC20(swapTokens[idx]);
            _token.transferFrom(
                msg.sender,
                address(this),
                _token.balanceOf(msg.sender)
            );

            swap(swapTokens[idx]);

            _token.transfer(msg.sender, _token.balanceOf(address(this)));
        }

        ERC20 _3crv = swapRouter._3CRV();

        _3crv.transferFrom(
            msg.sender,
            address(this),
            _3crv.balanceOf(msg.sender)
        );
        swapRouter.burn3CRVForUSDC(_3crv.balanceOf(address(this)), msg.sender);
    }

    function _estimateAndSwap(
        address token,
        uint256 amountToSwap,
        uint24 fee
    ) internal {
        uint256 amountOutMinimum = (quoter.quoteExactInputSingle(
            address(token),
            address(wantToken),
            fee,
            amountToSwap,
            0
        ) * (MAX_BPS - slippage)) / (MAX_BPS);

        _swapTokens(token, fee, amountToSwap, amountOutMinimum);
    }

    function _swapTokens(
        address token,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) internal {
        IERC20Metadata(token).approve(address(uniswapRouter), amountIn);

        IUniswapSwapRouter.ExactInputSingleParams
            memory params = IUniswapSwapRouter.ExactInputSingleParams({
                tokenIn: token,
                tokenOut: address(wantToken),
                fee: fee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0
            });
        uniswapRouter.exactInputSingle(params);
    }

    modifier validAddress(address _addr) {
        require(_addr != address(0), "_addr invalid");
        _;
    }

    modifier onlyStrategist() {
        require(msg.sender == strategist, "auth: strategist");
        _;
    }
}
