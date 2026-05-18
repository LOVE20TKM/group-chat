// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupAdmin} from "../../interfaces/IGroupAdmin.sol";
import {IAdminDenySource} from "../../interfaces/sources/deny/IAdminDenySource.sol";
import {EnumerableSets} from "../../libraries/EnumerableSets.sol";

contract AdminDenySource is IAdminDenySource {
    using EnumerableSets for EnumerableSets.AddressSet;
    using EnumerableSets for EnumerableSets.UintSet;

    address public immutable GROUP_ADMIN_ADDRESS;
    address public immutable GROUP_CHAT_ADDRESS;
    address public immutable GROUP_DEFAULTS_ADDRESS;
    address public immutable GROUP_ADDRESS;
    uint256 public immutable MAX_ADMIN_IDS;

    struct ChatState {
        EnumerableSets.AddressSet addressDenyList;
        EnumerableSets.UintSet senderIdDenyList;
        EnumerableSets.UintSet senderIdExemptList;
        uint256 stateVersion;
    }

    mapping(uint256 => ChatState) internal _states;

    constructor(address groupAdmin_) {
        if (groupAdmin_.code.length == 0) {
            revert AdminDenySourceAddressHasNoCode();
        }
        GROUP_ADMIN_ADDRESS = groupAdmin_;
        GROUP_CHAT_ADDRESS = IGroupAdmin(groupAdmin_).GROUP_CHAT_ADDRESS();
        GROUP_DEFAULTS_ADDRESS = IGroupAdmin(groupAdmin_).GROUP_DEFAULTS_ADDRESS();
        GROUP_ADDRESS = IGroupAdmin(groupAdmin_).GROUP_ADDRESS();
        MAX_ADMIN_IDS = IGroupAdmin(groupAdmin_).MAX_ADMIN_IDS();
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
            newVersion =
                _setSenderDenyTarget(state, groupId, operatorId, senderIds[i], senderAddresses[i], true, newVersion);
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
                _setSenderDenyTarget(state, groupId, operatorId, senderIds[i], senderAddresses[i], false, newVersion);
        }
        _emitStateVersionChangedIfChanged(groupId, newVersion);
    }

    function exemptSenderIds(uint256 groupId, uint256[] calldata senderIds) external {
        uint256 operatorId = _requireOwnerOrDelegate(groupId);
        uint256 newVersion = _setSenderIdExemptTargets(groupId, operatorId, senderIds, true);
        _emitStateVersionChangedIfChanged(groupId, newVersion);
    }

    function unexemptSenderIds(uint256 groupId, uint256[] calldata senderIds) external {
        uint256 operatorId = _requireOwnerOrDelegate(groupId);
        uint256 newVersion = _setSenderIdExemptTargets(groupId, operatorId, senderIds, false);
        _emitStateVersionChangedIfChanged(groupId, newVersion);
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
            if (_setSenderIdList(state.senderIdDenyList, senderId, listed)) {
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
            if (_setAddressList(state.addressDenyList, senderAddress, listed)) {
                newVersion = _ensureStateVersion(state, newVersion);
                _emitAddressDenySet(groupId, operatorId, senderAddress, listed, newVersion);
            }
        }
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

        if (_setAddressList(state.addressDenyList, senderAddress, listed)) {
            newVersion = _ensureStateVersion(state, newVersion);
            _emitAddressDenySet(groupId, operatorId, senderAddress, listed, newVersion);
        }
        if (_setSenderIdList(state.senderIdDenyList, senderId, listed)) {
            newVersion = _ensureStateVersion(state, newVersion);
            _emitSenderIdSet(groupId, operatorId, senderId, listed, true, newVersion);
        }
        return newVersion;
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

    function _requireAdmin(uint256 groupId) internal view returns (uint256 operatorId) {
        operatorId = IGroupAdmin(GROUP_ADMIN_ADDRESS).adminIdOf(groupId, msg.sender);
        if (operatorId == 0) {
            revert UnauthorizedDenySourceManager();
        }
    }

    function _requireOwnerOrDelegate(uint256 groupId) internal view returns (uint256 operatorId) {
        operatorId = IGroupAdmin(GROUP_ADMIN_ADDRESS).ownerOrDelegateIdOf(groupId, msg.sender);
        if (operatorId == 0) {
            revert UnauthorizedDenySourceManager();
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
}
