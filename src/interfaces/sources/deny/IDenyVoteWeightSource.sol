// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IDenyVoteWeightSource {
    function denyVoteWeightOf(uint256 groupId, address voter) external view returns (uint256);

    function denyVoteTotalWeightOf(uint256 groupId) external view returns (uint256);
}
