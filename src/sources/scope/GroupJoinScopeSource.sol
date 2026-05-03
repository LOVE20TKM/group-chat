// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupJoinGlobal} from "../../interfaces/IGroupJoinGlobal.sol";
import {IPostScopeSource} from "../../interfaces/IPostScopeSource.sol";

contract GroupJoinScopeSource is IPostScopeSource {
    error GroupJoinScopeSourceAddressHasNoCode();

    address public immutable GROUP_JOIN;

    constructor(address groupJoin_) {
        if (groupJoin_.code.length == 0) revert GroupJoinScopeSourceAddressHasNoCode();
        GROUP_JOIN = groupJoin_;
    }

    function canPost(uint256 chatGroupId, uint256, address senderAddress) external view returns (bool) {
        return IGroupJoinGlobal(GROUP_JOIN).gTokenAddressesByGroupIdByAccountCount(chatGroupId, senderAddress) != 0;
    }
}
