// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChat} from "../../interfaces/IGroupChat.sol";
import {IGroupDefaults} from "../../interfaces/external/IGroupDefaults.sol";
import {ILOVE20Group} from "../../interfaces/external/ILOVE20Group.sol";
import {IPostDenySource} from "../../interfaces/IPostDenySource.sol";

contract AdminDenySource is IPostDenySource {
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

    uint8 internal constant _ROLE_OWNER = 1;
    uint8 internal constant _ROLE_DELEGATE = 2;
    address public immutable GROUP_CHAT;
    address public immutable GROUP_DEFAULTS;
    address public immutable LOVE20_GROUP;

    struct AddressSet {
        address[] values;
        mapping(address => uint256) indexPlusOne;
    }

    struct UintSet {
        uint256[] values;
        mapping(uint256 => uint256) indexPlusOne;
    }

    struct ChatState {
        UintSet adminGroups;
        AddressSet addressDenyList;
        UintSet senderGroupIdDenyList;
        UintSet senderGroupIdExemptList;
        uint256 stateVersion;
    }

    mapping(uint256 => ChatState) internal _states;

    constructor(address groupChat_) {
        _requireCode(groupChat_);
        address groupDefaults = IGroupChat(groupChat_).GROUP_DEFAULTS();
        address love20Group = IGroupChat(groupChat_).LOVE20_GROUP();
        _requireCode(groupDefaults);
        _requireCode(love20Group);

        GROUP_CHAT = groupChat_;
        GROUP_DEFAULTS = groupDefaults;
        LOVE20_GROUP = love20Group;
    }

    function setAdmins(uint256 chatGroupId, uint256[] calldata adminGroupIds) external {
        (uint8 role, uint256 operatorGroupId) = _roleOf(chatGroupId);
        _requireOwnerOrDelegate(role);
        _validateAdminGroupIds(adminGroupIds);

        ChatState storage state = _states[chatGroupId];
        uint256 newVersion;
        uint256 i;
        while (i < state.adminGroups.values.length) {
            uint256 adminGroupId = state.adminGroups.values[i];
            if (_contains(adminGroupIds, adminGroupId)) {
                i++;
                continue;
            }
            _removeUint(state.adminGroups, adminGroupId);
            newVersion = _ensureStateVersion(state, newVersion);
            _emitAdminSet(chatGroupId, operatorGroupId, adminGroupId, false, newVersion);
        }

        for (i = 0; i < adminGroupIds.length; i++) {
            if (_addUint(state.adminGroups, adminGroupIds[i])) {
                newVersion = _ensureStateVersion(state, newVersion);
                _emitAdminSet(chatGroupId, operatorGroupId, adminGroupIds[i], true, newVersion);
            }
        }
        _emitStateVersionChangedIfChanged(chatGroupId, newVersion);
    }

    function addDenyListsBySenderGroupIds(uint256 chatGroupId, uint256[] calldata targetSenderGroupIds) external {
        uint256 operatorGroupId = _requireAdmin(chatGroupId);
        ChatState storage state = _states[chatGroupId];
        uint256 newVersion;
        for (uint256 i = 0; i < targetSenderGroupIds.length; i++) {
            uint256 targetSenderGroupId = targetSenderGroupIds[i];
            if (targetSenderGroupId == 0) revert TargetSenderGroupIdZero();
            address targetAddress = _ownerOfOrRevert(targetSenderGroupId);
            newVersion =
                _addSenderDenyTarget(state, chatGroupId, operatorGroupId, targetSenderGroupId, targetAddress, newVersion);
        }
        _emitStateVersionChangedIfChanged(chatGroupId, newVersion);
    }

    function removeDenyListsBySenderGroupIds(uint256 chatGroupId, uint256[] calldata targetSenderGroupIds) external {
        uint256 operatorGroupId = _requireAdmin(chatGroupId);
        ChatState storage state = _states[chatGroupId];
        uint256 newVersion;
        for (uint256 i = 0; i < targetSenderGroupIds.length; i++) {
            uint256 targetSenderGroupId = targetSenderGroupIds[i];
            if (targetSenderGroupId == 0) revert TargetSenderGroupIdZero();
            address targetAddress = _ownerOfOrRevert(targetSenderGroupId);
            newVersion = _removeSenderDenyTarget(
                state, chatGroupId, operatorGroupId, targetSenderGroupId, targetAddress, newVersion
            );
        }
        _emitStateVersionChangedIfChanged(chatGroupId, newVersion);
    }

    function addDenyListsBySenderAddresses(uint256 chatGroupId, address[] calldata targetAddresses) external {
        uint256 operatorGroupId = _requireAdmin(chatGroupId);
        ChatState storage state = _states[chatGroupId];
        uint256 newVersion;
        for (uint256 i = 0; i < targetAddresses.length; i++) {
            newVersion =
                _addSenderAddressDenyTarget(state, chatGroupId, operatorGroupId, targetAddresses[i], newVersion);
        }
        _emitStateVersionChangedIfChanged(chatGroupId, newVersion);
    }

    function removeDenyListsBySenderAddresses(uint256 chatGroupId, address[] calldata targetAddresses) external {
        uint256 operatorGroupId = _requireAdmin(chatGroupId);
        ChatState storage state = _states[chatGroupId];
        uint256 newVersion;
        for (uint256 i = 0; i < targetAddresses.length; i++) {
            newVersion =
                _removeSenderAddressDenyTarget(state, chatGroupId, operatorGroupId, targetAddresses[i], newVersion);
        }
        _emitStateVersionChangedIfChanged(chatGroupId, newVersion);
    }

    function addExemptListBySenderGroupIds(uint256 chatGroupId, uint256[] calldata senderGroupIds) external {
        (uint8 role, uint256 operatorGroupId) = _roleOf(chatGroupId);
        _requireOwnerOrDelegate(role);
        uint256 newVersion = _addSenderGroupIdExemptTargets(chatGroupId, operatorGroupId, senderGroupIds);
        _emitStateVersionChangedIfChanged(chatGroupId, newVersion);
    }

    function removeExemptListBySenderGroupIds(uint256 chatGroupId, uint256[] calldata senderGroupIds) external {
        (uint8 role, uint256 operatorGroupId) = _roleOf(chatGroupId);
        _requireOwnerOrDelegate(role);
        uint256 newVersion = _removeSenderGroupIdExemptTargets(chatGroupId, operatorGroupId, senderGroupIds);
        _emitStateVersionChangedIfChanged(chatGroupId, newVersion);
    }

    function isAdminGroup(uint256 chatGroupId, uint256 adminGroupId) external view returns (bool) {
        return _contains(_states[chatGroupId].adminGroups, adminGroupId);
    }

    function isAddressDenied(uint256 chatGroupId, address account) external view returns (bool) {
        return _contains(_states[chatGroupId].addressDenyList, account);
    }

    function isSenderGroupIdDenied(uint256 chatGroupId, uint256 senderGroupId) external view returns (bool) {
        return _contains(_states[chatGroupId].senderGroupIdDenyList, senderGroupId);
    }

    function isSenderGroupIdExempt(uint256 chatGroupId, uint256 senderGroupId) external view returns (bool) {
        return _contains(_states[chatGroupId].senderGroupIdExemptList, senderGroupId);
    }

    function adminGroupsCount(uint256 chatGroupId) external view returns (uint256) {
        return _states[chatGroupId].adminGroups.values.length;
    }

    function adminGroups(uint256 chatGroupId, uint256 offset, uint256 limit) external view returns (uint256[] memory) {
        return _page(_states[chatGroupId].adminGroups.values, offset, limit);
    }

    function addressDenyListCount(uint256 chatGroupId) external view returns (uint256) {
        return _states[chatGroupId].addressDenyList.values.length;
    }

    function addressDenyList(uint256 chatGroupId, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory)
    {
        return _page(_states[chatGroupId].addressDenyList.values, offset, limit);
    }

    function senderGroupIdDenyListCount(uint256 chatGroupId) external view returns (uint256) {
        return _states[chatGroupId].senderGroupIdDenyList.values.length;
    }

    function senderGroupIdDenyList(uint256 chatGroupId, uint256 offset, uint256 limit)
        external
        view
        returns (uint256[] memory)
    {
        return _page(_states[chatGroupId].senderGroupIdDenyList.values, offset, limit);
    }

    function senderGroupIdExemptListCount(uint256 chatGroupId) external view returns (uint256) {
        return _states[chatGroupId].senderGroupIdExemptList.values.length;
    }

    function senderGroupIdExemptList(uint256 chatGroupId, uint256 offset, uint256 limit)
        external
        view
        returns (uint256[] memory)
    {
        return _page(_states[chatGroupId].senderGroupIdExemptList.values, offset, limit);
    }

    function isDenied(uint256 chatGroupId, uint256 senderGroupId, address senderAddress) external view returns (bool) {
        ChatState storage state = _states[chatGroupId];
        if (_contains(state.senderGroupIdExemptList, senderGroupId)) {
            return false;
        }
        return _contains(state.addressDenyList, senderAddress) || _contains(state.senderGroupIdDenyList, senderGroupId);
    }

    function stateVersion(uint256 chatGroupId) external view returns (uint256) {
        return _states[chatGroupId].stateVersion;
    }

    function _addSenderGroupIdExemptTargets(
        uint256 chatGroupId,
        uint256 operatorGroupId,
        uint256[] calldata senderGroupIds
    ) internal returns (uint256 newVersion) {
        ChatState storage state = _states[chatGroupId];
        for (uint256 i = 0; i < senderGroupIds.length; i++) {
            uint256 senderGroupId = senderGroupIds[i];
            if (senderGroupId == 0) revert TargetSenderGroupIdZero();
            if (_addUint(state.senderGroupIdExemptList, senderGroupId)) {
                newVersion = _ensureStateVersion(state, newVersion);
                _emitSenderGroupIdSet(chatGroupId, operatorGroupId, senderGroupId, true, false, newVersion);
            }
        }
    }

    function _removeSenderGroupIdExemptTargets(
        uint256 chatGroupId,
        uint256 operatorGroupId,
        uint256[] calldata senderGroupIds
    ) internal returns (uint256 newVersion) {
        ChatState storage state = _states[chatGroupId];
        for (uint256 i = 0; i < senderGroupIds.length; i++) {
            uint256 senderGroupId = senderGroupIds[i];
            if (senderGroupId == 0) revert TargetSenderGroupIdZero();
            if (_removeUint(state.senderGroupIdExemptList, senderGroupId)) {
                newVersion = _ensureStateVersion(state, newVersion);
                _emitSenderGroupIdSet(chatGroupId, operatorGroupId, senderGroupId, false, false, newVersion);
            }
        }
    }

    function _addSenderDenyTarget(
        ChatState storage state,
        uint256 chatGroupId,
        uint256 operatorGroupId,
        uint256 targetSenderGroupId,
        address targetAddress,
        uint256 newVersion
    ) internal returns (uint256) {
        if (targetAddress == address(0)) revert TargetAddressZero();
        if (targetSenderGroupId == 0) revert TargetSenderGroupIdZero();

        if (_addAddress(state.addressDenyList, targetAddress)) {
            newVersion = _ensureStateVersion(state, newVersion);
            _emitAddressDenySet(chatGroupId, operatorGroupId, targetAddress, true, newVersion);
        }
        if (_addUint(state.senderGroupIdDenyList, targetSenderGroupId)) {
            newVersion = _ensureStateVersion(state, newVersion);
            _emitSenderGroupIdSet(chatGroupId, operatorGroupId, targetSenderGroupId, true, true, newVersion);
        }
        return newVersion;
    }

    function _removeSenderDenyTarget(
        ChatState storage state,
        uint256 chatGroupId,
        uint256 operatorGroupId,
        uint256 targetSenderGroupId,
        address targetAddress,
        uint256 newVersion
    ) internal returns (uint256) {
        if (targetAddress == address(0)) revert TargetAddressZero();
        if (targetSenderGroupId == 0) revert TargetSenderGroupIdZero();

        if (_removeAddress(state.addressDenyList, targetAddress)) {
            newVersion = _ensureStateVersion(state, newVersion);
            _emitAddressDenySet(chatGroupId, operatorGroupId, targetAddress, false, newVersion);
        }
        if (_removeUint(state.senderGroupIdDenyList, targetSenderGroupId)) {
            newVersion = _ensureStateVersion(state, newVersion);
            _emitSenderGroupIdSet(chatGroupId, operatorGroupId, targetSenderGroupId, false, true, newVersion);
        }
        return newVersion;
    }

    function _addSenderAddressDenyTarget(
        ChatState storage state,
        uint256 chatGroupId,
        uint256 operatorGroupId,
        address targetAddress,
        uint256 newVersion
    )
        internal
        returns (uint256)
    {
        if (targetAddress == address(0)) revert TargetAddressZero();

        if (_addAddress(state.addressDenyList, targetAddress)) {
            newVersion = _ensureStateVersion(state, newVersion);
            _emitAddressDenySet(chatGroupId, operatorGroupId, targetAddress, true, newVersion);
        }

        uint256 targetSenderGroupId = _validDefaultGroupIdOf(targetAddress);
        if (targetSenderGroupId != 0 && _addUint(state.senderGroupIdDenyList, targetSenderGroupId)) {
            newVersion = _ensureStateVersion(state, newVersion);
            _emitSenderGroupIdSet(chatGroupId, operatorGroupId, targetSenderGroupId, true, true, newVersion);
        }
        return newVersion;
    }

    function _removeSenderAddressDenyTarget(
        ChatState storage state,
        uint256 chatGroupId,
        uint256 operatorGroupId,
        address targetAddress,
        uint256 newVersion
    )
        internal
        returns (uint256)
    {
        if (targetAddress == address(0)) revert TargetAddressZero();

        if (_removeAddress(state.addressDenyList, targetAddress)) {
            newVersion = _ensureStateVersion(state, newVersion);
            _emitAddressDenySet(chatGroupId, operatorGroupId, targetAddress, false, newVersion);
        }

        uint256 targetSenderGroupId = _validDefaultGroupIdOf(targetAddress);
        if (targetSenderGroupId != 0 && _removeUint(state.senderGroupIdDenyList, targetSenderGroupId)) {
            newVersion = _ensureStateVersion(state, newVersion);
            _emitSenderGroupIdSet(chatGroupId, operatorGroupId, targetSenderGroupId, false, true, newVersion);
        }
        return newVersion;
    }

    function _roleOf(uint256 chatGroupId) internal view returns (uint8 role, uint256 operatorGroupId) {
        address chatOwner = _ownerOfOrRevert(chatGroupId);
        if (msg.sender == chatOwner) {
            return (_ROLE_OWNER, chatGroupId);
        }

        uint256 delegateGroupId = IGroupChat(GROUP_CHAT).delegateGroupIdOf(chatGroupId);
        if (delegateGroupId != 0 && msg.sender == _tryOwnerOf(delegateGroupId)) {
            return (_ROLE_DELEGATE, delegateGroupId);
        }

        return (0, IGroupDefaults(GROUP_DEFAULTS).defaultGroupIdOf(msg.sender));
    }

    function _requireOwnerOrDelegate(uint8 role) internal pure {
        if (role != _ROLE_OWNER && role != _ROLE_DELEGATE) revert UnauthorizedDenySourceManager();
    }

    function _requireAdmin(uint256 chatGroupId) internal view returns (uint256 operatorGroupId) {
        _ownerOfOrRevert(chatGroupId);
        operatorGroupId = _validDefaultGroupIdOf(msg.sender);
        if (operatorGroupId == 0 || !_contains(_states[chatGroupId].adminGroups, operatorGroupId)) {
            revert UnauthorizedDenySourceManager();
        }
    }

    function _validateAdminGroupIds(uint256[] calldata adminGroupIds) internal view {
        for (uint256 i = 0; i < adminGroupIds.length; i++) {
            _ownerOfOrRevert(adminGroupIds[i]);
            for (uint256 j = 0; j < i; j++) {
                if (adminGroupIds[i] == adminGroupIds[j]) revert DuplicateAdminGroupId();
            }
        }
    }

    function _ensureStateVersion(ChatState storage state, uint256 newVersion) internal returns (uint256) {
        if (newVersion == 0) {
            newVersion = ++state.stateVersion;
        }
        return newVersion;
    }

    function _emitStateVersionChangedIfChanged(uint256 chatGroupId, uint256 newVersion) internal {
        if (newVersion != 0) {
            emit StateVersionChanged(chatGroupId, newVersion);
        }
    }

    function _emitAdminSet(
        uint256 chatGroupId,
        uint256 operatorGroupId,
        uint256 adminGroupId,
        bool listed,
        uint256 newVersion
    ) internal {
        emit AdminSet(chatGroupId, msg.sender, adminGroupId, operatorGroupId, listed, newVersion);
    }

    function _emitAddressDenySet(
        uint256 chatGroupId,
        uint256 operatorGroupId,
        address account,
        bool listed,
        uint256 newVersion
    ) internal {
        emit AddressDenySet(chatGroupId, msg.sender, account, operatorGroupId, listed, newVersion);
    }

    function _emitSenderGroupIdSet(
        uint256 chatGroupId,
        uint256 operatorGroupId,
        uint256 senderGroupId,
        bool listed,
        bool isDeny,
        uint256 newVersion
    ) internal {
        if (isDeny) {
            emit SenderGroupIdDenySet(chatGroupId, msg.sender, senderGroupId, operatorGroupId, listed, newVersion);
        } else {
            emit SenderGroupIdExemptSet(chatGroupId, msg.sender, senderGroupId, operatorGroupId, listed, newVersion);
        }
    }

    function _requireCode(address target) internal view {
        if (target.code.length == 0) revert AdminDenySourceAddressHasNoCode();
    }

    function _ownerOfOrRevert(uint256 groupId) internal view returns (address owner) {
        try ILOVE20Group(LOVE20_GROUP).ownerOf(groupId) returns (address resolved) {
            return resolved;
        } catch {
            revert GroupNotExist();
        }
    }

    function _tryOwnerOf(uint256 groupId) internal view returns (address owner) {
        try ILOVE20Group(LOVE20_GROUP).ownerOf(groupId) returns (address resolved) {
            return resolved;
        } catch {
            return address(0);
        }
    }

    function _validDefaultGroupIdOf(address account) internal view returns (uint256 groupId) {
        groupId = IGroupDefaults(GROUP_DEFAULTS).defaultGroupIdOf(account);
        if (groupId == 0 || _tryOwnerOf(groupId) != account) {
            return 0;
        }
    }

    function _contains(uint256[] calldata values, uint256 target) internal pure returns (bool) {
        for (uint256 i = 0; i < values.length; i++) {
            if (values[i] == target) {
                return true;
            }
        }
        return false;
    }

    function _contains(AddressSet storage set, address value) internal view returns (bool) {
        return set.indexPlusOne[value] != 0;
    }

    function _contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return set.indexPlusOne[value] != 0;
    }

    function _addAddress(AddressSet storage set, address value) internal returns (bool) {
        if (_contains(set, value)) {
            return false;
        }
        set.values.push(value);
        set.indexPlusOne[value] = set.values.length;
        return true;
    }

    function _removeAddress(AddressSet storage set, address value) internal returns (bool) {
        uint256 indexPlusOne = set.indexPlusOne[value];
        if (indexPlusOne == 0) {
            return false;
        }

        uint256 index = indexPlusOne - 1;
        uint256 lastIndex = set.values.length - 1;
        if (index != lastIndex) {
            address last = set.values[lastIndex];
            set.values[index] = last;
            set.indexPlusOne[last] = indexPlusOne;
        }
        set.values.pop();
        delete set.indexPlusOne[value];
        return true;
    }

    function _addUint(UintSet storage set, uint256 value) internal returns (bool) {
        if (_contains(set, value)) {
            return false;
        }
        set.values.push(value);
        set.indexPlusOne[value] = set.values.length;
        return true;
    }

    function _removeUint(UintSet storage set, uint256 value) internal returns (bool) {
        uint256 indexPlusOne = set.indexPlusOne[value];
        if (indexPlusOne == 0) {
            return false;
        }

        uint256 index = indexPlusOne - 1;
        uint256 lastIndex = set.values.length - 1;
        if (index != lastIndex) {
            uint256 last = set.values[lastIndex];
            set.values[index] = last;
            set.indexPlusOne[last] = indexPlusOne;
        }
        set.values.pop();
        delete set.indexPlusOne[value];
        return true;
    }

    function _page(address[] storage values, uint256 offset, uint256 limit) internal view returns (address[] memory) {
        uint256 count = _pageCount(values.length, offset, limit);
        address[] memory result = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = values[offset + i];
        }
        return result;
    }

    function _page(uint256[] storage values, uint256 offset, uint256 limit) internal view returns (uint256[] memory) {
        uint256 count = _pageCount(values.length, offset, limit);
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = values[offset + i];
        }
        return result;
    }

    function _pageCount(uint256 total, uint256 offset, uint256 limit) internal pure returns (uint256) {
        if (limit == 0 || offset >= total) {
            return 0;
        }

        uint256 remaining = total - offset;
        return remaining < limit ? remaining : limit;
    }
}
