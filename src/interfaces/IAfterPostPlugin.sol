// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IAfterPostPlugin {
    function afterPost(
        uint256 chatGroupId,
        uint256 senderGroupId,
        address senderAddress,
        string calldata content
    ) external;
}
