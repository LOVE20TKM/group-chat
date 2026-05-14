// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IPostDenySource} from "../IPostDenySource.sol";

interface IAdminDenySource is IPostDenySource {
    error AdminDenySourceAddressHasNoCode();
    error UnauthorizedDenySourceManager();
    error GroupNotExist();
    error DuplicateAdminId();
    error AdminIdsLimitExceeded();
    error MaxAdminIdsZero();
    error TargetAddressZero();
    error TargetSenderIdZero();
    error SenderPairLengthMismatch();

    event AdminSet(
        uint256 indexed groupId,
        address indexed operator,
        uint256 indexed adminId,
        uint256 operatorId,
        bool listed,
        uint256 stateVersion
    );

    event AddressDenySet(
        uint256 indexed groupId,
        address indexed operator,
        address indexed targetAddress,
        uint256 operatorId,
        bool listed,
        uint256 stateVersion
    );

    event SenderIdDenySet(
        uint256 indexed groupId,
        address indexed operator,
        uint256 indexed targetSenderId,
        uint256 operatorId,
        bool listed,
        uint256 stateVersion
    );

    event SenderIdExemptSet(
        uint256 indexed groupId,
        address indexed operator,
        uint256 indexed targetSenderId,
        uint256 operatorId,
        bool listed,
        uint256 stateVersion
    );

    event StateVersionChanged(uint256 indexed groupId, uint256 stateVersion);

    function GROUP_CHAT_ADDRESS() external view returns (address);

    function GROUP_DEFAULTS_ADDRESS() external view returns (address);

    function GROUP_ADDRESS() external view returns (address);

    function MAX_ADMIN_IDS() external view returns (uint256);

    function setAdmins(uint256 groupId, uint256[] calldata adminIdList) external;

    function isAdminId(uint256 groupId, uint256 adminId) external view returns (bool);

    function adminIds(uint256 groupId) external view returns (uint256[] memory);

    function isAddressDenied(uint256 groupId, address account) external view returns (bool);

    function isSenderIdDenied(uint256 groupId, uint256 senderId) external view returns (bool);

    function isSenderIdExempt(uint256 groupId, uint256 senderId) external view returns (bool);

    function isAddressDeniedBatch(uint256 groupId, address[] calldata accounts)
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

    function denyBySenderAddresses(uint256 groupId, address[] calldata senderAddresses) external;

    function undenyBySenderAddresses(uint256 groupId, address[] calldata senderAddresses) external;

    function addressDenyListCount(uint256 groupId) external view returns (uint256);

    function addressDenyList(uint256 groupId, uint256 offset, uint256 limit) external view returns (address[] memory);

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
        returns (uint256[] memory);

    function exemptSenderIds(uint256 groupId, uint256[] calldata senderIds) external;

    function unexemptSenderIds(uint256 groupId, uint256[] calldata senderIds) external;

    function senderIdExemptListCount(uint256 groupId) external view returns (uint256);

    function senderIdExemptList(uint256 groupId, uint256 offset, uint256 limit)
        external
        view
        returns (uint256[] memory);

    function stateVersion(uint256 groupId) external view returns (uint256);
}
