// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChat} from "../../interfaces/IGroupChat.sol";

import {IGroupDefaults} from "../../interfaces/external/IGroupDefaults.sol";
import {ILOVE20Group} from "../../interfaces/external/ILOVE20Group.sol";
import {IPostDenySource} from "../../interfaces/sources/IPostDenySource.sol";

contract AdminDenySource is IPostDenySource {
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

    uint8 internal constant _ROLE_OWNER = 1;
    uint8 internal constant _ROLE_DELEGATE = 2;
    address public immutable GROUP_CHAT_ADDRESS;
    address public immutable GROUP_DEFAULTS_ADDRESS;
    address public immutable LOVE20_GROUP_ADDRESS;

    struct AddressSet {
        address[] values;
        mapping(address => uint256) indexPlusOne;
    }

    struct UintSet {
        uint256[] values;
        mapping(uint256 => uint256) indexPlusOne;
    }

    struct ChatState {
        UintSet adminIds;
        AddressSet addressDenyList;
        UintSet senderIdDenyList;
        UintSet senderIdExemptList;
        uint256 stateVersion;
    }

    mapping(uint256 => ChatState) internal _states;

    constructor(address groupChat_) {
        _requireCode(groupChat_);
        address groupDefaults = IGroupChat(groupChat_).GROUP_DEFAULTS_ADDRESS();
        address love20Group = IGroupChat(groupChat_).LOVE20_GROUP_ADDRESS();
        _requireCode(groupDefaults);
        _requireCode(love20Group);

        GROUP_CHAT_ADDRESS = groupChat_;
        GROUP_DEFAULTS_ADDRESS = groupDefaults;
        LOVE20_GROUP_ADDRESS = love20Group;
    }

    function setAdmins(uint256 chatGroupId, uint256[] calldata adminIdList) external {
        (uint8 role, uint256 operatorId) = _roleOf(chatGroupId);
        _requireOwnerOrDelegate(role);
        _validateAdminIds(adminIdList);

        ChatState storage state = _states[chatGroupId];
        uint256 newVersion;
        uint256 i;
        while (i < state.adminIds.values.length) {
            uint256 adminId = state.adminIds.values[i];
            if (_contains(adminIdList, adminId)) {
                i++;
                continue;
            }
            _removeUint(state.adminIds, adminId);
            newVersion = _ensureStateVersion(state, newVersion);
            _emitAdminSet(chatGroupId, operatorId, adminId, false, newVersion);
        }

        for (i = 0; i < adminIdList.length; i++) {
            if (_addUint(state.adminIds, adminIdList[i])) {
                newVersion = _ensureStateVersion(state, newVersion);
                _emitAdminSet(chatGroupId, operatorId, adminIdList[i], true, newVersion);
            }
        }
        _emitStateVersionChangedIfChanged(chatGroupId, newVersion);
    }

    function addDenyListsBySenderIds(uint256 chatGroupId, uint256[] calldata targetSenderIds) external {
        uint256 operatorId = _requireAdmin(chatGroupId);
        ChatState storage state = _states[chatGroupId];
        uint256 newVersion;
        for (uint256 i = 0; i < targetSenderIds.length; i++) {
            uint256 targetSenderId = targetSenderIds[i];
            if (targetSenderId == 0) {
                revert TargetSenderIdZero();
            }
            address targetAddress = _ownerOfOrRevert(targetSenderId);
            newVersion = _addSenderDenyTarget(state, chatGroupId, operatorId, targetSenderId, targetAddress, newVersion);
        }
        _emitStateVersionChangedIfChanged(chatGroupId, newVersion);
    }

    function removeDenyListsBySenderIds(uint256 chatGroupId, uint256[] calldata targetSenderIds) external {
        uint256 operatorId = _requireAdmin(chatGroupId);
        ChatState storage state = _states[chatGroupId];
        uint256 newVersion;
        for (uint256 i = 0; i < targetSenderIds.length; i++) {
            uint256 targetSenderId = targetSenderIds[i];
            if (targetSenderId == 0) {
                revert TargetSenderIdZero();
            }
            address targetAddress = _ownerOfOrRevert(targetSenderId);
            newVersion =
                _removeSenderDenyTarget(state, chatGroupId, operatorId, targetSenderId, targetAddress, newVersion);
        }
        _emitStateVersionChangedIfChanged(chatGroupId, newVersion);
    }

    function addDenyListsBySenderAddresses(uint256 chatGroupId, address[] calldata targetAddresses) external {
        uint256 operatorId = _requireAdmin(chatGroupId);
        ChatState storage state = _states[chatGroupId];
        uint256 newVersion;
        for (uint256 i = 0; i < targetAddresses.length; i++) {
            newVersion = _addSenderAddressDenyTarget(state, chatGroupId, operatorId, targetAddresses[i], newVersion);
        }
        _emitStateVersionChangedIfChanged(chatGroupId, newVersion);
    }

    function removeDenyListsBySenderAddresses(uint256 chatGroupId, address[] calldata targetAddresses) external {
        uint256 operatorId = _requireAdmin(chatGroupId);
        ChatState storage state = _states[chatGroupId];
        uint256 newVersion;
        for (uint256 i = 0; i < targetAddresses.length; i++) {
            newVersion = _removeSenderAddressDenyTarget(state, chatGroupId, operatorId, targetAddresses[i], newVersion);
        }
        _emitStateVersionChangedIfChanged(chatGroupId, newVersion);
    }

    function addExemptListBySenderIds(uint256 chatGroupId, uint256[] calldata senderIds) external {
        (uint8 role, uint256 operatorId) = _roleOf(chatGroupId);
        _requireOwnerOrDelegate(role);
        uint256 newVersion = _addSenderIdExemptTargets(chatGroupId, operatorId, senderIds);
        _emitStateVersionChangedIfChanged(chatGroupId, newVersion);
    }

    function removeExemptListBySenderIds(uint256 chatGroupId, uint256[] calldata senderIds) external {
        (uint8 role, uint256 operatorId) = _roleOf(chatGroupId);
        _requireOwnerOrDelegate(role);
        uint256 newVersion = _removeSenderIdExemptTargets(chatGroupId, operatorId, senderIds);
        _emitStateVersionChangedIfChanged(chatGroupId, newVersion);
    }

    function isAdminId(uint256 chatGroupId, uint256 adminId) external view returns (bool) {
        return _contains(_states[chatGroupId].adminIds, adminId);
    }

    function isAddressDenied(uint256 chatGroupId, address account) external view returns (bool) {
        return _contains(_states[chatGroupId].addressDenyList, account);
    }

    function isSenderIdDenied(uint256 chatGroupId, uint256 senderId) external view returns (bool) {
        return _contains(_states[chatGroupId].senderIdDenyList, senderId);
    }

    function isSenderIdExempt(uint256 chatGroupId, uint256 senderId) external view returns (bool) {
        return _contains(_states[chatGroupId].senderIdExemptList, senderId);
    }

    function adminIdsCount(uint256 chatGroupId) external view returns (uint256) {
        return _states[chatGroupId].adminIds.values.length;
    }

    function adminIds(uint256 chatGroupId, uint256 offset, uint256 limit) external view returns (uint256[] memory) {
        return _page(_states[chatGroupId].adminIds.values, offset, limit);
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

    function senderIdDenyListCount(uint256 chatGroupId) external view returns (uint256) {
        return _states[chatGroupId].senderIdDenyList.values.length;
    }

    function senderIdDenyList(uint256 chatGroupId, uint256 offset, uint256 limit)
        external
        view
        returns (uint256[] memory)
    {
        return _page(_states[chatGroupId].senderIdDenyList.values, offset, limit);
    }

    function senderIdExemptListCount(uint256 chatGroupId) external view returns (uint256) {
        return _states[chatGroupId].senderIdExemptList.values.length;
    }

    function senderIdExemptList(uint256 chatGroupId, uint256 offset, uint256 limit)
        external
        view
        returns (uint256[] memory)
    {
        return _page(_states[chatGroupId].senderIdExemptList.values, offset, limit);
    }

    function isDenied(uint256 chatGroupId, uint256 senderId, address senderAddress) external view returns (bool) {
        ChatState storage state = _states[chatGroupId];
        if (_contains(state.senderIdExemptList, senderId)) {
            return false;
        }
        return _contains(state.addressDenyList, senderAddress) || _contains(state.senderIdDenyList, senderId);
    }

    function stateVersion(uint256 chatGroupId) external view returns (uint256) {
        return _states[chatGroupId].stateVersion;
    }

    function _addSenderIdExemptTargets(uint256 chatGroupId, uint256 operatorId, uint256[] calldata senderIds)
        internal
        returns (uint256 newVersion)
    {
        ChatState storage state = _states[chatGroupId];
        for (uint256 i = 0; i < senderIds.length; i++) {
            uint256 senderId = senderIds[i];
            if (senderId == 0) {
                revert TargetSenderIdZero();
            }
            if (_addUint(state.senderIdExemptList, senderId)) {
                newVersion = _ensureStateVersion(state, newVersion);
                _emitSenderIdSet(chatGroupId, operatorId, senderId, true, false, newVersion);
            }
        }
    }

    function _removeSenderIdExemptTargets(uint256 chatGroupId, uint256 operatorId, uint256[] calldata senderIds)
        internal
        returns (uint256 newVersion)
    {
        ChatState storage state = _states[chatGroupId];
        for (uint256 i = 0; i < senderIds.length; i++) {
            uint256 senderId = senderIds[i];
            if (senderId == 0) {
                revert TargetSenderIdZero();
            }
            if (_removeUint(state.senderIdExemptList, senderId)) {
                newVersion = _ensureStateVersion(state, newVersion);
                _emitSenderIdSet(chatGroupId, operatorId, senderId, false, false, newVersion);
            }
        }
    }

    function _addSenderDenyTarget(
        ChatState storage state,
        uint256 chatGroupId,
        uint256 operatorId,
        uint256 targetSenderId,
        address targetAddress,
        uint256 newVersion
    ) internal returns (uint256) {
        if (targetAddress == address(0)) {
            revert TargetAddressZero();
        }
        if (targetSenderId == 0) {
            revert TargetSenderIdZero();
        }

        if (_addAddress(state.addressDenyList, targetAddress)) {
            newVersion = _ensureStateVersion(state, newVersion);
            _emitAddressDenySet(chatGroupId, operatorId, targetAddress, true, newVersion);
        }
        if (_addUint(state.senderIdDenyList, targetSenderId)) {
            newVersion = _ensureStateVersion(state, newVersion);
            _emitSenderIdSet(chatGroupId, operatorId, targetSenderId, true, true, newVersion);
        }
        return newVersion;
    }

    function _removeSenderDenyTarget(
        ChatState storage state,
        uint256 chatGroupId,
        uint256 operatorId,
        uint256 targetSenderId,
        address targetAddress,
        uint256 newVersion
    ) internal returns (uint256) {
        if (targetAddress == address(0)) {
            revert TargetAddressZero();
        }
        if (targetSenderId == 0) {
            revert TargetSenderIdZero();
        }

        if (_removeAddress(state.addressDenyList, targetAddress)) {
            newVersion = _ensureStateVersion(state, newVersion);
            _emitAddressDenySet(chatGroupId, operatorId, targetAddress, false, newVersion);
        }
        if (_removeUint(state.senderIdDenyList, targetSenderId)) {
            newVersion = _ensureStateVersion(state, newVersion);
            _emitSenderIdSet(chatGroupId, operatorId, targetSenderId, false, true, newVersion);
        }
        return newVersion;
    }

    function _addSenderAddressDenyTarget(
        ChatState storage state,
        uint256 chatGroupId,
        uint256 operatorId,
        address targetAddress,
        uint256 newVersion
    ) internal returns (uint256) {
        if (targetAddress == address(0)) {
            revert TargetAddressZero();
        }

        if (_addAddress(state.addressDenyList, targetAddress)) {
            newVersion = _ensureStateVersion(state, newVersion);
            _emitAddressDenySet(chatGroupId, operatorId, targetAddress, true, newVersion);
        }

        uint256 targetSenderId = _validDefaultGroupIdOf(targetAddress);
        if (targetSenderId != 0 && _addUint(state.senderIdDenyList, targetSenderId)) {
            newVersion = _ensureStateVersion(state, newVersion);
            _emitSenderIdSet(chatGroupId, operatorId, targetSenderId, true, true, newVersion);
        }
        return newVersion;
    }

    function _removeSenderAddressDenyTarget(
        ChatState storage state,
        uint256 chatGroupId,
        uint256 operatorId,
        address targetAddress,
        uint256 newVersion
    ) internal returns (uint256) {
        if (targetAddress == address(0)) {
            revert TargetAddressZero();
        }

        if (_removeAddress(state.addressDenyList, targetAddress)) {
            newVersion = _ensureStateVersion(state, newVersion);
            _emitAddressDenySet(chatGroupId, operatorId, targetAddress, false, newVersion);
        }

        uint256 targetSenderId = _validDefaultGroupIdOf(targetAddress);
        if (targetSenderId != 0 && _removeUint(state.senderIdDenyList, targetSenderId)) {
            newVersion = _ensureStateVersion(state, newVersion);
            _emitSenderIdSet(chatGroupId, operatorId, targetSenderId, false, true, newVersion);
        }
        return newVersion;
    }

    function _roleOf(uint256 chatGroupId) internal view returns (uint8 role, uint256 operatorId) {
        address chatOwner = _ownerOfOrRevert(chatGroupId);
        if (msg.sender == chatOwner) {
            return (_ROLE_OWNER, chatGroupId);
        }

        uint256 delegateId = IGroupChat(GROUP_CHAT_ADDRESS).delegateIdOf(chatGroupId);
        if (delegateId != 0 && msg.sender == _tryOwnerOf(delegateId)) {
            return (_ROLE_DELEGATE, delegateId);
        }

        return (0, IGroupDefaults(GROUP_DEFAULTS_ADDRESS).defaultGroupIdOf(msg.sender));
    }

    function _requireOwnerOrDelegate(uint8 role) internal pure {
        if (role != _ROLE_OWNER && role != _ROLE_DELEGATE) {
            revert UnauthorizedDenySourceManager();
        }
    }

    function _requireAdmin(uint256 chatGroupId) internal view returns (uint256 operatorId) {
        _ownerOfOrRevert(chatGroupId);
        operatorId = _validDefaultGroupIdOf(msg.sender);
        if (operatorId == 0 || !_contains(_states[chatGroupId].adminIds, operatorId)) {
            revert UnauthorizedDenySourceManager();
        }
    }

    function _validateAdminIds(uint256[] calldata adminIdList) internal view {
        for (uint256 i = 0; i < adminIdList.length; i++) {
            _ownerOfOrRevert(adminIdList[i]);
            for (uint256 j = 0; j < i; j++) {
                if (adminIdList[i] == adminIdList[j]) {
                    revert DuplicateAdminId();
                }
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

    function _emitAdminSet(uint256 chatGroupId, uint256 operatorId, uint256 adminId, bool listed, uint256 newVersion)
        internal
    {
        emit AdminSet(chatGroupId, msg.sender, adminId, operatorId, listed, newVersion);
    }

    function _emitAddressDenySet(
        uint256 chatGroupId,
        uint256 operatorId,
        address account,
        bool listed,
        uint256 newVersion
    ) internal {
        emit AddressDenySet(chatGroupId, msg.sender, account, operatorId, listed, newVersion);
    }

    function _emitSenderIdSet(
        uint256 chatGroupId,
        uint256 operatorId,
        uint256 senderId,
        bool listed,
        bool isDeny,
        uint256 newVersion
    ) internal {
        if (isDeny) {
            emit SenderIdDenySet(chatGroupId, msg.sender, senderId, operatorId, listed, newVersion);
        } else {
            emit SenderIdExemptSet(chatGroupId, msg.sender, senderId, operatorId, listed, newVersion);
        }
    }

    function _requireCode(address target) internal view {
        if (target.code.length == 0) {
            revert AdminDenySourceAddressHasNoCode();
        }
    }

    function _ownerOfOrRevert(uint256 groupId) internal view returns (address owner) {
        try ILOVE20Group(LOVE20_GROUP_ADDRESS).ownerOf(groupId) returns (address resolved) {
            return resolved;
        } catch {
            revert GroupNotExist();
        }
    }

    function _tryOwnerOf(uint256 groupId) internal view returns (address owner) {
        try ILOVE20Group(LOVE20_GROUP_ADDRESS).ownerOf(groupId) returns (address resolved) {
            return resolved;
        } catch {
            return address(0);
        }
    }

    function _validDefaultGroupIdOf(address account) internal view returns (uint256 groupId) {
        groupId = IGroupDefaults(GROUP_DEFAULTS_ADDRESS).defaultGroupIdOf(account);
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
