// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseGroupChatManager} from "./BaseGroupChatManager.sol";
import {IExtensionCenter} from "../interfaces/external/IExtensionCenter.sol";
import {ILOVE20Stake} from "../interfaces/external/ILOVE20Stake.sol";

contract TokenGovGroupChatManager is BaseGroupChatManager {
    address public immutable STAKE_ADDRESS;
    address public immutable EXTENSION_CENTER_ADDRESS;

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
        _requireCode(stake);

        EXTENSION_CENTER_ADDRESS = extensionCenter_;
        STAKE_ADDRESS = stake;
    }

    function activate(address token) external returns (uint256 chatGroupId) {
        _requireCode(token);
        _requireNotManaged(chatGroupIdOfToken[token] != 0);

        chatGroupId = _mintManagedChatGroup(_tokenGroupNameStem("mgr_token_gov_", token));
        tokenOf[chatGroupId] = token;
        chatGroupIdOfToken[token] = chatGroupId;
        _activateManagedChat(chatGroupId);
    }

    function canPost(uint256 chatGroupId, uint256, address senderAddress) external view returns (bool) {
        address token = tokenOf[chatGroupId];
        return token != address(0) && _tokenGovVoteWeight(token, senderAddress) != 0;
    }

    function denyVoteWeightOf(uint256 chatGroupId, address voter, address, uint256) external view returns (uint256) {
        address token = tokenOf[chatGroupId];
        if (token == address(0)) {
            return 0;
        }
        return _tokenGovVoteWeight(token, voter);
    }

    function _tokenGovVoteWeight(address token, address account) internal view returns (uint256) {
        return ILOVE20Stake(STAKE_ADDRESS).validGovVotes(token, account);
    }

}
