// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseGroupChatManager} from "./BaseGroupChatManager.sol";
import {IExtensionCenter} from "../interfaces/external/IExtensionCenter.sol";
import {ILOVE20Stake} from "../interfaces/external/ILOVE20Stake.sol";

contract TokenGovGroupChatManager is BaseGroupChatManager {
    address public immutable STAKE;
    address public immutable EXTENSION_CENTER;

    mapping(uint256 => address) public tokenOf;

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

        EXTENSION_CENTER = extensionCenter_;
        STAKE = stake;
    }

    function activate(uint256 chatGroupId, address token) external {
        _requireCode(token);
        _requireNotManaged(tokenOf[chatGroupId] != address(0));

        tokenOf[chatGroupId] = token;
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
        return ILOVE20Stake(STAKE).validGovVotes(token, account);
    }
}
