// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IPostDenySource} from "../IPostDenySource.sol";

interface IAdminDenySource is IPostDenySource {
    error AdminDenySourceAddressHasNoCode();
    error UnauthorizedDenySourceManager();
    error GroupNotExist();
    error DuplicateAdminId();
    error TargetAddressZero();
    error TargetSenderIdZero();

    event AdminSet(
        uint256 indexed chatGroupId,
        address indexed operator,
        uint256 indexed adminId,
        uint256 operatorId,
        bool listed,
        uint256 stateVersion
    );

    event AddressDenySet(
        uint256 indexed chatGroupId,
        address indexed operator,
        address indexed targetAddress,
        uint256 operatorId,
        bool listed,
        uint256 stateVersion
    );

    event SenderIdDenySet(
        uint256 indexed chatGroupId,
        address indexed operator,
        uint256 indexed targetSenderId,
        uint256 operatorId,
        bool listed,
        uint256 stateVersion
    );

    event SenderIdExemptSet(
        uint256 indexed chatGroupId,
        address indexed operator,
        uint256 indexed targetSenderId,
        uint256 operatorId,
        bool listed,
        uint256 stateVersion
    );

    event StateVersionChanged(uint256 indexed chatGroupId, uint256 stateVersion);

    function GROUP_CHAT_ADDRESS() external view returns (address);

    function GROUP_DEFAULTS_ADDRESS() external view returns (address);

    function LOVE20_GROUP_ADDRESS() external view returns (address);

    function setAdmins(uint256 chatGroupId, uint256[] calldata adminIdList) external;

    function isAdminId(uint256 chatGroupId, uint256 adminId) external view returns (bool);

    function adminIdsCount(uint256 chatGroupId) external view returns (uint256);

    function adminIds(uint256 chatGroupId, uint256 offset, uint256 limit) external view returns (uint256[] memory);

    function addDenyListsBySenderAddresses(uint256 chatGroupId, address[] calldata targetAddresses) external;

    function removeDenyListsBySenderAddresses(uint256 chatGroupId, address[] calldata targetAddresses) external;

    function isAddressDenied(uint256 chatGroupId, address account) external view returns (bool);

    function addressDenyListCount(uint256 chatGroupId) external view returns (uint256);

    function addressDenyList(uint256 chatGroupId, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory);

    function addDenyListsBySenderIds(uint256 chatGroupId, uint256[] calldata targetSenderIds) external;

    function removeDenyListsBySenderIds(uint256 chatGroupId, uint256[] calldata targetSenderIds) external;

    function isSenderIdDenied(uint256 chatGroupId, uint256 senderId) external view returns (bool);

    function senderIdDenyListCount(uint256 chatGroupId) external view returns (uint256);

    function senderIdDenyList(uint256 chatGroupId, uint256 offset, uint256 limit)
        external
        view
        returns (uint256[] memory);

    function addExemptListBySenderIds(uint256 chatGroupId, uint256[] calldata senderIds) external;

    function removeExemptListBySenderIds(uint256 chatGroupId, uint256[] calldata senderIds) external;

    function isSenderIdExempt(uint256 chatGroupId, uint256 senderId) external view returns (bool);

    function senderIdExemptListCount(uint256 chatGroupId) external view returns (uint256);

    function senderIdExemptList(uint256 chatGroupId, uint256 offset, uint256 limit)
        external
        view
        returns (uint256[] memory);

    function stateVersion(uint256 chatGroupId) external view returns (uint256);
}
