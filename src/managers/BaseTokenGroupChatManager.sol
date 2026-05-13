// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IExtensionCenter} from "../interfaces/external/IExtensionCenter.sol";
import {ILOVE20Launch} from "../interfaces/external/ILOVE20Launch.sol";
import {ILOVE20Stake} from "../interfaces/external/ILOVE20Stake.sol";
import {BaseGroupChatManager} from "./BaseGroupChatManager.sol";

abstract contract BaseTokenGroupChatManager is BaseGroupChatManager {
    address internal immutable LAUNCH_ADDRESS;
    address internal immutable STAKE_ADDRESS;
    address public immutable EXTENSION_CENTER_ADDRESS;

    mapping(uint256 => address) public tokenOfGroup;
    mapping(address => uint256) public groupIdOfToken;
    address[] internal _tokens;

    constructor(
        address groupChat_,
        address denySource_,
        address beforePostPlugin_,
        address afterPostPlugin_,
        address extensionCenter_
    ) BaseGroupChatManager(groupChat_, denySource_, beforePostPlugin_, afterPostPlugin_) {
        _requireCode(extensionCenter_);

        address launch = IExtensionCenter(extensionCenter_).launchAddress();
        address stake = IExtensionCenter(extensionCenter_).stakeAddress();
        _requireCode(launch);
        _requireCode(stake);

        LAUNCH_ADDRESS = launch;
        EXTENSION_CENTER_ADDRESS = extensionCenter_;
        STAKE_ADDRESS = stake;
    }

    function tokensCount() external view returns (uint256) {
        return _tokens.length;
    }

    function tokens(uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (address[] memory tokenList, uint256[] memory groupIds)
    {
        uint256 count = _pageCount(_tokens.length, offset, limit);
        tokenList = new address[](count);
        groupIds = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            address token = _tokens[_pageIndex(_tokens.length, offset, i, reverse)];
            tokenList[i] = token;
            groupIds[i] = groupIdOfToken[token];
        }
    }

    function denyVoteWeightOf(uint256 groupId, address voter) external view returns (uint256) {
        address token = tokenOfGroup[groupId];
        if (token == address(0)) {
            return 0;
        }
        return _tokenGovVoteWeight(token, voter);
    }

    function denyVoteTotalWeightOf(uint256 groupId) external view returns (uint256) {
        address token = tokenOfGroup[groupId];
        if (token == address(0)) {
            return 0;
        }
        return ILOVE20Stake(STAKE_ADDRESS).govVotesNum(token);
    }

    function _activateTokenChat(address token, string memory managerPrefix) internal returns (uint256 groupId) {
        _requireLOVE20Token(token);
        _requireNotManaged(groupIdOfToken[token] != 0);

        groupId = _mintManagedGroup(_tokenGroupNameStem(managerPrefix, token));
        tokenOfGroup[groupId] = token;
        groupIdOfToken[token] = groupId;
        _tokens.push(token);
        _activateManagedChat(groupId);
    }

    function _tokenGovVoteWeight(address token, address account) internal view returns (uint256) {
        return ILOVE20Stake(STAKE_ADDRESS).validGovVotes(token, account);
    }

    function _requireLOVE20Token(address token) internal view {
        _requireCode(token);
        if (!ILOVE20Launch(LAUNCH_ADDRESS).isLOVE20Token(token)) {
            revert TokenNotLOVE20();
        }
    }
}
