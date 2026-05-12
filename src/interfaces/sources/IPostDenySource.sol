// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IPostDenySource {
    function isDenied(uint256 groupId, uint256 senderId, address senderAddress) external view returns (bool);

    function isAddressDenied(uint256 groupId, address senderAddress) external view returns (bool);

    function isSenderIdDenied(uint256 groupId, uint256 senderId) external view returns (bool);

    function isSenderIdExempt(uint256 groupId, uint256 senderId) external view returns (bool);

    function isAddressDeniedBatch(uint256 groupId, address[] calldata senderAddresses)
        external
        view
        returns (bool[] memory denied);

    function isSenderIdDeniedBatch(uint256 groupId, uint256[] calldata senderIds)
        external
        view
        returns (bool[] memory denied);

    function isSenderIdExemptBatch(uint256 groupId, uint256[] calldata senderIds)
        external
        view
        returns (bool[] memory exempt);
}
