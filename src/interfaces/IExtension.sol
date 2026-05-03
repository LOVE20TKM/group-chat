// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IExtension {
    function joinedAmountByAccount(address account) external view returns (uint256);
}
