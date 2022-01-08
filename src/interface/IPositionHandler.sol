/// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

interface IPositionHandler {
    function openPosition(
        address _token,
        uint256 _amount,
        bool _isLong
    ) external;

    function closePosition(address _token, uint256 _amount) external;

    function deposit(address _token, uint256 _amount) external;

    function withdraw(address _token, uint256 _amount) external;

    function amountInPosition(address _token) external view returns (uint256);
}

// Long position handler accepts and gives back only want token i.e., USDC.
// Once recieved USDC --> router --> which accepts destination token --> CRV/CVXCRV depending upon the price.
// CRV/CVXCRV --> staked on convex.
// rewards --> 3 tokens CVX, 3crvlp token, crv token.
// CVXCRV <--> USDC integration with 1inch as seperate module.
// CVXCRV --> CRV in curve pool. CRV --> USDC in curve pool.
