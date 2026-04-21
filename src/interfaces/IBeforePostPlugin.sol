// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IBeforePostPlugin {
    function beforePost(
        uint256 chatGroupId,
        uint256 senderGroupId,
        address senderAddress,
        string calldata content,
        uint256[] calldata mentions,
        bool mentionAll,
        uint256 quotedMessageIndex
    ) external;
}
