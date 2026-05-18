// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IGroupAdmin {
    error GroupAdminAddressHasNoCode();
    error UnauthorizedGroupAdminManager();
    error GroupNotExist();
    error DuplicateAdminId();
    error AdminIdsLimitExceeded();
    error MaxAdminIdsZero();

    event AdminSet(
        uint256 indexed groupId,
        address indexed operator,
        uint256 indexed adminId,
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

    function adminIdOf(uint256 groupId, address account) external view returns (uint256);

    function ownerOrDelegateIdOf(uint256 groupId, address account) external view returns (uint256);

    function isAdminId(uint256 groupId, uint256 adminId) external view returns (bool);

    function adminIds(uint256 groupId) external view returns (uint256[] memory);

    function stateVersion(uint256 groupId) external view returns (uint256);
}
