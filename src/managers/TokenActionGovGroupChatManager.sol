// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseGroupChatManager} from "./BaseGroupChatManager.sol";
import {IExtensionCenter} from "../interfaces/IExtensionCenter.sol";
import {ILOVE20Vote} from "../interfaces/ILOVE20Vote.sol";

contract TokenActionGovGroupChatManager is BaseGroupChatManager {
    struct TokenActionGovChatParams {
        address token;
        uint256 actionId;
        uint256 recentRounds;
    }

    address public immutable VOTE;
    address public immutable EXTENSION_CENTER;

    mapping(uint256 => TokenActionGovChatParams) public paramsOf;

    constructor(
        address groupChat_,
        address denySource_,
        address beforePostPlugin_,
        address afterPostPlugin_,
        address extensionCenter_
    ) BaseGroupChatManager(groupChat_, denySource_, beforePostPlugin_, afterPostPlugin_) {
        _requireCode(extensionCenter_);

        address vote = IExtensionCenter(extensionCenter_).voteAddress();
        _requireCode(vote);

        EXTENSION_CENTER = extensionCenter_;
        VOTE = vote;
    }

    function activate(uint256 chatGroupId, address token, uint256 actionId, uint256 recentRounds) external {
        _requireCode(token);
        _requireRecentRounds(recentRounds);
        TokenActionGovChatParams storage params = paramsOf[chatGroupId];
        _requireNotManaged(params.token != address(0));

        params.token = token;
        params.actionId = actionId;
        params.recentRounds = recentRounds;
        _activateManagedChat(chatGroupId);
    }

    function canPost(uint256 chatGroupId, uint256, address senderAddress) external view returns (bool) {
        TokenActionGovChatParams storage params = paramsOf[chatGroupId];
        address token = params.token;
        return token != address(0) && _hasRecentActionVote(token, params.actionId, params.recentRounds, senderAddress);
    }

    function denyVoteWeightOf(uint256 chatGroupId, address voter, address, uint256) external view returns (uint256) {
        TokenActionGovChatParams storage params = paramsOf[chatGroupId];
        address token = params.token;
        if (token == address(0)) {
            return 0;
        }
        return _currentActionVoteWeight(token, params.actionId, voter);
    }

    function _hasRecentActionVote(address token, uint256 actionId, uint256 recentRounds, address account)
        internal
        view
        returns (bool)
    {
        uint256 round = ILOVE20Vote(VOTE).currentRound();
        for (uint256 i = 0; i < recentRounds; i++) {
            if (ILOVE20Vote(VOTE).votesNumByAccountByActionId(token, round, account, actionId) != 0) {
                return true;
            }
            if (round == 0) {
                break;
            }
            unchecked {
                round--;
            }
        }
        return false;
    }

    function _currentActionVoteWeight(address token, uint256 actionId, address account)
        internal
        view
        returns (uint256)
    {
        return ILOVE20Vote(VOTE).votesNumByAccountByActionId(token, ILOVE20Vote(VOTE).currentRound(), account, actionId);
    }
}
