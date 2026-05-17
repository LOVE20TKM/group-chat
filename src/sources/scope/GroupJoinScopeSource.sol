// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupJoin} from "../../interfaces/external/IGroupJoin.sol";
import {IGroupJoinScopeSource} from "../../interfaces/sources/scope/IGroupJoinScopeSource.sol";

contract GroupJoinScopeSource is IGroupJoinScopeSource {
    address public immutable GROUP_JOIN_ADDRESS;

    constructor(address groupJoin_) {
        if (groupJoin_.code.length == 0) {
            revert GroupJoinScopeSourceAddressHasNoCode();
        }
        GROUP_JOIN_ADDRESS = groupJoin_;
    }

    function canPost(uint256 groupId, uint256, address senderAddress) external view returns (bool) {
        return IGroupJoin(GROUP_JOIN_ADDRESS).gTokenAddressesByGroupIdByAccountCount(groupId, senderAddress) != 0;
    }
}
