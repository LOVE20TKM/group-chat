// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupJoin} from "../../interfaces/external/IGroupJoin.sol";
import {IGroupJoinScopeSource} from "../../interfaces/sources/scope/IGroupJoinScopeSource.sol";
import {IGroupMemberScope} from "../../interfaces/sources/scope/IGroupMemberScope.sol";

contract GroupJoinScopeSource is IGroupJoinScopeSource {
    address public immutable GROUP_MEMBER_SCOPE_ADDRESS;
    address public immutable GROUP_JOIN_ADDRESS;

    constructor(address groupMemberScope_, address groupJoin_) {
        if (groupMemberScope_.code.length == 0 || groupJoin_.code.length == 0) {
            revert GroupJoinScopeSourceAddressHasNoCode();
        }
        GROUP_MEMBER_SCOPE_ADDRESS = groupMemberScope_;
        GROUP_JOIN_ADDRESS = groupJoin_;
    }

    function canPost(uint256 groupId, uint256 senderId, address senderAddress) external view returns (bool) {
        if (IGroupMemberScope(GROUP_MEMBER_SCOPE_ADDRESS).canPost(groupId, senderId, senderAddress)) {
            return true;
        }
        return IGroupJoin(GROUP_JOIN_ADDRESS).gTokenAddressesByGroupIdByAccountCount(groupId, senderAddress) != 0;
    }
}
