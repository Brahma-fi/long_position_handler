/// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

interface ICurvePool {
    function exchange(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _min_dy,
        address _receiver
    ) external returns (uint256);

    function remove_liquidity_one_coin(
        uint256 _token_amount,
        int128 i,
        uint256 min_amount
    ) external;
}
