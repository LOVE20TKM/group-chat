// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IERC20Balance} from "../interfaces/external/IERC20Balance.sol";
import {IExtensionCenter} from "../interfaces/external/IExtensionCenter.sol";
import {ILOVE20Join} from "../interfaces/external/ILOVE20Join.sol";
import {ILOVE20Vote} from "../interfaces/external/ILOVE20Vote.sol";
import {BaseTokenGroupChatManager} from "./BaseTokenGroupChatManager.sol";

contract TokenGroupChatManager is BaseTokenGroupChatManager {
    address public immutable JOIN_ADDRESS;
    address public immutable VOTE_ADDRESS;

    constructor(
        address groupChat_,
        address denySource_,
        address beforePostPlugin_,
        address afterPostPlugin_,
        address extensionCenter_
    ) BaseTokenGroupChatManager(groupChat_, denySource_, beforePostPlugin_, afterPostPlugin_, extensionCenter_) {
        address join = IExtensionCenter(extensionCenter_).joinAddress();
        address vote = IExtensionCenter(extensionCenter_).voteAddress();
        _requireCode(join);
        _requireCode(vote);

        JOIN_ADDRESS = join;
        VOTE_ADDRESS = vote;
    }

    function activate(address token) external returns (uint256 chatGroupId) {
        return _activateTokenChat(token, "mgr_token_");
    }

    function canPost(uint256 chatGroupId, uint256, address senderAddress) external view returns (bool) {
        address token = tokenOfChatGroup[chatGroupId];
        return token != address(0)
            && (
                _hasTokenBalance(token, senderAddress) || _tokenGovVoteWeight(token, senderAddress) != 0
                    || _hasTokenActionParticipation(token, senderAddress)
            );
    }

    function _hasTokenBalance(address token, address account) internal view returns (bool) {
        return IERC20Balance(token).balanceOf(account) > 1;
    }

    function _hasTokenActionParticipation(address token, address account) internal view returns (bool) {
        return ILOVE20Join(JOIN_ADDRESS).amountByAccount(token, account) != 0
            || _hasCurrentRoundExtensionActionParticipation(token, account);
    }

    function _hasCurrentRoundExtensionActionParticipation(address token, address account)
        internal
        view
        returns (bool)
    {
        uint256 round = ILOVE20Join(JOIN_ADDRESS).currentRound();
        uint256 count = ILOVE20Vote(VOTE_ADDRESS).votedActionIdsCount(token, round);

        for (uint256 i = 0; i < count; i++) {
            uint256 actionId = ILOVE20Vote(VOTE_ADDRESS).votedActionIdsAtIndex(token, round, i);
            if (IExtensionCenter(EXTENSION_CENTER_ADDRESS).isAccountJoined(token, actionId, account)) {
                return true;
            }
        }

        return false;
    }
}
