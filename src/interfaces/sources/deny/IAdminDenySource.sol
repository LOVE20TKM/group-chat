// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IPostDenySource} from "../IPostDenySource.sol";

interface IAdminDenySource is IPostDenySource {
    error AdminDenySourceAddressHasNoCode();
    error UnauthorizedDenySourceManager();
    error TargetAddressZero();
    error TargetSenderIdZero();
    error SenderPairLengthMismatch();

    event AddressDenySet(
        uint256 indexed groupId,
        address indexed operatorAddress,
        address indexed targetAddress,
        uint256 operatorId,
        bool listed,
        uint256 stateVersion
    );

    event SenderIdDenySet(
        uint256 indexed groupId,
        address indexed operatorAddress,
        uint256 indexed targetSenderId,
        uint256 operatorId,
        bool listed,
        uint256 stateVersion
    );

    event StateVersionChanged(uint256 indexed groupId, uint256 stateVersion);

    function GROUP_ADMIN_ADDRESS() external view returns (address);

    function GROUP_CHAT_ADDRESS() external view returns (address);

    function GROUP_DEFAULTS_ADDRESS() external view returns (address);

    function GROUP_ADDRESS() external view returns (address);

    function MAX_ADMIN_IDS() external view returns (uint256);

    function isAddressDenied(uint256 groupId, address senderAddress) external view returns (bool);

    function isSenderIdDenied(uint256 groupId, uint256 senderId) external view returns (bool);

    function addressDenyDetails(uint256 groupId, address[] calldata senderAddresses)
        external
        view
        returns (bool[] memory denied, address[] memory operatorAddresses, uint256[] memory operatorIds);

    function senderIdDenyDetails(uint256 groupId, uint256[] calldata senderIds)
        external
        view
        returns (bool[] memory denied, address[] memory operatorAddresses, uint256[] memory operatorIds);

    function denyBySenderAddresses(uint256 groupId, address[] calldata senderAddresses) external;

    function undenyBySenderAddresses(uint256 groupId, address[] calldata senderAddresses) external;

    function addressDenyListCount(uint256 groupId) external view returns (uint256);

    function addressDenyList(uint256 groupId, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory senderAddresses, address[] memory operatorAddresses, uint256[] memory operatorIds);

    function denyBySenderIds(uint256 groupId, uint256[] calldata senderIds) external;

    function undenyBySenderIds(uint256 groupId, uint256[] calldata senderIds) external;

    function denyBySenders(uint256 groupId, uint256[] calldata senderIds, address[] calldata senderAddresses)
        external;

    function undenyBySenders(uint256 groupId, uint256[] calldata senderIds, address[] calldata senderAddresses)
        external;

    function senderIdDenyListCount(uint256 groupId) external view returns (uint256);

    function senderIdDenyList(uint256 groupId, uint256 offset, uint256 limit)
        external
        view
        returns (uint256[] memory senderIds, address[] memory operatorAddresses, uint256[] memory operatorIds);

    function stateVersion(uint256 groupId) external view returns (uint256);
}
