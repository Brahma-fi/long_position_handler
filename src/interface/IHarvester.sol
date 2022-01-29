// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

interface IHarvester {
    function swapTokens(uint256 idx) external returns (address);

    function numTokens() external returns (uint256);

    function setWantToken(address _addr) external;

    function setSlippage(uint256 _slippage) external;

    // Add token to be swapped via 1inch
    function addSwapToken(address _addr) external;

    // Remove token to be swapped via 1inch
    function removeSwapToken(address _addr) external;

    // Swap tokens to wantToken
    function harvest() external;

    //1inch swap config add any required params
    function swap(address sourceToken) external;
}
