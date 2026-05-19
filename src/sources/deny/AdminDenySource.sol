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

    struct DenyOperatorState {
        address operatorAddress;
        uint256 operatorId;
    }

    struct ChatState {
        EnumerableSets.AddressSet addressDenyList;
        EnumerableSets.UintSet senderIdDenyList;
        mapping(address => DenyOperatorState) addressDenyOperatorStates;
        mapping(uint256 => DenyOperatorState) senderIdDenyOperatorStates;
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

    function isAddressDenied(uint256 groupId, address senderAddress) external view returns (bool) {
        return _states[groupId].addressDenyList.contains(senderAddress);
    }

    function isSenderIdDenied(uint256 groupId, uint256 senderId) external view returns (bool) {
        return _states[groupId].senderIdDenyList.contains(senderId);
    }

    function addressDenyDetails(uint256 groupId, address[] calldata senderAddresses)
        external
        view
        returns (bool[] memory denied, address[] memory operatorAddresses, uint256[] memory operatorIds)
    {
        ChatState storage state = _states[groupId];
        denied = new bool[](senderAddresses.length);
        operatorAddresses = new address[](senderAddresses.length);
        operatorIds = new uint256[](senderAddresses.length);
        for (uint256 i = 0; i < senderAddresses.length; i++) {
            denied[i] = state.addressDenyList.contains(senderAddresses[i]);
            DenyOperatorState storage operatorState = state.addressDenyOperatorStates[senderAddresses[i]];
            operatorAddresses[i] = operatorState.operatorAddress;
            operatorIds[i] = operatorState.operatorId;
        }
    }

    function senderIdDenyDetails(uint256 groupId, uint256[] calldata senderIds)
        external
        view
        returns (bool[] memory denied, address[] memory operatorAddresses, uint256[] memory operatorIds)
    {
        ChatState storage state = _states[groupId];
        denied = new bool[](senderIds.length);
        operatorAddresses = new address[](senderIds.length);
        operatorIds = new uint256[](senderIds.length);
        for (uint256 i = 0; i < senderIds.length; i++) {
            denied[i] = state.senderIdDenyList.contains(senderIds[i]);
            DenyOperatorState storage operatorState = state.senderIdDenyOperatorStates[senderIds[i]];
            operatorAddresses[i] = operatorState.operatorAddress;
            operatorIds[i] = operatorState.operatorId;
        }
    }

    function addressDenyListCount(uint256 groupId) external view returns (uint256) {
        return _states[groupId].addressDenyList.values.length;
    }

    function addressDenyList(uint256 groupId, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory senderAddresses, address[] memory operatorAddresses, uint256[] memory operatorIds)
    {
        ChatState storage state = _states[groupId];
        senderAddresses = state.addressDenyList.page(offset, limit);
        operatorAddresses = new address[](senderAddresses.length);
        operatorIds = new uint256[](senderAddresses.length);
        for (uint256 i = 0; i < senderAddresses.length; i++) {
            DenyOperatorState storage operatorState = state.addressDenyOperatorStates[senderAddresses[i]];
            operatorAddresses[i] = operatorState.operatorAddress;
            operatorIds[i] = operatorState.operatorId;
        }
    }

    function senderIdDenyListCount(uint256 groupId) external view returns (uint256) {
        return _states[groupId].senderIdDenyList.values.length;
    }

    function senderIdDenyList(uint256 groupId, uint256 offset, uint256 limit)
        external
        view
        returns (uint256[] memory senderIds, address[] memory operatorAddresses, uint256[] memory operatorIds)
    {
        ChatState storage state = _states[groupId];
        senderIds = state.senderIdDenyList.page(offset, limit);
        operatorAddresses = new address[](senderIds.length);
        operatorIds = new uint256[](senderIds.length);
        for (uint256 i = 0; i < senderIds.length; i++) {
            DenyOperatorState storage operatorState = state.senderIdDenyOperatorStates[senderIds[i]];
            operatorAddresses[i] = operatorState.operatorAddress;
            operatorIds[i] = operatorState.operatorId;
        }
    }

    function isDenied(uint256 groupId, uint256 senderId, address senderAddress) external view returns (bool) {
        return _isDenied(_states[groupId], senderId, senderAddress);
    }

    function _isDenied(ChatState storage state, uint256 senderId, address senderAddress) internal view returns (bool) {
        return state.addressDenyList.contains(senderAddress) || state.senderIdDenyList.contains(senderId);
    }

    function stateVersion(uint256 groupId) external view returns (uint256) {
        return _states[groupId].stateVersion;
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
                _setSenderIdDenyOperatorState(state, senderId, operatorId, listed);
                newVersion = _ensureStateVersion(state, newVersion);
                _emitSenderIdSet(groupId, operatorId, senderId, listed, newVersion);
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
                _setAddressDenyOperatorState(state, senderAddress, operatorId, listed);
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
            _setAddressDenyOperatorState(state, senderAddress, operatorId, listed);
            newVersion = _ensureStateVersion(state, newVersion);
            _emitAddressDenySet(groupId, operatorId, senderAddress, listed, newVersion);
        }
        if (_setSenderIdList(state.senderIdDenyList, senderId, listed)) {
            _setSenderIdDenyOperatorState(state, senderId, operatorId, listed);
            newVersion = _ensureStateVersion(state, newVersion);
            _emitSenderIdSet(groupId, operatorId, senderId, listed, newVersion);
        }
        return newVersion;
    }

    function _setAddressDenyOperatorState(
        ChatState storage state,
        address senderAddress,
        uint256 operatorId,
        bool listed
    ) internal {
        if (listed) {
            state.addressDenyOperatorStates[senderAddress] = DenyOperatorState(msg.sender, operatorId);
        } else {
            delete state.addressDenyOperatorStates[senderAddress];
        }
    }

    function _setSenderIdDenyOperatorState(ChatState storage state, uint256 senderId, uint256 operatorId, bool listed)
        internal
    {
        if (listed) {
            state.senderIdDenyOperatorStates[senderId] = DenyOperatorState(msg.sender, operatorId);
        } else {
            delete state.senderIdDenyOperatorStates[senderId];
        }
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

    function _emitAddressDenySet(
        uint256 groupId,
        uint256 operatorId,
        address senderAddress,
        bool listed,
        uint256 newVersion
    ) internal {
        emit AddressDenySet(groupId, msg.sender, senderAddress, operatorId, listed, newVersion);
    }

    function _emitSenderIdSet(uint256 groupId, uint256 operatorId, uint256 senderId, bool listed, uint256 newVersion)
        internal
    {
        emit SenderIdDenySet(groupId, msg.sender, senderId, operatorId, listed, newVersion);
    }
}
