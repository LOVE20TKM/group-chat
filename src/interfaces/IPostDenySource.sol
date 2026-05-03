// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IPostDenySource {
    function isDenied(
        uint256 chatGroupId,
        uint256 senderGroupId,
        address senderAddress
    ) external view returns (bool);
}
