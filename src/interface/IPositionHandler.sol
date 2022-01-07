pragma solidity ^0.8.0;

interface IPositionHandler {

    function openPosition(address _token, uint256 _amount, bool _isLong) external;

    function closePosition(address _token, uint256 _amount) external;

    function deposit(address _token, uint256 _amount) external;

    function withdraw(address _token, uint256 _amount) external;

    function amountInPosition() external view returns (uint256);

}