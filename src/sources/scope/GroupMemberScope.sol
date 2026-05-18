// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupAdmin} from "../../interfaces/IGroupAdmin.sol";
import {ILOVE20Group} from "../../interfaces/external/ILOVE20Group.sol";
import {IGroupMemberScope} from "../../interfaces/sources/scope/IGroupMemberScope.sol";
import {EnumerableSets} from "../../libraries/EnumerableSets.sol";

contract GroupMemberScope is IGroupMemberScope {
    using EnumerableSets for EnumerableSets.UintSet;

    address public immutable GROUP_ADMIN_ADDRESS;
    address public immutable GROUP_ADDRESS;

    struct MemberState {
        EnumerableSets.UintSet memberIds;
        uint256 stateVersion;
    }

    mapping(uint256 => MemberState) internal _states;

    constructor(address groupAdmin_) {
        if (groupAdmin_.code.length == 0) {
            revert GroupMemberScopeAddressHasNoCode();
        }
        GROUP_ADMIN_ADDRESS = groupAdmin_;
        GROUP_ADDRESS = IGroupAdmin(groupAdmin_).GROUP_ADDRESS();
    }

    function addMemberIds(uint256 groupId, uint256[] calldata memberIdList) external {
        uint256 operatorId = _requireAdmin(groupId);
        uint256 newVersion = _setMemberIds(groupId, operatorId, memberIdList, true);
        _emitStateVersionChangedIfChanged(groupId, newVersion);
    }

    function removeMemberIds(uint256 groupId, uint256[] calldata memberIdList) external {
        uint256 operatorId = _requireAdmin(groupId);
        uint256 newVersion = _setMemberIds(groupId, operatorId, memberIdList, false);
        _emitStateVersionChangedIfChanged(groupId, newVersion);
    }

    function isMemberId(uint256 groupId, uint256 memberId) external view returns (bool) {
        return _states[groupId].memberIds.contains(memberId);
    }

    function isMemberIdBatch(uint256 groupId, uint256[] calldata memberIdList)
        external
        view
        returns (bool[] memory listed)
    {
        MemberState storage state = _states[groupId];
        listed = new bool[](memberIdList.length);
        for (uint256 i = 0; i < memberIdList.length; i++) {
            listed[i] = state.memberIds.contains(memberIdList[i]);
        }
    }

    function memberIdsCount(uint256 groupId) external view returns (uint256) {
        return _states[groupId].memberIds.values.length;
    }

    function memberIds(uint256 groupId, uint256 offset, uint256 limit) external view returns (uint256[] memory) {
        return _states[groupId].memberIds.page(offset, limit);
    }

    function stateVersion(uint256 groupId) external view returns (uint256) {
        return _states[groupId].stateVersion;
    }

    function canPost(uint256 groupId, uint256 senderId, address) external view returns (bool) {
        return _states[groupId].memberIds.contains(senderId);
    }

    function _setMemberIds(uint256 groupId, uint256 operatorId, uint256[] calldata memberIdList, bool listed)
        internal
        returns (uint256 newVersion)
    {
        MemberState storage state = _states[groupId];
        for (uint256 i = 0; i < memberIdList.length; i++) {
            uint256 memberId = memberIdList[i];
            _requireMemberIdTarget(memberId);
            if (_setMemberId(state.memberIds, memberId, listed)) {
                newVersion = _ensureStateVersion(state, newVersion);
                emit MemberIdSet(groupId, msg.sender, memberId, operatorId, listed, newVersion);
            }
        }
    }

    function _setMemberId(EnumerableSets.UintSet storage set, uint256 memberId, bool listed) internal returns (bool) {
        return listed ? set.add(memberId) : set.remove(memberId);
    }

    function _requireAdmin(uint256 groupId) internal view returns (uint256 operatorId) {
        operatorId = IGroupAdmin(GROUP_ADMIN_ADDRESS).adminIdOf(groupId, msg.sender);
        if (operatorId == 0) {
            revert UnauthorizedGroupMemberScopeManager();
        }
    }

    function _requireMemberIdTarget(uint256 memberId) internal view {
        if (memberId == 0) {
            revert TargetMemberIdZero();
        }
        _ownerOfOrRevert(memberId);
    }

    function _ensureStateVersion(MemberState storage state, uint256 newVersion) internal returns (uint256) {
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

    function _ownerOfOrRevert(uint256 groupId) internal view returns (address owner) {
        try ILOVE20Group(GROUP_ADDRESS).ownerOf(groupId) returns (address resolved) {
            return resolved;
        } catch {
            revert GroupNotExist();
        }
    }
}
