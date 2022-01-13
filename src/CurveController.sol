/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./interface/ISwapRouter.sol";
import "./interface/IConvexRewards.sol";
import "./interface/IPositionHandler.sol";

import "./library/Math.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CurveController is IPositionHandler {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Metadata;

    ISwapRouter public swapRouter;
    // 0x3Fe65692bfCD0e6CF84cB1E7d24108E434A7587e
    IConvexRewards public baseRewardPool;

    address public governance;

    constructor(
        ISwapRouter _swapRouter,
        IConvexRewards _baseRewardPool,
        address _governance
    ) {
        swapRouter = _swapRouter;
        baseRewardPool = _baseRewardPool;

        governance = _governance;
    }

    function openPosition(
        uint256 _amount,
        bool _isLong,
        uint256 _slippage,
        bytes memory _data
    ) external {
        require(_isLong, "CurveController :: not long");
        require(
            _amount > 0 &&
                _amount <= swapRouter.USDC().balanceOf(address(this)),
            "CurveController :: amount"
        );

        /// Convert USDC -> CRV on 1inch
        _safeApproveIfNotApproved(swapRouter.USDC(), address(swapRouter));
        uint256 receivedCRV = swapRouter.estimateAndSwapTokens(
            true,
            address(swapRouter.CRV()),
            _amount,
            address(this),
            _slippage,
            _data
        );

        /// Convert CRV -> cvxCRV on Curve
        _safeApproveIfNotApproved(swapRouter.CRV(), address(swapRouter));
        swapRouter.swapOnCRVCVXCRVPool(true, receivedCRV, address(this));

        /// Stake all cvxCRV on convex
        _safeApproveIfNotApproved(swapRouter.CVXCRV(), address(baseRewardPool));
        require(baseRewardPool.stakeAll(), "CurveController :: staking");
    }

    function closePosition(uint256 _amount) external {
        require(
            _amount > 0 && _amount <= baseRewardPool.balanceOf(address(this)),
            "CurveController :: amount"
        );

        /// Unstake and claim all rewards from convex
        baseRewardPool.withdrawAll(true);

        /// Convert cvxCRV -> CRV on curve
        _safeApproveIfNotApproved(swapRouter.CVXCRV(), address(swapRouter));
        swapRouter.swapOnCRVCVXCRVPool(
            false,
            swapRouter.CVXCRV().balanceOf(address(this)),
            address(this)
        );
    }

    function swapAllTokensToUSDC(
        bytes memory _crvSwapData,
        bytes memory _cvxSwapData,
        uint256 _slippage
    ) external {
        /// Convert CRV -> USDC on 1inch
        if (swapRouter.CRV().balanceOf(address(this)) > 0) {
            _safeApproveIfNotApproved(swapRouter.CRV(), address(swapRouter));
            swapRouter.estimateAndSwapTokens(
                false,
                address(swapRouter.CRV()),
                swapRouter.CRV().balanceOf(address(this)),
                address(this),
                _slippage,
                _crvSwapData
            );
        }

        /// Convert CVX to USDC on 1inch
        if (swapRouter.CVX().balanceOf(address(this)) > 0) {
            _safeApproveIfNotApproved(swapRouter.CVX(), address(swapRouter));
            swapRouter.estimateAndSwapTokens(
                false,
                address(swapRouter.CVX()),
                swapRouter.CVX().balanceOf(address(this)),
                address(this),
                _slippage,
                _cvxSwapData
            );
        }

        /// Burn 3CRV to get USDC on Curve
        if (swapRouter._3CRV().balanceOf(address(this)) > 0) {
            _safeApproveIfNotApproved(swapRouter._3CRV(), address(swapRouter));
            swapRouter.burn3CRVForUSDC(
                swapRouter._3CRV().balanceOf(address(this)),
                address(this)
            );
        }
    }

    function deposit(uint256 _amount) external validTransaction(_amount) {
        swapRouter.USDC().safeTransferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(uint256 _amount)
        external
        validTransaction(_amount)
        returns (
            uint256 amountWithdrawn,
            uint256 pendingWithdrawal,
            uint256 amountUnableToWithdraw
        )
    {
        uint256 usdcBalance = swapRouter.USDC().balanceOf(address(this));

        /// Transfer USDC if sufficient balance
        if (_amount <= usdcBalance) {
            swapRouter.USDC().safeTransfer(msg.sender, _amount);
            amountWithdrawn = _amount;
            pendingWithdrawal = 0;
            amountUnableToWithdraw = 0;
        } else {
            /// If insufficient, transfer all USDC Balance
            amountWithdrawn = usdcBalance;
            swapRouter.USDC().safeTransfer(msg.sender, usdcBalance);
            uint256 pendingAmount = _amount - usdcBalance;

            /// Find amount of cvxCRV to unstake to get pending withdrawals
            uint256 crvPrice = swapRouter.getTokenPriceInUSD(
                address(swapRouter.CRV())
            );
            uint256 cvxcrvBalanceInCRV = swapRouter.crvcvxcrvPool().get_dy(
                1,
                0,
                baseRewardPool.balanceOf(address(this))
            );
            uint256 cvxcrvBalanceInUSDC = (crvPrice * cvxcrvBalanceInCRV);
            uint256 cvxcrvInUSDCToUnstake = Math.min(
                pendingAmount,
                cvxcrvBalanceInUSDC
            );

            /// return pendingWithdrawals & set any amountUnableToWithdraw
            pendingWithdrawal = cvxcrvInUSDCToUnstake / crvPrice;
            amountUnableToWithdraw = Math.min(
                0,
                pendingAmount - cvxcrvInUSDCToUnstake
            );

            /// swap cvxCRV for CRV
            swapRouter.swapOnCRVCVXCRVPool(
                false,
                pendingWithdrawal,
                address(this)
            );
        }
    }

    function allBalances()
        external
        override
        returns (
            uint256 crvBalance,
            uint256 cvxcrvBalance,
            uint256 cvxBalance,
            uint256 _3crvBalance,
            uint256 usdcBalance
        )
    {
        crvBalance = swapRouter.CRV().balanceOf(address(this));
        cvxcrvBalance = swapRouter.CVXCRV().balanceOf(address(this));
        cvxBalance = swapRouter.CVX().balanceOf(address(this));
        _3crvBalance = swapRouter._3CRV().balanceOf(address(this));
        usdcBalance = swapRouter.USDC().balanceOf(address(this));
    }

    function amountInPosition(address _token) external view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function sweep() external {
        require(msg.sender == governance, "CurveController :: Governance");

        swapRouter.CRV().transfer(
            governance,
            swapRouter.CRV().balanceOf(address(this))
        );
        swapRouter.CVXCRV().transfer(
            governance,
            swapRouter.CVXCRV().balanceOf(address(this))
        );
        swapRouter.CVX().transfer(
            governance,
            swapRouter.CVX().balanceOf(address(this))
        );
        swapRouter._3CRV().transfer(
            governance,
            swapRouter._3CRV().balanceOf(address(this))
        );
        swapRouter.USDC().transfer(
            governance,
            swapRouter.USDC().balanceOf(address(this))
        );
    }

    function _safeApproveIfNotApproved(IERC20Metadata token, address spender)
        internal
    {
        if (token.allowance(address(this), spender) < type(uint256).max) {
            token.safeApprove(spender, type(uint256).max);
        }
    }

    modifier validTransaction(uint256 _amount) {
        require(_amount > 0, "CurveController :: amount");
        _;
    }
}
