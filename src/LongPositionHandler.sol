/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./interface/IHarvester.sol";
import "./interface/ISwapRouter.sol";
import "./interface/IConvexRewards.sol";
import "./interface/ICrvDepositor.sol";
import "./interface/IPositionHandler.sol";
import {ILongPositionHandler} from "./interface/ILongPositionHandler.sol";

import "./library/Math.sol";

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

contract LongPositionHandler is ILongPositionHandler {
    using SafeTransferLib for ERC20;

    IHarvester public override harvester;
    ISwapRouter public override swapRouter;
    // 0x3Fe65692bfCD0e6CF84cB1E7d24108E434A7587e
    IConvexRewards public override baseRewardPool;
    // 0x8014595F2AB54cD7c604B00E9fb932176fDc86Ae
    ICrvDepositor public override crvDepositor;

    address public override governance;

    constructor(
        IHarvester _harvester,
        ISwapRouter _swapRouter,
        IConvexRewards _baseRewardPool,
        ICrvDepositor _crvDepositor,
        address _governance
    ) {
        harvester = _harvester;
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

        swapRouter.USDC().safeApprove(address(harvester), type(uint256).max);
        swapRouter.CRV().safeApprove(address(harvester), type(uint256).max);
        swapRouter.CVX().safeApprove(address(harvester), type(uint256).max);
        swapRouter._3CRV().safeApprove(address(harvester), type(uint256).max);
    }

    function openPosition(bytes calldata data) external override {
        OpenPositionParams memory openPositionParams = abi.decode(
            data,
            (OpenPositionParams)
        );
        require(openPositionParams._isLong, "LongPositionHandler :: not long");
        require(
            openPositionParams._amount > 0 &&
                openPositionParams._amount <=
                swapRouter.USDC().balanceOf(address(this)),
            "LongPositionHandler :: amount"
        );

        /// Convert USDC -> CRV on 1inch
        uint256 receivedCRV = swapRouter.estimateAndSwapTokens(
            true,
            address(swapRouter.CRV()),
            openPositionParams._amount,
            address(this),
            openPositionParams._data
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

    // closePosition: unstake CVXCRV on convex
    function closePosition(bytes calldata data) external override {
        ClosePositionParams memory closePositionParams = abi.decode(
            data,
            (ClosePositionParams)
        );
        require(
            closePositionParams._amount > 0 &&
                closePositionParams._amount <=
                baseRewardPool.balanceOf(address(this)),
            "LongPositionHandler :: amount"
        );

        /// Unstake _amount and claim rewards from convex
        baseRewardPool.withdraw(closePositionParams._amount, true);
    }

    function closePositionAndCompound(bool compoundRewards)
        external
        override
        returns (uint256)
    {
        uint256 stakedCVXCRV = baseRewardPool.balanceOf(address(this));
        /// Unstake all and claim rewards from convex
        baseRewardPool.withdrawAll(true);

        /// Stake back balances
        if (!compoundRewards) {
            /// Stake only principal
            require(
                baseRewardPool.stake(stakedCVXCRV),
                "LongPositionHandler :: staking"
            );
        } else {
            /// Convert CRV to CVXCRV
            swapRouter.swapOnCRVCVXCRVPool(
                true,
                swapRouter.CRV().balanceOf(address(this)),
                address(this)
            );
            /// Stake the entire balance
            require(
                baseRewardPool.stakeAll(),
                "LongPositionHandler :: staking"
            );
        }

        return baseRewardPool.balanceOf(address(this));
    }

    function deposit(bytes calldata data) external override {
        DepositParams memory depositParams = abi.decode(data, (DepositParams));
        validTransaction(depositParams._amount);
        swapRouter.USDC().safeTransferFrom(
            msg.sender,
            address(this),
            depositParams._amount
        );
    }

    function withdraw(bytes calldata data)
        external
        override
        returns (uint256 amountWithdrawn, uint256 amountUnableToWithdraw)
    {
        WithdrawParams memory withdrawParams = abi.decode(
            data,
            (WithdrawParams)
        );
        validTransaction(withdrawParams._amount);

        _convertBalances(withdrawParams._data);

        uint256 usdcBal = swapRouter.USDC().balanceOf(address(this));
        amountWithdrawn = Math.min(usdcBal, withdrawParams._amount);
        amountUnableToWithdraw = usdcBal >= withdrawParams._amount
            ? 0
            : withdrawParams._amount - usdcBal;

        swapRouter.USDC().safeTransfer(msg.sender, amountWithdrawn);
    }

    function claimRewards() external override {
        /// get's all the staking rewards
        require(baseRewardPool.getReward(), "reward claim failed");
        /// convert them to usdc
        _convertBalances("");
        /// send them to strategy
        swapRouter.USDC().safeTransfer(
            msg.sender,
            swapRouter.USDC().balanceOf(address(this))
        );
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
        return
            (crvPrice * _getCVXCRVInPositionInCRV()) /
            10**swapRouter.USDC().decimals();
    }

    function positionInCRV() external view override returns (uint256) {
        return _getCVXCRVInPositionInCRV();
    }

    function amountInPosition(address _token)
        external
        view
        override
        returns (uint256, uint256)
    {
        return (ERC20(_token).balanceOf(address(this)), block.number);
    }

    function sweep(address _token) external override {
        require(msg.sender == governance, "onlyGovernance");

        ERC20(_token).safeTransfer(
            governance,
            swapRouter.CRV().balanceOf(address(this))
        );
    }

    /// @dev pass empty bytes as _cvxcrvSwapData to only convert rewards
    function _convertBalances(bytes memory _cvxcrvSwapData) internal {
        /// Convert CRV -> CVXCRV
        if (swapRouter.CRV().balanceOf(address(this)) > 0) {
            swapRouter.swapOnCRVCVXCRVPool(
                true,
                swapRouter.CRV().balanceOf(address(this)),
                address(this)
            );
        }
        /// Convert CVXCRV -> USDC on 1inch and transfer
        if (
            swapRouter.CVXCRV().balanceOf(address(this)) > 0 &&
            bytes32(_cvxcrvSwapData) != ""
        ) {
            swapRouter.estimateAndSwapTokens(
                false,
                address(swapRouter.CVXCRV()),
                swapRouter.CVXCRV().balanceOf(address(this)),
                address(this),
                _cvxcrvSwapData
            );
        }
        /// Harvest rewards and get USDC converted
        harvester.harvest();
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

    function validTransaction(uint256 _amount) internal pure {
        require(_amount > 0, "LongPositionHandler :: amount");
    }
}
