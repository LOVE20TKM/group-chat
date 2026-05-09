// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupJoinGlobal} from "../../interfaces/external/IGroupJoinGlobal.sol";
import {IPostScopeSource} from "../../interfaces/sources/IPostScopeSource.sol";

contract GroupJoinScopeSource is IPostScopeSource {
    error GroupJoinScopeSourceAddressHasNoCode();

    address public immutable GROUP_JOIN_ADDRESS;

    constructor(address groupJoin_) {
        if (groupJoin_.code.length == 0) {
            revert GroupJoinScopeSourceAddressHasNoCode();
        }
        GROUP_JOIN_ADDRESS = groupJoin_;
    }

    function canPost(uint256 groupId, uint256, address senderAddress) external view returns (bool) {
        return IGroupJoinGlobal(GROUP_JOIN_ADDRESS).gTokenAddressesByGroupIdByAccountCount(groupId, senderAddress) != 0;
    }
}
