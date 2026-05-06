// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseGroupChatManager} from "./BaseGroupChatManager.sol";
import {IExtensionCenter} from "../interfaces/external/IExtensionCenter.sol";
import {ILOVE20Vote} from "../interfaces/external/ILOVE20Vote.sol";

contract TokenActionGovGroupChatManager is BaseGroupChatManager {
    struct TokenActionGovChatParams {
        address token;
        uint256 actionId;
    }

    address public immutable VOTE;
    address public immutable EXTENSION_CENTER;
    uint256 public immutable RECENT_ROUNDS;

    mapping(uint256 => TokenActionGovChatParams) public paramsOf;
    mapping(address => mapping(uint256 => uint256)) public chatGroupIdOfAction;

    constructor(
        address groupChat_,
        address denySource_,
        address beforePostPlugin_,
        address afterPostPlugin_,
        address extensionCenter_,
        uint256 recentRounds_
    ) BaseGroupChatManager(groupChat_, denySource_, beforePostPlugin_, afterPostPlugin_) {
        _requireCode(extensionCenter_);
        _requireRecentRounds(recentRounds_);

        address vote = IExtensionCenter(extensionCenter_).voteAddress();
        _requireCode(vote);

        EXTENSION_CENTER = extensionCenter_;
        VOTE = vote;
        RECENT_ROUNDS = recentRounds_;
    }

    function activate(address token, uint256 actionId) external returns (uint256 chatGroupId) {
        _requireCode(token);
        _requireNotManaged(chatGroupIdOfAction[token][actionId] != 0);

        chatGroupId = _mintManagedChatGroup(_tokenActionGroupNameStem("mgr_action_gov_", token, actionId));
        TokenActionGovChatParams storage params = paramsOf[chatGroupId];
        params.token = token;
        params.actionId = actionId;
        chatGroupIdOfAction[token][actionId] = chatGroupId;
        _activateManagedChat(chatGroupId);
    }

    function canPost(uint256 chatGroupId, uint256, address senderAddress) external view returns (bool) {
        TokenActionGovChatParams storage params = paramsOf[chatGroupId];
        address token = params.token;
        return token != address(0) && _hasRecentActionVote(token, params.actionId, senderAddress);
    }

    function denyVoteWeightOf(uint256 chatGroupId, address voter, address, uint256) external view returns (uint256) {
        TokenActionGovChatParams storage params = paramsOf[chatGroupId];
        address token = params.token;
        if (token == address(0)) {
            return 0;
        }
        return _currentActionVoteWeight(token, params.actionId, voter);
    }

    function _hasRecentActionVote(address token, uint256 actionId, address account) internal view returns (bool) {
        uint256 round = ILOVE20Vote(VOTE).currentRound();
        for (uint256 i = 0; i < RECENT_ROUNDS; i++) {
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
