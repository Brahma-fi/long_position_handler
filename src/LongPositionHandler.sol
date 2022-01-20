/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./interface/ISwapRouter.sol";
import "./interface/IConvexRewards.sol";
import "./interface/ICrvDepositor.sol";
import "./interface/IPositionHandler.sol";
import "./interface/ICurvePool.sol";
import {ILongPositionHandler} from "./interface/ILongPositionHandler.sol";

import "./library/Math.sol";

import {SafeTransferLib} from "./utils/ERC20/SafeTransferLib.sol";
import {ERC20} from "./utils/ERC20/ERC20.sol";

contract LongPositionHandler is ILongPositionHandler {
    using SafeTransferLib for ERC20;

    ISwapRouter public override swapRouter;
    // 0x3Fe65692bfCD0e6CF84cB1E7d24108E434A7587e
    IConvexRewards public override baseRewardPool;
    // 0x8014595F2AB54cD7c604B00E9fb932176fDc86Ae
    ICrvDepositor public override crvDepositor;

    address public override governance;

    constructor(
        ISwapRouter _swapRouter,
        IConvexRewards _baseRewardPool,
        ICrvDepositor _crvDepositor,
        address _governance
    ) {
        swapRouter = _swapRouter;
        baseRewardPool = _baseRewardPool;
        crvDepositor = _crvDepositor;

        governance = _governance;

        swapRouter.USDC().safeApprove(address(swapRouter), type(uint256).max);
        swapRouter.CRV().safeApprove(address(swapRouter), type(uint256).max);
        swapRouter.CVXCRV().safeApprove(address(swapRouter), type(uint256).max);
        swapRouter.CVX().safeApprove(address(swapRouter), type(uint256).max);
        swapRouter._3CRV().safeApprove(address(swapRouter), type(uint256).max);

        swapRouter.CVXCRV().safeApprove(
            address(baseRewardPool),
            type(uint256).max
        );
    }

    function openPosition(
        uint256 _amount,
        bool _isLong,
        bytes memory _data
    ) external override {
        require(_isLong, "LongPositionHandler :: not long");
        require(
            _amount > 0 &&
                _amount <= swapRouter.USDC().balanceOf(address(this)),
            "LongPositionHandler :: amount"
        );

        /// Convert USDC -> CRV on 1inch
        uint256 receivedCRV = swapRouter.estimateAndSwapTokens(
            true,
            address(swapRouter.CRV()),
            _amount,
            address(this),
            _data
        );

        /// Check for expected cvxCRV after swap on curve
        uint256 expectedCvxCrv = swapRouter.crvcvxcrvPool().get_dy(
            0,
            1,
            receivedCRV
        );

        /// If swap on curve is better than 1:1 on convex
        if (receivedCRV < expectedCvxCrv) {
            /// Convert CRV -> cvxCRV on Curve
            swapRouter.swapOnCRVCVXCRVPool(true, receivedCRV, address(this));
            /// Stake all cvxCRV on convex
            require(
                baseRewardPool.stakeAll(),
                "LongPositionHandler :: staking"
            );
        } else {
            /// Else convert & stake directly on convex
            crvDepositor.deposit(receivedCRV, false, address(baseRewardPool));
        }
    }

    function closePosition(uint256 _amount) external override {
        require(
            _amount > 0 && _amount <= baseRewardPool.balanceOf(address(this)),
            "LongPositionHandler :: amount"
        );

        /// Unstake _amount and claim rewards from convex
        baseRewardPool.withdrawAndUnwrap(_amount, true);
    }

    function closePositionAndCompound(bool compoundRewards)
        external
        override
        returns (uint256)
    {
        uint256 stakedCVXCRV = baseRewardPool.balanceOf(address(this));
        /// Unstake all and claim rewards from convex
        baseRewardPool.withdrawAllAndUnwrap(true);

        /// Stake back balances
        if (!compoundRewards) {
            /// Stake only principal
            require(
                baseRewardPool.stake(stakedCVXCRV),
                "LongPositionHandler :: staking"
            );
        } else {
            /// Stake the entire balance
            require(
                baseRewardPool.stakeAll(),
                "LongPositionHandler :: staking"
            );
        }

        return baseRewardPool.balanceOf(address(this));
    }

    function convertBalanceAndWithdraw(bytes memory _cvxcrvSwapData)
        external
        override
    {
        /// Convert CVXCRV -> USDC on 1inch and transfer
        if (swapRouter.CVXCRV().balanceOf(address(this)) > 0) {
            swapRouter.estimateAndSwapTokens(
                false,
                address(swapRouter.CVXCRV()),
                swapRouter.CVXCRV().balanceOf(address(this)),
                address(this),
                _cvxcrvSwapData
            );

            swapRouter.CVXCRV().safeTransfer(
                msg.sender,
                swapRouter.CVXCRV().balanceOf(address(this))
            );
            swapRouter.USDC().safeTransfer(
                msg.sender,
                swapRouter.USDC().balanceOf(address(this))
            );
        }
    }

    function deposit(uint256 _amount)
        external
        override
        validTransaction(_amount)
    {
        swapRouter.USDC().safeTransferFrom(msg.sender, address(this), _amount);
        SafeTransferLib.safeTransferFrom(
            swapRouter.USDC(),
            msg.sender,
            address(this),
            _amount
        );
    }

    function withdraw(uint256 _amount)
        external
        override
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
            // unstake and withdraw cvxcrv
            baseRewardPool.withdraw(pendingAmount, false);
        }
    }

    function allBalances()
        public
        view
        override
        returns (
            uint256 crvBalance,
            uint256 cvxcrvBalance,
            uint256 cvxBalance,
            uint256 _3crvBalance,
            uint256 usdcBalance
        )
    {
        (
            crvBalance,
            cvxcrvBalance,
            cvxBalance,
            _3crvBalance,
            usdcBalance
        ) = _getBalances();
    }

    function balancesInUSDC()
        external
        view
        returns (
            uint256 _crv,
            uint256 _cvx,
            uint256 _cvxcrv,
            uint256 _3crv,
            uint256 _usdc
        )
    {
        (
            uint256 crvBalance,
            uint256 cvxcrvBalance,
            uint256 cvxBalance,
            uint256 _3crvBalance,
            uint256 usdcBalance
        ) = _getBalances();
        uint256 crvPrice = swapRouter.getTokenPriceInUSD(
            address(swapRouter.CRV())
        );

        _usdc = usdcBalance;
        _crv = crvBalance * crvPrice;
        _cvx =
            cvxBalance *
            swapRouter.getTokenPriceInUSD(address(swapRouter.CVX()));
        _cvxcrv =
            swapRouter.crvcvxcrvPool().get_dy(1, 0, cvxcrvBalance) *
            crvPrice;
        _3crv =
            (swapRouter._3crvPool().get_virtual_price() / 1e18) *
            _3crvBalance;
    }

    function positionInUSDC() external view override returns (uint256) {
        uint256 crvPrice = swapRouter.getTokenPriceInUSD(
            address(swapRouter.CRV())
        );

        return crvPrice * _getCVXCRVInPositionInCRV();
    }

    function positionInCRV() external view override returns (uint256) {
        return _getCVXCRVInPositionInCRV();
    }

    function amountInPosition(address _token)
        external
        view
        override
        returns (uint256)
    {
        return ERC20(_token).balanceOf(address(this));
    }

    function sweep(address _token) external override {
        require(msg.sender == governance, "onlyGovernance");

        ERC20(_token).safeTransfer(
            governance,
            swapRouter.CRV().balanceOf(address(this))
        );
    }

    function _getBalances()
        internal
        view
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

    function _getCVXCRVInPositionInCRV() internal view returns (uint256) {
        uint256 stakedCVXCRV = baseRewardPool.balanceOf(address(this));
        return
            stakedCVXCRV != 0
                ? swapRouter.crvcvxcrvPool().get_dy(1, 0, stakedCVXCRV)
                : 0;
    }

    modifier validTransaction(uint256 _amount) {
        require(_amount > 0, "LongPositionHandler :: amount");
        _;
    }
}
