// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseTokenActionGroupChatManager} from "./BaseTokenActionGroupChatManager.sol";

contract TokenActionGovGroupChatManager is BaseTokenActionGroupChatManager {
    constructor(
        address groupChat_,
        address denySource_,
        address beforePostPlugin_,
        address afterPostPlugin_,
        address extensionCenter_,
        uint256 recentRounds_
    )
        BaseTokenActionGroupChatManager(
            groupChat_,
            denySource_,
            beforePostPlugin_,
            afterPostPlugin_,
            extensionCenter_,
            recentRounds_
        )
    {}

    function activate(address token, uint256 actionId) external returns (uint256 chatGroupId) {
        return _activateActionChat(token, actionId, "mgr_action_gov_");
    }

    function canPost(uint256 chatGroupId, uint256, address senderAddress) external view returns (bool) {
        ActionChat storage action = actionOfChatGroup[chatGroupId];
        address token = action.token;
        return token != address(0) && _hasRecentActionVote(token, action.actionId, senderAddress);
    }
}
