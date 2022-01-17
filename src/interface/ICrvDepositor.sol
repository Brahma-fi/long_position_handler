/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface ICrvDepositor {
    function deposit(
        uint256 _amount,
        bool _lock,
        address _stakeAddress
    ) external;
}
