// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IGroupDefaultsErrors {
    error GroupNotExist();
    error SenderNotGroupOwner();
    error DefaultGroupIdAlreadySet(uint256 groupId);
    error DefaultGroupIdNotSet();
}

interface IGroupDefaultsEvents {
    event SetDefaultGroupId(address indexed account, uint256 indexed groupId);

    event ClearDefaultGroupId(address indexed account, uint256 indexed prevGroupId);
}

interface IGroupDefaults is IGroupDefaultsErrors, IGroupDefaultsEvents {
    function GROUP_ADDRESS() external view returns (address);

    function setDefaultGroupId(uint256 groupId) external;

    function clearDefaultGroupId() external;

    function defaultGroupIdOf(address account) external view returns (uint256);

    function defaultGroupsOf(address[] calldata accounts)
        external
        view
        returns (uint256[] memory groupIds, string[] memory groupNames);
}
