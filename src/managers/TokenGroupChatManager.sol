// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseGroupChatManager} from "./BaseGroupChatManager.sol";
import {IERC20Balance} from "../interfaces/external/IERC20Balance.sol";
import {IExtension} from "../interfaces/external/IExtension.sol";
import {IExtensionCenter} from "../interfaces/external/IExtensionCenter.sol";
import {ILOVE20Join} from "../interfaces/external/ILOVE20Join.sol";
import {ILOVE20Stake} from "../interfaces/external/ILOVE20Stake.sol";
import {ActionInfo, ILOVE20Submit} from "../interfaces/external/ILOVE20Submit.sol";
import {ILOVE20Vote} from "../interfaces/external/ILOVE20Vote.sol";

contract TokenGroupChatManager is BaseGroupChatManager {
    address public immutable STAKE;
    address public immutable JOIN;
    address public immutable VOTE;
    address public immutable SUBMIT;
    address public immutable EXTENSION_CENTER;

    mapping(uint256 => address) public tokenOf;
    mapping(address => uint256) public chatGroupIdOfToken;

    constructor(
        address groupChat_,
        address denySource_,
        address beforePostPlugin_,
        address afterPostPlugin_,
        address extensionCenter_
    ) BaseGroupChatManager(groupChat_, denySource_, beforePostPlugin_, afterPostPlugin_) {
        _requireCode(extensionCenter_);

        address stake = IExtensionCenter(extensionCenter_).stakeAddress();
        address join = IExtensionCenter(extensionCenter_).joinAddress();
        address vote = IExtensionCenter(extensionCenter_).voteAddress();
        address submit = IExtensionCenter(extensionCenter_).submitAddress();
        _requireCode(stake);
        _requireCode(join);
        _requireCode(vote);
        _requireCode(submit);

        EXTENSION_CENTER = extensionCenter_;
        STAKE = stake;
        JOIN = join;
        VOTE = vote;
        SUBMIT = submit;
    }

    function activate(address token) external returns (uint256 chatGroupId) {
        _requireCode(token);
        _requireNotManaged(chatGroupIdOfToken[token] != 0);

        chatGroupId = _mintManagedChatGroup(_tokenGroupNameStem("mgr_token_", token));
        tokenOf[chatGroupId] = token;
        chatGroupIdOfToken[token] = chatGroupId;
        _activateManagedChat(chatGroupId);
    }

    function canPost(uint256 chatGroupId, uint256, address senderAddress) external view returns (bool) {
        address token = tokenOf[chatGroupId];
        return token != address(0)
            && (
                _hasTokenBalance(token, senderAddress) || _tokenGovVoteWeight(token, senderAddress) != 0
                    || _hasTokenActionParticipation(token, senderAddress)
            );
    }

    function denyVoteWeightOf(uint256 chatGroupId, address voter, address, uint256) external view returns (uint256) {
        address token = tokenOf[chatGroupId];
        if (token == address(0)) {
            return 0;
        }
        return _tokenGovVoteWeight(token, voter);
    }

    function _hasTokenBalance(address token, address account) internal view returns (bool) {
        return IERC20Balance(token).balanceOf(account) > 1;
    }

    function _hasTokenActionParticipation(address token, address account) internal view returns (bool) {
        return ILOVE20Join(JOIN).amountByAccount(token, account) != 0
            || _hasCurrentRoundExtensionActionParticipation(token, account);
    }

    function _hasCurrentRoundExtensionActionParticipation(address token, address account)
        internal
        view
        returns (bool)
    {
        uint256 round = ILOVE20Join(JOIN).currentRound();
        uint256 count = ILOVE20Vote(VOTE).votedActionIdsCount(token, round);

        for (uint256 i = 0; i < count; i++) {
            uint256 actionId = ILOVE20Vote(VOTE).votedActionIdsAtIndex(token, round, i);
            ActionInfo memory info = ILOVE20Submit(SUBMIT).actionInfo(token, actionId);
            address extension = info.body.whiteListAddress;
            if (extension.code.length == 0) {
                continue;
            }

            try IExtension(extension).joinedAmountByAccount(account) returns (uint256 amount) {
                if (amount != 0) {
                    return true;
                }
            } catch {}
        }

        return false;
    }

    function _tokenGovVoteWeight(address token, address account) internal view returns (uint256) {
        return ILOVE20Stake(STAKE).validGovVotes(token, account);
    }

}
