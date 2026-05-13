// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseTokenActionManager} from "./BaseTokenActionManager.sol";

contract TokenActionGovManager is BaseTokenActionManager {
    constructor(
        address groupChat_,
        address denySource_,
        address beforePostPlugin_,
        address afterPostPlugin_,
        address extensionCenter_,
        uint256 recentRounds_
    )
        BaseTokenActionManager(
            groupChat_,
            denySource_,
            beforePostPlugin_,
            afterPostPlugin_,
            extensionCenter_,
            recentRounds_
        )
    {}

    function activate(address token, uint256 actionId) external returns (uint256 groupId) {
        return _activateManagedAction(token, actionId, "mgr_action_gov_");
    }

    function canPost(uint256 groupId, uint256, address senderAddress) external view returns (bool) {
        ManagedAction storage action = actionOfGroup[groupId];
        address token = action.token;
        return token != address(0) && _hasRecentActionVote(token, action.actionId, senderAddress);
    }
}
