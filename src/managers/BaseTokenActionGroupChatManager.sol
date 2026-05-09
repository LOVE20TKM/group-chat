// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IExtensionCenter} from "../interfaces/external/IExtensionCenter.sol";
import {ILOVE20Vote} from "../interfaces/external/ILOVE20Vote.sol";
import {BaseGroupChatManager} from "./BaseGroupChatManager.sol";

abstract contract BaseTokenActionGroupChatManager is BaseGroupChatManager {
    struct ActionChat {
        address token;
        uint256 actionId;
    }

    address public immutable VOTE_ADDRESS;
    address public immutable EXTENSION_CENTER_ADDRESS;
    uint256 public immutable RECENT_ROUNDS;

    mapping(uint256 => ActionChat) public actionOfChatGroup;
    mapping(address => mapping(uint256 => uint256)) public chatGroupIdOfAction;
    mapping(address => uint256[]) internal _actionIdsByToken;

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

        EXTENSION_CENTER_ADDRESS = extensionCenter_;
        VOTE_ADDRESS = vote;
        RECENT_ROUNDS = recentRounds_;
    }

    function actionsCountOf(address token) external view returns (uint256) {
        return _actionIdsByToken[token].length;
    }

    function actionsOf(address token, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (uint256[] memory actionIds, uint256[] memory chatGroupIds)
    {
        uint256[] storage source = _actionIdsByToken[token];
        uint256 count = _pageCount(source.length, offset, limit);
        actionIds = new uint256[](count);
        chatGroupIds = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 actionId = source[_pageIndex(source.length, offset, i, reverse)];
            actionIds[i] = actionId;
            chatGroupIds[i] = chatGroupIdOfAction[token][actionId];
        }
    }

    function chatGroupIdsOfActions(address token, uint256[] calldata actionIds)
        external
        view
        returns (uint256[] memory chatGroupIds)
    {
        chatGroupIds = new uint256[](actionIds.length);
        for (uint256 i = 0; i < actionIds.length; i++) {
            chatGroupIds[i] = chatGroupIdOfAction[token][actionIds[i]];
        }
    }

    function actionsOfChatGroups(uint256[] calldata chatGroupIds)
        external
        view
        returns (address[] memory tokens, uint256[] memory actionIds)
    {
        tokens = new address[](chatGroupIds.length);
        actionIds = new uint256[](chatGroupIds.length);
        for (uint256 i = 0; i < chatGroupIds.length; i++) {
            ActionChat storage action = actionOfChatGroup[chatGroupIds[i]];
            tokens[i] = action.token;
            actionIds[i] = action.actionId;
        }
    }

    function denyVoteWeightOf(uint256 chatGroupId, address voter) external view returns (uint256) {
        ActionChat storage action = actionOfChatGroup[chatGroupId];
        address token = action.token;
        if (token == address(0)) {
            return 0;
        }
        return _currentActionVoteWeight(token, action.actionId, voter);
    }

    function _activateActionChat(address token, uint256 actionId, string memory managerPrefix)
        internal
        returns (uint256 chatGroupId)
    {
        _requireCode(token);
        _requireNotManaged(chatGroupIdOfAction[token][actionId] != 0);

        chatGroupId = _mintManagedChatGroup(_tokenActionGroupNameStem(managerPrefix, token, actionId));
        actionOfChatGroup[chatGroupId] = ActionChat({token: token, actionId: actionId});
        chatGroupIdOfAction[token][actionId] = chatGroupId;
        _actionIdsByToken[token].push(actionId);
        _activateManagedChat(chatGroupId);
    }

    function _hasRecentActionVote(address token, uint256 actionId, address account) internal view returns (bool) {
        uint256 round = ILOVE20Vote(VOTE_ADDRESS).currentRound();
        for (uint256 i = 0; i < RECENT_ROUNDS; i++) {
            if (ILOVE20Vote(VOTE_ADDRESS).votesNumByAccountByActionId(token, round, account, actionId) != 0) {
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
        return ILOVE20Vote(VOTE_ADDRESS).votesNumByAccountByActionId(
            token, ILOVE20Vote(VOTE_ADDRESS).currentRound(), account, actionId
        );
    }
}
