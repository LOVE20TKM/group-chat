// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChat} from "../../interfaces/IGroupChat.sol";

import {IGroupDefaults} from "../../interfaces/external/IGroupDefaults.sol";
import {ILOVE20Group} from "../../interfaces/external/ILOVE20Group.sol";
import {IAdminDenySource} from "../../interfaces/sources/deny/IAdminDenySource.sol";
import {EnumerableSets} from "../../libraries/EnumerableSets.sol";

contract AdminDenySource is IAdminDenySource {
    using EnumerableSets for EnumerableSets.AddressSet;
    using EnumerableSets for EnumerableSets.UintSet;

    uint8 internal constant _ROLE_OWNER = 1;
    uint8 internal constant _ROLE_DELEGATE = 2;
    address public immutable GROUP_CHAT_ADDRESS;
    address public immutable GROUP_DEFAULTS_ADDRESS;
    address public immutable GROUP_ADDRESS;
    uint256 public immutable MAX_ADMIN_IDS;

    struct ChatState {
        EnumerableSets.UintSet adminIds;
        EnumerableSets.AddressSet addressDenyList;
        EnumerableSets.UintSet senderIdDenyList;
        EnumerableSets.UintSet senderIdExemptList;
        uint256 stateVersion;
    }

    mapping(uint256 => ChatState) internal _states;

    constructor(address groupChat_, uint256 maxAdminIds_) {
        if (maxAdminIds_ == 0) {
            revert MaxAdminIdsZero();
        }
        _requireCode(groupChat_);
        address groupDefaults = IGroupChat(groupChat_).GROUP_DEFAULTS_ADDRESS();
        address love20Group = IGroupChat(groupChat_).GROUP_ADDRESS();
        _requireCode(groupDefaults);
        _requireCode(love20Group);

        GROUP_CHAT_ADDRESS = groupChat_;
        GROUP_DEFAULTS_ADDRESS = groupDefaults;
        GROUP_ADDRESS = love20Group;
        MAX_ADMIN_IDS = maxAdminIds_;
    }

    function setAdmins(uint256 groupId, uint256[] calldata adminIdList) external {
        (uint8 role, uint256 operatorId) = _roleOf(groupId);
        _requireOwnerOrDelegate(role);
        if (adminIdList.length > MAX_ADMIN_IDS) {
            revert AdminIdsLimitExceeded();
        }
        _validateAdminIds(adminIdList);

        ChatState storage state = _states[groupId];
        uint256 newVersion;
        uint256 i;
        while (i < state.adminIds.values.length) {
            uint256 adminId = state.adminIds.values[i];
            if (_contains(adminIdList, adminId)) {
                i++;
                continue;
            }
            state.adminIds.remove(adminId);
            newVersion = _ensureStateVersion(state, newVersion);
            _emitAdminSet(groupId, operatorId, adminId, false, newVersion);
        }

        for (i = 0; i < adminIdList.length; i++) {
            if (state.adminIds.add(adminIdList[i])) {
                newVersion = _ensureStateVersion(state, newVersion);
                _emitAdminSet(groupId, operatorId, adminIdList[i], true, newVersion);
            }
        }
        _emitStateVersionChangedIfChanged(groupId, newVersion);
    }

    function denyBySenderIds(uint256 groupId, uint256[] calldata senderIds) external {
        uint256 operatorId = _requireAdmin(groupId);
        uint256 newVersion = _setSenderIdDenyTargets(groupId, operatorId, senderIds, true);
        _emitStateVersionChangedIfChanged(groupId, newVersion);
    }

    function undenyBySenderIds(uint256 groupId, uint256[] calldata senderIds) external {
        uint256 operatorId = _requireAdmin(groupId);
        uint256 newVersion = _setSenderIdDenyTargets(groupId, operatorId, senderIds, false);
        _emitStateVersionChangedIfChanged(groupId, newVersion);
    }

    function denyBySenderAddresses(uint256 groupId, address[] calldata senderAddresses) external {
        uint256 operatorId = _requireAdmin(groupId);
        uint256 newVersion = _setSenderAddressDenyTargets(groupId, operatorId, senderAddresses, true);
        _emitStateVersionChangedIfChanged(groupId, newVersion);
    }

    function undenyBySenderAddresses(uint256 groupId, address[] calldata senderAddresses) external {
        uint256 operatorId = _requireAdmin(groupId);
        uint256 newVersion = _setSenderAddressDenyTargets(groupId, operatorId, senderAddresses, false);
        _emitStateVersionChangedIfChanged(groupId, newVersion);
    }

    function denyBySenders(uint256 groupId, uint256[] calldata senderIds, address[] calldata senderAddresses)
        external
    {
        uint256 operatorId = _requireAdmin(groupId);
        if (senderIds.length != senderAddresses.length) {
            revert SenderPairLengthMismatch();
        }
        ChatState storage state = _states[groupId];
        uint256 newVersion;
        for (uint256 i = 0; i < senderIds.length; i++) {
            newVersion = _addSenderDenyTarget(state, groupId, operatorId, senderIds[i], senderAddresses[i], newVersion);
        }
        _emitStateVersionChangedIfChanged(groupId, newVersion);
    }

    function undenyBySenders(uint256 groupId, uint256[] calldata senderIds, address[] calldata senderAddresses)
        external
    {
        uint256 operatorId = _requireAdmin(groupId);
        if (senderIds.length != senderAddresses.length) {
            revert SenderPairLengthMismatch();
        }
        ChatState storage state = _states[groupId];
        uint256 newVersion;
        for (uint256 i = 0; i < senderIds.length; i++) {
            newVersion =
                _removeSenderDenyTarget(state, groupId, operatorId, senderIds[i], senderAddresses[i], newVersion);
        }
        _emitStateVersionChangedIfChanged(groupId, newVersion);
    }

    function exemptSenderIds(uint256 groupId, uint256[] calldata senderIds) external {
        (uint8 role, uint256 operatorId) = _roleOf(groupId);
        _requireOwnerOrDelegate(role);
        uint256 newVersion = _setSenderIdExemptTargets(groupId, operatorId, senderIds, true);
        _emitStateVersionChangedIfChanged(groupId, newVersion);
    }

    function unexemptSenderIds(uint256 groupId, uint256[] calldata senderIds) external {
        (uint8 role, uint256 operatorId) = _roleOf(groupId);
        _requireOwnerOrDelegate(role);
        uint256 newVersion = _setSenderIdExemptTargets(groupId, operatorId, senderIds, false);
        _emitStateVersionChangedIfChanged(groupId, newVersion);
    }

    function isAdminId(uint256 groupId, uint256 adminId) external view returns (bool) {
        return _states[groupId].adminIds.contains(adminId);
    }

    function isAddressDenied(uint256 groupId, address account) external view returns (bool) {
        return _states[groupId].addressDenyList.contains(account);
    }

    function isSenderIdDenied(uint256 groupId, uint256 senderId) external view returns (bool) {
        return _states[groupId].senderIdDenyList.contains(senderId);
    }

    function isSenderIdExempt(uint256 groupId, uint256 senderId) external view returns (bool) {
        return _states[groupId].senderIdExemptList.contains(senderId);
    }

    function isAddressDeniedBatch(uint256 groupId, address[] calldata accounts)
        external
        view
        returns (bool[] memory denied)
    {
        ChatState storage state = _states[groupId];
        denied = new bool[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            denied[i] = state.addressDenyList.contains(accounts[i]);
        }
    }

    function isSenderIdDeniedBatch(uint256 groupId, uint256[] calldata senderIds)
        external
        view
        returns (bool[] memory denied)
    {
        ChatState storage state = _states[groupId];
        denied = new bool[](senderIds.length);
        for (uint256 i = 0; i < senderIds.length; i++) {
            denied[i] = state.senderIdDenyList.contains(senderIds[i]);
        }
    }

    function isSenderIdExemptBatch(uint256 groupId, uint256[] calldata senderIds)
        external
        view
        returns (bool[] memory exempt)
    {
        ChatState storage state = _states[groupId];
        exempt = new bool[](senderIds.length);
        for (uint256 i = 0; i < senderIds.length; i++) {
            exempt[i] = state.senderIdExemptList.contains(senderIds[i]);
        }
    }

    function adminIds(uint256 groupId) external view returns (uint256[] memory) {
        return _states[groupId].adminIds.values;
    }

    function addressDenyListCount(uint256 groupId) external view returns (uint256) {
        return _states[groupId].addressDenyList.values.length;
    }

    function addressDenyList(uint256 groupId, uint256 offset, uint256 limit) external view returns (address[] memory) {
        return _states[groupId].addressDenyList.page(offset, limit);
    }

    function senderIdDenyListCount(uint256 groupId) external view returns (uint256) {
        return _states[groupId].senderIdDenyList.values.length;
    }

    function senderIdDenyList(uint256 groupId, uint256 offset, uint256 limit)
        external
        view
        returns (uint256[] memory)
    {
        return _states[groupId].senderIdDenyList.page(offset, limit);
    }

    function senderIdExemptListCount(uint256 groupId) external view returns (uint256) {
        return _states[groupId].senderIdExemptList.values.length;
    }

    function senderIdExemptList(uint256 groupId, uint256 offset, uint256 limit)
        external
        view
        returns (uint256[] memory)
    {
        return _states[groupId].senderIdExemptList.page(offset, limit);
    }

    function isDenied(uint256 groupId, uint256 senderId, address senderAddress) external view returns (bool) {
        return _isDenied(_states[groupId], senderId, senderAddress);
    }

    function _isDenied(ChatState storage state, uint256 senderId, address senderAddress) internal view returns (bool) {
        if (state.senderIdExemptList.contains(senderId)) {
            return false;
        }
        return state.addressDenyList.contains(senderAddress) || state.senderIdDenyList.contains(senderId);
    }

    function stateVersion(uint256 groupId) external view returns (uint256) {
        return _states[groupId].stateVersion;
    }

    function _setSenderIdExemptTargets(uint256 groupId, uint256 operatorId, uint256[] calldata senderIds, bool listed)
        internal
        returns (uint256 newVersion)
    {
        ChatState storage state = _states[groupId];
        for (uint256 i = 0; i < senderIds.length; i++) {
            uint256 senderId = senderIds[i];
            _requireSenderIdTarget(senderId);
            bool changed = _setSenderIdList(state.senderIdExemptList, senderId, listed);
            if (changed) {
                newVersion = _ensureStateVersion(state, newVersion);
                _emitSenderIdSet(groupId, operatorId, senderId, listed, false, newVersion);
            }
        }
    }

    function _setSenderIdDenyTargets(uint256 groupId, uint256 operatorId, uint256[] calldata senderIds, bool listed)
        internal
        returns (uint256 newVersion)
    {
        ChatState storage state = _states[groupId];
        for (uint256 i = 0; i < senderIds.length; i++) {
            uint256 senderId = senderIds[i];
            _requireSenderIdTarget(senderId);
            if (_setSenderIdDenyTarget(state, senderId, listed)) {
                newVersion = _ensureStateVersion(state, newVersion);
                _emitSenderIdSet(groupId, operatorId, senderId, listed, true, newVersion);
            }
        }
    }

    function _setSenderAddressDenyTargets(
        uint256 groupId,
        uint256 operatorId,
        address[] calldata senderAddresses,
        bool listed
    ) internal returns (uint256 newVersion) {
        ChatState storage state = _states[groupId];
        for (uint256 i = 0; i < senderAddresses.length; i++) {
            address senderAddress = senderAddresses[i];
            _requireAddressTarget(senderAddress);
            if (_setSenderAddressDenyTarget(state, senderAddress, listed)) {
                newVersion = _ensureStateVersion(state, newVersion);
                _emitAddressDenySet(groupId, operatorId, senderAddress, listed, newVersion);
            }
        }
    }

    function _addSenderDenyTarget(
        ChatState storage state,
        uint256 groupId,
        uint256 operatorId,
        uint256 senderId,
        address senderAddress,
        uint256 newVersion
    ) internal returns (uint256) {
        return _setSenderDenyTarget(state, groupId, operatorId, senderId, senderAddress, true, newVersion);
    }

    function _removeSenderDenyTarget(
        ChatState storage state,
        uint256 groupId,
        uint256 operatorId,
        uint256 senderId,
        address senderAddress,
        uint256 newVersion
    ) internal returns (uint256) {
        return _setSenderDenyTarget(state, groupId, operatorId, senderId, senderAddress, false, newVersion);
    }

    function _setSenderDenyTarget(
        ChatState storage state,
        uint256 groupId,
        uint256 operatorId,
        uint256 senderId,
        address senderAddress,
        bool listed,
        uint256 newVersion
    ) internal returns (uint256) {
        if (senderAddress == address(0)) {
            revert TargetAddressZero();
        }
        if (senderId == 0) {
            revert TargetSenderIdZero();
        }

        if (_setSenderAddressDenyTarget(state, senderAddress, listed)) {
            newVersion = _ensureStateVersion(state, newVersion);
            _emitAddressDenySet(groupId, operatorId, senderAddress, listed, newVersion);
        }
        return _setSenderIdDenyTargetWithEvent(state, groupId, operatorId, senderId, listed, newVersion);
    }

    function _setSenderIdDenyTargetWithEvent(
        ChatState storage state,
        uint256 groupId,
        uint256 operatorId,
        uint256 senderId,
        bool listed,
        uint256 newVersion
    ) internal returns (uint256) {
        if (_setSenderIdDenyTarget(state, senderId, listed)) {
            newVersion = _ensureStateVersion(state, newVersion);
            _emitSenderIdSet(groupId, operatorId, senderId, listed, true, newVersion);
        }
        return newVersion;
    }

    function _setSenderIdDenyTarget(ChatState storage state, uint256 senderId, bool listed) internal returns (bool) {
        return _setSenderIdList(state.senderIdDenyList, senderId, listed);
    }

    function _setSenderAddressDenyTarget(ChatState storage state, address targetAddress, bool listed)
        internal
        returns (bool)
    {
        return _setAddressList(state.addressDenyList, targetAddress, listed);
    }

    function _setSenderIdList(EnumerableSets.UintSet storage set, uint256 senderId, bool listed)
        internal
        returns (bool)
    {
        return listed ? set.add(senderId) : set.remove(senderId);
    }

    function _setAddressList(EnumerableSets.AddressSet storage set, address targetAddress, bool listed)
        internal
        returns (bool)
    {
        return listed ? set.add(targetAddress) : set.remove(targetAddress);
    }

    function _requireSenderIdTarget(uint256 senderId) internal pure {
        if (senderId == 0) {
            revert TargetSenderIdZero();
        }
    }

    function _requireAddressTarget(address senderAddress) internal pure {
        if (senderAddress == address(0)) {
            revert TargetAddressZero();
        }
    }

    function _roleOf(uint256 groupId) internal view returns (uint8 role, uint256 operatorId) {
        address chatOwner = _ownerOfOrRevert(groupId);
        if (msg.sender == chatOwner) {
            return (_ROLE_OWNER, groupId);
        }

        uint256 delegateId = IGroupChat(GROUP_CHAT_ADDRESS).delegateIdOf(groupId);
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

    function _requireAdmin(uint256 groupId) internal view returns (uint256 operatorId) {
        _ownerOfOrRevert(groupId);
        operatorId = _validDefaultGroupIdOf(msg.sender);
        if (operatorId == 0 || !_states[groupId].adminIds.contains(operatorId)) {
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

    function _emitStateVersionChangedIfChanged(uint256 groupId, uint256 newVersion) internal {
        if (newVersion != 0) {
            emit StateVersionChanged(groupId, newVersion);
        }
    }

    function _emitAdminSet(uint256 groupId, uint256 operatorId, uint256 adminId, bool listed, uint256 newVersion)
        internal
    {
        emit AdminSet(groupId, msg.sender, adminId, operatorId, listed, newVersion);
    }

    function _emitAddressDenySet(uint256 groupId, uint256 operatorId, address account, bool listed, uint256 newVersion)
        internal
    {
        emit AddressDenySet(groupId, msg.sender, account, operatorId, listed, newVersion);
    }

    function _emitSenderIdSet(
        uint256 groupId,
        uint256 operatorId,
        uint256 senderId,
        bool listed,
        bool isDeny,
        uint256 newVersion
    ) internal {
        if (isDeny) {
            emit SenderIdDenySet(groupId, msg.sender, senderId, operatorId, listed, newVersion);
        } else {
            emit SenderIdExemptSet(groupId, msg.sender, senderId, operatorId, listed, newVersion);
        }
    }

    function _requireCode(address target) internal view {
        if (target.code.length == 0) {
            revert AdminDenySourceAddressHasNoCode();
        }
    }

    function _ownerOfOrRevert(uint256 groupId) internal view returns (address owner) {
        try ILOVE20Group(GROUP_ADDRESS).ownerOf(groupId) returns (address resolved) {
            return resolved;
        } catch {
            revert GroupNotExist();
        }
    }

    function _tryOwnerOf(uint256 groupId) internal view returns (address owner) {
        try ILOVE20Group(GROUP_ADDRESS).ownerOf(groupId) returns (address resolved) {
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
}
