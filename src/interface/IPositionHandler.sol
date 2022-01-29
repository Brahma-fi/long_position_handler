// Long position handler accepts and gives back only want token i.e., USDC.
// Once recieved USDC --> router --> which accepts destination token --> CRV/CVXCRV depending upon the price.
// CRV/CVXCRV --> staked on convex.
// rewards --> 3 tokens CVX, 3crvlp token, crv token.
// CVXCRV <--> USDC integration with 1inch as seperate module.
// CVXCRV --> CRV in curve pool. CRV --> USDC in curve pool.

/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPositionHandler {
    function openPosition(bytes calldata data) external;

    function closePosition(bytes calldata data) external;

    function deposit(bytes calldata data) external;

    function withdraw(bytes calldata data)
        external
        returns (uint256 amountWithdrawn, uint256 amountUnableToWithdraw);

    function amountInPosition(address _token)
        external
        view
        returns (uint256 amount, uint256 blockNumber);

    // function getPnl(address _token) external view returns (int256 pnl, uint256 blockNumber);

    function sweep(address _token) external;
}
