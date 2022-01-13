/// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "./interface/ISwapRouter.sol";
import "./interface/IConvexRewards.sol";
import "./interface/IPositionHandler.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CurveController is IPositionHandler {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Metadata;

    ISwapRouter public swapRouter;
    // 0x3Fe65692bfCD0e6CF84cB1E7d24108E434A7587e
    IConvexRewards public baseRewardPool;

    constructor(ISwapRouter _swapRouter, IConvexRewards _baseRewardPool) {
        swapRouter = _swapRouter;
        baseRewardPool = _baseRewardPool;
    }

    function openPosition(
        uint256 _amount,
        bool _isLong,
        bytes memory _data
    ) external {
        require(_isLong, "CurveController :: not long");
        require(
            _amount > 0 &&
                _amount <= swapRouter.USDC().balanceOf(address(this)),
            "CurveController :: amount"
        );

        /// Convert USDC -> CRV on 1inch
        if (
            swapRouter.USDC().allowance(address(this), address(swapRouter)) <
            type(uint256).max
        ) {
            swapRouter.USDC().safeApprove(
                address(swapRouter),
                type(uint256).max
            );
        }
        uint256 receivedCRV = swapRouter.estimateAndSwapTokens(
            true,
            address(swapRouter.CRV()),
            _amount,
            address(this),
            5,
            _data
        );

        /// Convert CRV -> cvxCRV on Curve
        if (
            swapRouter.CRV().allowance(address(this), address(swapRouter)) <
            type(uint256).max
        ) {
            swapRouter.CRV().safeApprove(
                address(swapRouter),
                type(uint256).max
            );
        }
        swapRouter.swapOnCRVCVXCRVPool(true, receivedCRV, address(this));

        /// Stake all cvxCRV on convex
        if (
            swapRouter.CVXCRV().allowance(
                address(this),
                address(baseRewardPool)
            ) < type(uint256).max
        ) {
            swapRouter.CRV().safeApprove(
                address(baseRewardPool),
                type(uint256).max
            );
        }
        require(baseRewardPool.stakeAll(), "CurveController :: staking");
    }

    function closePosition(uint256 _amount, bytes memory _data) external {
        require(_amount > 0, "CurveController :: amount");

        /// Unstake and claim all rewards from convex
        baseRewardPool.withdrawAll(true);

        /// Convert cvxCRV -> CRV on curve
        swapRouter.swapOnCRVCVXCRVPool(
            false,
            swapRouter.CVXCRV().balanceOf(address(this)),
            address(this)
        );

        /// Convert CRV -> USDC on 1inch
        swapRouter.estimateAndSwapTokens(
            false,
            address(swapRouter.CRV()),
            swapRouter.CRV().balanceOf(address(this)),
            address(this),
            5,
            _data
        );

        /// Convert CVX to USDC on 1inch
        swapRouter.estimateAndSwapTokens(
            false,
            address(swapRouter.CVX()),
            swapRouter.CVX().balanceOf(address(this)),
            address(this),
            5,
            _data
        );

        /// Burn 3CRV to get USDC on Curve
        swapRouter.burn3CRVForUSDC(
            swapRouter._3CRV().balanceOf(address(this)),
            address(this)
        );
    }

    function deposit(uint256 _amount) external validTransaction(_amount) {
        swapRouter.USDC().safeTransferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(uint256 _amount) external validTransaction(_amount) {
        // insufficient USDC --> transfer USDC bal --> cvxCRV -> CRV -> USDC --> transfer USDC bal
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
