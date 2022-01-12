/// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "./interface/ISwapRouter.sol";
import "./interface/IPositionHandler.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CurveController is IPositionHandler {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Metadata;

    ISwapRouter public swapRouter;

    constructor(ISwapRouter _swapRouter) {
        swapRouter = _swapRouter;
    }

    function openPosition(
        uint256 _amount,
        bool _isLong,
        bytes memory _data
    ) external {}

    function closePosition(uint256 _amount, bytes memory _data) external {}

    function deposit(uint256 _amount) external validTransaction(_amount) {
        swapRouter.USDC().safeTransferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(uint256 _amount) external validTransaction(_amount) {
        swapRouter.USDC().safeTransferFrom(address(this), msg.sender, _amount);
    }

    function amountInPosition(address _token) external view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function sweep() external {}

    modifier validTransaction(uint256 _amount) {
        require(_amount > 0, "CurveController :: amount");
        _;
    }
}
