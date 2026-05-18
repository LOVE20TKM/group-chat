// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupAdmin} from "./interfaces/IGroupAdmin.sol";
import {IGroupChat} from "./interfaces/IGroupChat.sol";
import {IGroupDefaults} from "./interfaces/external/IGroupDefaults.sol";
import {ILOVE20Group} from "./interfaces/external/ILOVE20Group.sol";
import {EnumerableSets} from "./libraries/EnumerableSets.sol";

contract GroupAdmin is IGroupAdmin {
    using EnumerableSets for EnumerableSets.UintSet;

    address public immutable GROUP_CHAT_ADDRESS;
    address public immutable GROUP_DEFAULTS_ADDRESS;
    address public immutable GROUP_ADDRESS;
    uint256 public immutable MAX_ADMIN_IDS;

    struct AdminState {
        EnumerableSets.UintSet adminIds;
        uint256 stateVersion;
    }

    mapping(uint256 => AdminState) internal _states;

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
        uint256 operatorId = ownerOrDelegateIdOf(groupId, msg.sender);
        if (operatorId == 0) {
            revert UnauthorizedGroupAdminManager();
        }
        if (adminIdList.length > MAX_ADMIN_IDS) {
            revert AdminIdsLimitExceeded();
        }
        _validateAdminIds(adminIdList);

        AdminState storage state = _states[groupId];
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
            emit AdminSet(groupId, msg.sender, adminId, operatorId, false, newVersion);
        }

        for (i = 0; i < adminIdList.length; i++) {
            if (state.adminIds.add(adminIdList[i])) {
                newVersion = _ensureStateVersion(state, newVersion);
                emit AdminSet(groupId, msg.sender, adminIdList[i], operatorId, true, newVersion);
            }
        }
        _emitStateVersionChangedIfChanged(groupId, newVersion);
    }

    function adminIdOf(uint256 groupId, address account) public view returns (uint256 adminId) {
        _ownerOfOrRevert(groupId);
        adminId = IGroupDefaults(GROUP_DEFAULTS_ADDRESS).defaultGroupIdOf(account);
        if (adminId == 0 || _tryOwnerOf(adminId) != account || !_states[groupId].adminIds.contains(adminId)) {
            return 0;
        }
    }

    function ownerOrDelegateIdOf(uint256 groupId, address account) public view returns (uint256 operatorId) {
        address chatOwner = _ownerOfOrRevert(groupId);
        if (account == chatOwner) {
            return groupId;
        }

        uint256 delegateId = IGroupChat(GROUP_CHAT_ADDRESS).delegateIdOf(groupId);
        if (delegateId != 0 && account == _tryOwnerOf(delegateId)) {
            return delegateId;
        }
        return 0;
    }

    function isAdminId(uint256 groupId, uint256 adminId) external view returns (bool) {
        return _states[groupId].adminIds.contains(adminId);
    }

    function adminIds(uint256 groupId) external view returns (uint256[] memory) {
        return _states[groupId].adminIds.values;
    }

    function stateVersion(uint256 groupId) external view returns (uint256) {
        return _states[groupId].stateVersion;
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

    function _ensureStateVersion(AdminState storage state, uint256 newVersion) internal returns (uint256) {
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

    function _requireCode(address target) internal view {
        if (target.code.length == 0) {
            revert GroupAdminAddressHasNoCode();
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

    function _contains(uint256[] calldata values, uint256 target) internal pure returns (bool) {
        for (uint256 i = 0; i < values.length; i++) {
            if (values[i] == target) {
                return true;
            }
        }
        return false;
    }
}
