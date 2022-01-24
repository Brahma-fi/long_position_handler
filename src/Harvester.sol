/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./interface/IHarvester.sol";
import "./interface/IUniswapSwapRouter.sol";
import "./interface/IQuoter.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract Harvester is IHarvester {
    uint256 private immutable MAX_BPS = 10000;

    IUniswapSwapRouter private immutable uniswapRouter =
        IUniswapSwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IQuoter public immutable quoter =
        IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);

    IERC20Metadata public wantToken;

    address[] public override swapTokens;
    uint256 public override numTokens;

    constructor(IERC20Metadata _wantToken) {
        wantToken = _wantToken;
    }

    function addSwapToken(address _addr) external {
        require(_addr != address(0), "_addr invalid");

        swapTokens.push(_addr);
        numTokens++;
    }

    function removeSwapToken(address _addr) external {
        require(_addr != address(0), "_addr invalid");
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

    function _estimateAndSwap(
        address token,
        uint256 amountToSwap,
        uint256 slippage,
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
}
