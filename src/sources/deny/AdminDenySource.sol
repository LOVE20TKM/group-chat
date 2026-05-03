// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChat} from "../../interfaces/IGroupChat.sol";
import {IGroupDefaults} from "../../interfaces/IGroupDefaults.sol";
import {ILOVE20Group} from "../../interfaces/ILOVE20Group.sol";
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

    event AddressExemptSet(
        uint256 indexed chatGroupId,
        address indexed operator,
        address indexed targetAddress,
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
    uint8 internal constant _ROLE_ADMIN = 3;

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
        AddressSet addressExemptList;
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
        uint256 i;
        while (i < state.adminGroups.values.length) {
            uint256 adminGroupId = state.adminGroups.values[i];
            if (_contains(adminGroupIds, adminGroupId)) {
                i++;
                continue;
            }
            _removeUint(state.adminGroups, adminGroupId);
            _emitAdminSet(state, chatGroupId, operatorGroupId, adminGroupId, false);
        }

        for (i = 0; i < adminGroupIds.length; i++) {
            if (_addUint(state.adminGroups, adminGroupIds[i])) {
                _emitAdminSet(state, chatGroupId, operatorGroupId, adminGroupIds[i], true);
            }
        }
    }

    function addAddressDenyList(uint256 chatGroupId, address[] calldata accounts) external {
        (uint8 role, uint256 operatorGroupId) = _roleOf(chatGroupId);
        _requireManager(role);
        _addAddressTargets(chatGroupId, operatorGroupId, accounts, true, false);
    }

    function removeAddressDenyList(uint256 chatGroupId, address[] calldata accounts) external {
        (uint8 role, uint256 operatorGroupId) = _roleOf(chatGroupId);
        _requireManager(role);
        _removeAddressTargets(chatGroupId, operatorGroupId, accounts, true);
    }

    function addSenderGroupIdDenyList(uint256 chatGroupId, uint256[] calldata senderGroupIds) external {
        (uint8 role, uint256 operatorGroupId) = _roleOf(chatGroupId);
        _requireManager(role);
        _addUintTargets(chatGroupId, operatorGroupId, senderGroupIds, true, false);
    }

    function removeSenderGroupIdDenyList(uint256 chatGroupId, uint256[] calldata senderGroupIds) external {
        (uint8 role, uint256 operatorGroupId) = _roleOf(chatGroupId);
        _requireManager(role);
        _removeUintTargets(chatGroupId, operatorGroupId, senderGroupIds, true);
    }

    function addAddressExemptList(uint256 chatGroupId, address[] calldata accounts) external {
        (uint8 role, uint256 operatorGroupId) = _roleOf(chatGroupId);
        _requireOwnerOrDelegate(role);
        _addAddressTargets(chatGroupId, operatorGroupId, accounts, false, true);
    }

    function removeAddressExemptList(uint256 chatGroupId, address[] calldata accounts) external {
        (uint8 role, uint256 operatorGroupId) = _roleOf(chatGroupId);
        _requireOwnerOrDelegate(role);
        _removeAddressTargets(chatGroupId, operatorGroupId, accounts, false);
    }

    function addSenderGroupIdExemptList(uint256 chatGroupId, uint256[] calldata senderGroupIds) external {
        (uint8 role, uint256 operatorGroupId) = _roleOf(chatGroupId);
        _requireOwnerOrDelegate(role);
        _addUintTargets(chatGroupId, operatorGroupId, senderGroupIds, false, true);
    }

    function removeSenderGroupIdExemptList(uint256 chatGroupId, uint256[] calldata senderGroupIds) external {
        (uint8 role, uint256 operatorGroupId) = _roleOf(chatGroupId);
        _requireOwnerOrDelegate(role);
        _removeUintTargets(chatGroupId, operatorGroupId, senderGroupIds, false);
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

    function isAddressExempt(uint256 chatGroupId, address account) external view returns (bool) {
        return _contains(_states[chatGroupId].addressExemptList, account);
    }

    function isSenderGroupIdExempt(uint256 chatGroupId, uint256 senderGroupId) external view returns (bool) {
        return _contains(_states[chatGroupId].senderGroupIdExemptList, senderGroupId);
    }

    function adminGroupsCount(uint256 chatGroupId) external view returns (uint256) {
        return _states[chatGroupId].adminGroups.values.length;
    }

    function adminGroups(uint256 chatGroupId, uint256 offset, uint256 limit)
        external
        view
        returns (uint256[] memory)
    {
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

    function addressExemptListCount(uint256 chatGroupId) external view returns (uint256) {
        return _states[chatGroupId].addressExemptList.values.length;
    }

    function addressExemptList(uint256 chatGroupId, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory)
    {
        return _page(_states[chatGroupId].addressExemptList.values, offset, limit);
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

    function isDenied(uint256 chatGroupId, uint256 senderGroupId, address senderAddress)
        external
        view
        returns (bool)
    {
        ChatState storage state = _states[chatGroupId];
        if (_contains(state.addressExemptList, senderAddress) || _contains(state.senderGroupIdExemptList, senderGroupId))
        {
            return false;
        }
        return _contains(state.addressDenyList, senderAddress)
            || _contains(state.senderGroupIdDenyList, senderGroupId);
    }

    function stateVersion(uint256 chatGroupId) external view returns (uint256) {
        return _states[chatGroupId].stateVersion;
    }

    function _addAddressTargets(
        uint256 chatGroupId,
        uint256 operatorGroupId,
        address[] calldata accounts,
        bool isDeny,
        bool
    ) internal {
        ChatState storage state = _states[chatGroupId];
        AddressSet storage set = isDeny ? state.addressDenyList : state.addressExemptList;
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            if (account == address(0)) revert TargetAddressZero();
            if (_addAddress(set, account)) {
                _emitAddressSet(state, chatGroupId, operatorGroupId, account, true, isDeny);
            }
        }
    }

    function _removeAddressTargets(
        uint256 chatGroupId,
        uint256 operatorGroupId,
        address[] calldata accounts,
        bool isDeny
    ) internal {
        ChatState storage state = _states[chatGroupId];
        AddressSet storage set = isDeny ? state.addressDenyList : state.addressExemptList;
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            if (account == address(0)) revert TargetAddressZero();
            if (_removeAddress(set, account)) {
                _emitAddressSet(state, chatGroupId, operatorGroupId, account, false, isDeny);
            }
        }
    }

    function _addUintTargets(
        uint256 chatGroupId,
        uint256 operatorGroupId,
        uint256[] calldata senderGroupIds,
        bool isDeny,
        bool
    ) internal {
        ChatState storage state = _states[chatGroupId];
        UintSet storage set = isDeny ? state.senderGroupIdDenyList : state.senderGroupIdExemptList;
        for (uint256 i = 0; i < senderGroupIds.length; i++) {
            uint256 senderGroupId = senderGroupIds[i];
            if (senderGroupId == 0) revert TargetSenderGroupIdZero();
            if (_addUint(set, senderGroupId)) {
                _emitSenderGroupIdSet(state, chatGroupId, operatorGroupId, senderGroupId, true, isDeny);
            }
        }
    }

    function _removeUintTargets(
        uint256 chatGroupId,
        uint256 operatorGroupId,
        uint256[] calldata senderGroupIds,
        bool isDeny
    ) internal {
        ChatState storage state = _states[chatGroupId];
        UintSet storage set = isDeny ? state.senderGroupIdDenyList : state.senderGroupIdExemptList;
        for (uint256 i = 0; i < senderGroupIds.length; i++) {
            uint256 senderGroupId = senderGroupIds[i];
            if (senderGroupId == 0) revert TargetSenderGroupIdZero();
            if (_removeUint(set, senderGroupId)) {
                _emitSenderGroupIdSet(state, chatGroupId, operatorGroupId, senderGroupId, false, isDeny);
            }
        }
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

        uint256 defaultGroupId = IGroupDefaults(GROUP_DEFAULTS).defaultGroupIdOf(msg.sender);
        if (defaultGroupId != 0 && _contains(_states[chatGroupId].adminGroups, defaultGroupId)) {
            return (_ROLE_ADMIN, defaultGroupId);
        }

        return (0, defaultGroupId);
    }

    function _requireOwnerOrDelegate(uint8 role) internal pure {
        if (role != _ROLE_OWNER && role != _ROLE_DELEGATE) revert UnauthorizedDenySourceManager();
    }

    function _requireManager(uint8 role) internal pure {
        if (role != _ROLE_OWNER && role != _ROLE_DELEGATE && role != _ROLE_ADMIN) {
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

    function _emitAdminSet(
        ChatState storage state,
        uint256 chatGroupId,
        uint256 operatorGroupId,
        uint256 adminGroupId,
        bool listed
    ) internal {
        uint256 newVersion = ++state.stateVersion;
        emit AdminSet(chatGroupId, msg.sender, adminGroupId, operatorGroupId, listed, newVersion);
        emit StateVersionChanged(chatGroupId, newVersion);
    }

    function _emitAddressSet(
        ChatState storage state,
        uint256 chatGroupId,
        uint256 operatorGroupId,
        address account,
        bool listed,
        bool isDeny
    ) internal {
        uint256 newVersion = ++state.stateVersion;
        if (isDeny) {
            emit AddressDenySet(chatGroupId, msg.sender, account, operatorGroupId, listed, newVersion);
        } else {
            emit AddressExemptSet(chatGroupId, msg.sender, account, operatorGroupId, listed, newVersion);
        }
        emit StateVersionChanged(chatGroupId, newVersion);
    }

    function _emitSenderGroupIdSet(
        ChatState storage state,
        uint256 chatGroupId,
        uint256 operatorGroupId,
        uint256 senderGroupId,
        bool listed,
        bool isDeny
    ) internal {
        uint256 newVersion = ++state.stateVersion;
        if (isDeny) {
            emit SenderGroupIdDenySet(chatGroupId, msg.sender, senderGroupId, operatorGroupId, listed, newVersion);
        } else {
            emit SenderGroupIdExemptSet(chatGroupId, msg.sender, senderGroupId, operatorGroupId, listed, newVersion);
        }
        emit StateVersionChanged(chatGroupId, newVersion);
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
