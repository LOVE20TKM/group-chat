// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IExtensionCenter} from "../interfaces/external/IExtensionCenter.sol";
import {ILOVE20Launch} from "../interfaces/external/ILOVE20Launch.sol";
import {ILOVE20Stake} from "../interfaces/external/ILOVE20Stake.sol";
import {ILOVE20Vote} from "../interfaces/external/ILOVE20Vote.sol";
import {BaseGroupChatManager} from "./BaseGroupChatManager.sol";

abstract contract BaseTokenActionGroupChatManager is BaseGroupChatManager {
    struct ActionChat {
        address token;
        uint256 actionId;
    }

    address public immutable LAUNCH_ADDRESS;
    address public immutable STAKE_ADDRESS;
    address public immutable VOTE_ADDRESS;
    address public immutable EXTENSION_CENTER_ADDRESS;
    uint256 public immutable RECENT_ROUNDS;

    mapping(uint256 => ActionChat) public actionOfGroup;
    mapping(address => mapping(uint256 => uint256)) public groupIdOfAction;
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

        address launch = IExtensionCenter(extensionCenter_).launchAddress();
        address stake = IExtensionCenter(extensionCenter_).stakeAddress();
        address vote = IExtensionCenter(extensionCenter_).voteAddress();
        _requireCode(launch);
        _requireCode(stake);
        _requireCode(vote);

        LAUNCH_ADDRESS = launch;
        STAKE_ADDRESS = stake;
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
        returns (uint256[] memory actionIds, uint256[] memory groupIds)
    {
        uint256[] storage source = _actionIdsByToken[token];
        uint256 count = _pageCount(source.length, offset, limit);
        actionIds = new uint256[](count);
        groupIds = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 actionId = source[_pageIndex(source.length, offset, i, reverse)];
            actionIds[i] = actionId;
            groupIds[i] = groupIdOfAction[token][actionId];
        }
    }

    function groupIdsOfActions(address token, uint256[] calldata actionIds)
        external
        view
        returns (uint256[] memory groupIds)
    {
        groupIds = new uint256[](actionIds.length);
        for (uint256 i = 0; i < actionIds.length; i++) {
            groupIds[i] = groupIdOfAction[token][actionIds[i]];
        }
    }

    function actionsOfGroups(uint256[] calldata groupIds)
        external
        view
        returns (address[] memory tokens, uint256[] memory actionIds)
    {
        tokens = new address[](groupIds.length);
        actionIds = new uint256[](groupIds.length);
        for (uint256 i = 0; i < groupIds.length; i++) {
            ActionChat storage action = actionOfGroup[groupIds[i]];
            tokens[i] = action.token;
            actionIds[i] = action.actionId;
        }
    }

    function denyVoteWeightOf(uint256 groupId, address voter) external view returns (uint256) {
        ActionChat storage action = actionOfGroup[groupId];
        address token = action.token;
        if (token == address(0)) {
            return 0;
        }
        return _currentActionVoteWeight(token, action.actionId, voter);
    }

    function denyVoteTotalWeightOf(uint256 groupId) external view returns (uint256) {
        ActionChat storage action = actionOfGroup[groupId];
        address token = action.token;
        if (token == address(0)) {
            return 0;
        }
        return ILOVE20Stake(STAKE_ADDRESS).govVotesNum(token);
    }

    function _activateActionChat(address token, uint256 actionId, string memory managerPrefix)
        internal
        returns (uint256 groupId)
    {
        _requireLOVE20Token(token);
        _requireNotManaged(groupIdOfAction[token][actionId] != 0);

        groupId = _mintManagedGroup(_tokenActionGroupNameStem(managerPrefix, token, actionId));
        actionOfGroup[groupId] = ActionChat({token: token, actionId: actionId});
        groupIdOfAction[token][actionId] = groupId;
        _actionIdsByToken[token].push(actionId);
        _activateManagedChat(groupId);
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

    function _requireLOVE20Token(address token) internal view {
        _requireCode(token);
        if (!ILOVE20Launch(LAUNCH_ADDRESS).isLOVE20Token(token)) {
            revert TokenNotLOVE20();
        }
    }
}
