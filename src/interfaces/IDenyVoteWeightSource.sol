// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IDenyVoteWeightSource {
    function denyVoteWeightOf(uint256 chatGroupId, address voter, address targetAddress, uint256 targetSenderId)
        external
        view
        returns (uint256);
}
