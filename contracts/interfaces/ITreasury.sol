// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./IEpoch.sol";

interface ITreasury is IEpoch {
    function getDollarPrice() external view returns (uint256);

    function buyBonds(uint256 amount, uint256 targetPrice) external;

    function redeemBonds(uint256 amount, uint256 targetPrice) external;
}
