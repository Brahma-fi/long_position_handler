/// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

interface IPositionHandler {
    function openPosition(
        uint256 _amount,
        bool _isLong,
        bytes memory _data
    ) external;

    function closePosition(uint256 _amount, bytes memory _data) external;

    function deposit(uint256 _amount) external;

    function withdraw(uint256 _amount) external;

    function amountInPosition(address _token) external view returns (uint256);

    function sweep() external;
}

// Long position handler accepts and gives back only want token i.e., USDC.
// Once recieved USDC --> router --> which accepts destination token --> CRV/CVXCRV depending upon the price.
// CRV/CVXCRV --> staked on convex.
// rewards --> 3 tokens CVX, 3crvlp token, crv token.
// CVXCRV <--> USDC integration with 1inch as seperate module.
// CVXCRV --> CRV in curve pool. CRV --> USDC in curve pool.
