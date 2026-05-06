// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IGroupJoinGlobal {
    function gTokenAddressesByGroupIdByAccountCount(uint256 groupId, address account) external view returns (uint256);
}
