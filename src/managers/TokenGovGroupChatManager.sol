// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseTokenGroupChatManager} from "./BaseTokenGroupChatManager.sol";

contract TokenGovGroupChatManager is BaseTokenGroupChatManager {
    constructor(
        address groupChat_,
        address denySource_,
        address beforePostPlugin_,
        address afterPostPlugin_,
        address extensionCenter_
    ) BaseTokenGroupChatManager(groupChat_, denySource_, beforePostPlugin_, afterPostPlugin_, extensionCenter_) {}

    function activate(address token) external returns (uint256 chatGroupId) {
        return _activateTokenChat(token, "mgr_token_gov_");
    }

    function canPost(uint256 chatGroupId, uint256, address senderAddress) external view returns (bool) {
        address token = tokenOfChatGroup[chatGroupId];
        return token != address(0) && _tokenGovVoteWeight(token, senderAddress) != 0;
    }
}
