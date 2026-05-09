// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IExtensionCenter} from "../interfaces/external/IExtensionCenter.sol";
import {ILOVE20Stake} from "../interfaces/external/ILOVE20Stake.sol";
import {BaseGroupChatManager} from "./BaseGroupChatManager.sol";

abstract contract BaseTokenGroupChatManager is BaseGroupChatManager {
    address public immutable STAKE_ADDRESS;
    address public immutable EXTENSION_CENTER_ADDRESS;

    mapping(uint256 => address) public tokenOf;
    mapping(address => uint256) public chatGroupIdOfToken;
    address[] internal _activatedTokens;

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

    function activatedTokensCount() external view returns (uint256) {
        return _activatedTokens.length;
    }

    function activatedTokens(uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (address[] memory tokens, uint256[] memory chatGroupIds)
    {
        uint256 count = _pageCount(_activatedTokens.length, offset, limit);
        tokens = new address[](count);
        chatGroupIds = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            address token = _activatedTokens[_pageIndex(_activatedTokens.length, offset, i, reverse)];
            tokens[i] = token;
            chatGroupIds[i] = chatGroupIdOfToken[token];
        }
    }

    function denyVoteWeightOf(uint256 chatGroupId, address voter) external view returns (uint256) {
        address token = tokenOf[chatGroupId];
        if (token == address(0)) {
            return 0;
        }
        return _tokenGovVoteWeight(token, voter);
    }

    function _activateTokenChat(address token, string memory managerPrefix) internal returns (uint256 chatGroupId) {
        _requireCode(token);
        _requireNotManaged(chatGroupIdOfToken[token] != 0);

        chatGroupId = _mintManagedChatGroup(_tokenGroupNameStem(managerPrefix, token));
        tokenOf[chatGroupId] = token;
        chatGroupIdOfToken[token] = chatGroupId;
        _activatedTokens.push(token);
        _activateManagedChat(chatGroupId);
    }

    function _tokenGovVoteWeight(address token, address account) internal view returns (uint256) {
        return ILOVE20Stake(STAKE_ADDRESS).validGovVotes(token, account);
    }
}
