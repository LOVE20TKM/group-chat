// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IPostDenySource} from "../../IPostDenySource.sol";

interface IAdminDenySource is IPostDenySource {
    error AdminDenySourceAddressHasNoCode();
    error UnauthorizedDenySourceManager();
    error GroupNotExist();
    error DuplicateAdminGroupId();
    error TargetAddressZero();
    error TargetSenderGroupIdZero();

    event AdminSet(
        uint256 indexed chatGroupId,
        address indexed operator,
        uint256 indexed adminGroupId,
        uint256 operatorGroupId,
        bool listed,
        uint256 stateVersion
    );

    event AddressDenySet(
        uint256 indexed chatGroupId,
        address indexed operator,
        address indexed targetAddress,
        uint256 operatorGroupId,
        bool listed,
        uint256 stateVersion
    );

    event SenderGroupIdDenySet(
        uint256 indexed chatGroupId,
        address indexed operator,
        uint256 indexed targetSenderGroupId,
        uint256 operatorGroupId,
        bool listed,
        uint256 stateVersion
    );

    event SenderGroupIdExemptSet(
        uint256 indexed chatGroupId,
        address indexed operator,
        uint256 indexed targetSenderGroupId,
        uint256 operatorGroupId,
        bool listed,
        uint256 stateVersion
    );

    event StateVersionChanged(uint256 indexed chatGroupId, uint256 stateVersion);

    function GROUP_CHAT_ADDRESS() external view returns (address);

    function GROUP_DEFAULTS_ADDRESS() external view returns (address);

    function LOVE20_GROUP_ADDRESS() external view returns (address);

    function setAdmins(uint256 chatGroupId, uint256[] calldata adminGroupIds) external;

    function addDenyListsBySenderGroupIds(uint256 chatGroupId, uint256[] calldata targetSenderGroupIds) external;

    function removeDenyListsBySenderGroupIds(uint256 chatGroupId, uint256[] calldata targetSenderGroupIds) external;

    function addDenyListsBySenderAddresses(uint256 chatGroupId, address[] calldata targetAddresses) external;

    function removeDenyListsBySenderAddresses(uint256 chatGroupId, address[] calldata targetAddresses) external;

    function addExemptListBySenderGroupIds(uint256 chatGroupId, uint256[] calldata senderGroupIds) external;

    function removeExemptListBySenderGroupIds(uint256 chatGroupId, uint256[] calldata senderGroupIds) external;

    function isAdminGroup(uint256 chatGroupId, uint256 adminGroupId) external view returns (bool);

    function isAddressDenied(uint256 chatGroupId, address account) external view returns (bool);

    function isSenderGroupIdDenied(uint256 chatGroupId, uint256 senderGroupId) external view returns (bool);

    function isSenderGroupIdExempt(uint256 chatGroupId, uint256 senderGroupId) external view returns (bool);

    function adminGroupsCount(uint256 chatGroupId) external view returns (uint256);

    function adminGroups(uint256 chatGroupId, uint256 offset, uint256 limit) external view returns (uint256[] memory);

    function addressDenyListCount(uint256 chatGroupId) external view returns (uint256);

    function addressDenyList(uint256 chatGroupId, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory);

    function senderGroupIdDenyListCount(uint256 chatGroupId) external view returns (uint256);

    function senderGroupIdDenyList(uint256 chatGroupId, uint256 offset, uint256 limit)
        external
        view
        returns (uint256[] memory);

    function senderGroupIdExemptListCount(uint256 chatGroupId) external view returns (uint256);

    function senderGroupIdExemptList(uint256 chatGroupId, uint256 offset, uint256 limit)
        external
        view
        returns (uint256[] memory);

    function stateVersion(uint256 chatGroupId) external view returns (uint256);
}
