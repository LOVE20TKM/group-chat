// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseGroupChatManager} from "../src/managers/BaseGroupChatManager.sol";

import {TokenActionGovGroupChatManager} from "../src/managers/TokenActionGovGroupChatManager.sol";
import {TokenActionGroupChatManager} from "../src/managers/TokenActionGroupChatManager.sol";
import {TokenGovGroupChatManager} from "../src/managers/TokenGovGroupChatManager.sol";
import {TokenGroupChatManager} from "../src/managers/TokenGroupChatManager.sol";

import {MockERC20Payment} from "./mocks/MockLOVE20Group.sol";
import {MockLOVE20Protocols} from "./mocks/MockLOVE20Protocols.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";

contract GroupChatTypedManagersTest is GroupChatFixture {
    function testT110_tokenManagerStoresTokenAndCombinesEligibility() public {
        MockLOVE20Protocols protocol = new MockLOVE20Protocols();
        address token = address(protocol);
        TokenGroupChatManager manager =
            new TokenGroupChatManager(address(chat), address(0), address(0), address(0), address(protocol));
        chatGroupId = _activateToken(manager, token);

        assertEq(manager.tokenOf(chatGroupId), token);
        assertEq(manager.chatGroupIdOfToken(token), chatGroupId);
        assertEq(manager.activatedTokensCount(), 1);
        (address[] memory tokens, uint256[] memory tokenChatGroupIds) = manager.activatedTokens(0, 10, false);
        assertEq(tokens.length, 1);
        assertEq(tokens[0], token);
        assertEq(tokenChatGroupIds.length, 1);
        assertEq(tokenChatGroupIds[0], chatGroupId);
        _assertStartsWith(groupNft.groupNameOf(chatGroupId), "mgr_token_LOVE20_");

        assertTrue(!_canPostAllowed(chatGroupId, senderId, senderOwner));
        protocol.setBalance(senderOwner, 1);
        assertTrue(!_canPostAllowed(chatGroupId, senderId, senderOwner));
        protocol.setBalance(senderOwner, 2);
        assertTrue(_canPostAllowed(chatGroupId, senderId, senderOwner));
        protocol.setBalance(senderOwner, 0);
        protocol.setGovVotes(token, senderOwner, 9);
        assertTrue(_canPostAllowed(chatGroupId, senderId, senderOwner));
        assertEq(manager.denyVoteWeightOf(chatGroupId, senderOwner), 9);
        protocol.setGovVotes(token, senderOwner, 0);
        protocol.setJoinedAmountByAccount(token, senderOwner, 1);
        assertTrue(_canPostAllowed(chatGroupId, senderId, senderOwner));
        protocol.setJoinedAmountByAccount(token, senderOwner, 0);
        protocol.setCurrentRound(20);
        protocol.setExtensionJoinedAmount(senderOwner, 1);
        protocol.setVotedAction(token, 19, 99, address(protocol));
        assertTrue(!_canPostAllowed(chatGroupId, senderId, senderOwner));
        protocol.setVotedAction(token, 20, 100, other);
        assertTrue(!_canPostAllowed(chatGroupId, senderId, senderOwner));
        protocol.setVotedAction(token, 20, 101, address(protocol));
        protocol.setExtensionJoined(token, 101, senderOwner, true);
        assertTrue(_canPostAllowed(chatGroupId, senderId, senderOwner));

        vm.expectRevert(BaseGroupChatManager.ChatAlreadyManaged.selector);
        manager.activate(token);
    }

    function testT111_tokenGovManagerStoresParamsAndUsesGovVoteWeight() public {
        MockLOVE20Protocols protocol = new MockLOVE20Protocols();
        address token = address(protocol);
        TokenGovGroupChatManager manager =
            new TokenGovGroupChatManager(address(chat), address(0), address(0), address(0), address(protocol));
        chatGroupId = manager.activate(token);

        assertEq(manager.tokenOf(chatGroupId), token);
        assertEq(manager.chatGroupIdOfToken(token), chatGroupId);
        assertEq(manager.activatedTokensCount(), 1);
        (address[] memory tokens, uint256[] memory tokenChatGroupIds) = manager.activatedTokens(0, 10, false);
        assertEq(tokens.length, 1);
        assertEq(tokens[0], token);
        assertEq(tokenChatGroupIds.length, 1);
        assertEq(tokenChatGroupIds[0], chatGroupId);
        _assertStartsWith(groupNft.groupNameOf(chatGroupId), "mgr_token_gov_LOVE20_");

        assertTrue(!_canPostAllowed(chatGroupId, senderId, senderOwner));
        protocol.setGovVotes(token, senderOwner, 7);
        assertTrue(_canPostAllowed(chatGroupId, senderId, senderOwner));
        assertEq(manager.denyVoteWeightOf(chatGroupId, senderOwner), 7);
    }

    function testT112_tokenActionGovManagerStoresParamsAndUsesRecentVotes() public {
        MockLOVE20Protocols protocol = new MockLOVE20Protocols();
        address token = address(protocol);
        TokenActionGovGroupChatManager manager =
            new TokenActionGovGroupChatManager(address(chat), address(0), address(0), address(0), address(protocol), 3);

        vm.expectRevert(BaseGroupChatManager.RecentRoundsZero.selector);
        new TokenActionGovGroupChatManager(address(chat), address(0), address(0), address(0), address(protocol), 0);

        protocol.setCurrentRound(7);
        chatGroupId = manager.activate(token, 42);
        (address storedToken, uint256 actionId) = manager.paramsOf(chatGroupId);
        assertEq(storedToken, token);
        assertEq(actionId, 42);
        assertEq(manager.RECENT_ROUNDS(), 3);
        assertEq(manager.chatGroupIdOfAction(token, 42), chatGroupId);
        assertEq(manager.activatedActionsCount(token), 1);
        (uint256[] memory actionIds, uint256[] memory actionChatGroupIds) =
            manager.activatedActions(token, 0, 10, false);
        assertEq(actionIds.length, 1);
        assertEq(actionIds[0], 42);
        assertEq(actionChatGroupIds.length, 1);
        assertEq(actionChatGroupIds[0], chatGroupId);
        _assertStartsWith(groupNft.groupNameOf(chatGroupId), "mgr_action_gov_LOVE20_42_");

        assertTrue(!_canPostAllowed(chatGroupId, senderId, senderOwner));
        protocol.setActionVotes(token, 5, senderOwner, 42, 1);
        assertTrue(_canPostAllowed(chatGroupId, senderId, senderOwner));
        protocol.setActionVotes(token, 7, senderOwner, 42, 5);
        assertEq(manager.denyVoteWeightOf(chatGroupId, senderOwner), 5);

        uint256 secondChatGroupId = manager.activate(token, 43);
        uint256[] memory queryActionIds = new uint256[](3);
        queryActionIds[0] = 43;
        queryActionIds[1] = 44;
        queryActionIds[2] = 42;
        uint256[] memory chatGroupIds = manager.chatGroupIdsOfActions(token, queryActionIds);
        assertEq(chatGroupIds.length, 3);
        assertEq(chatGroupIds[0], secondChatGroupId);
        assertEq(chatGroupIds[1], 0);
        assertEq(chatGroupIds[2], chatGroupId);

        (actionIds, actionChatGroupIds) = manager.activatedActions(token, 0, 1, true);
        assertEq(actionIds.length, 1);
        assertEq(actionIds[0], 43);
        assertEq(actionChatGroupIds.length, 1);
        assertEq(actionChatGroupIds[0], secondChatGroupId);
    }

    function testT113_tokenActionManagerStoresParamsAndAllowsVoteOrParticipation() public {
        MockLOVE20Protocols protocol = new MockLOVE20Protocols();
        address token = address(protocol);
        TokenActionGroupChatManager manager =
            new TokenActionGroupChatManager(address(chat), address(0), address(0), address(0), address(protocol), 3);
        protocol.setCurrentRound(10);
        chatGroupId = manager.activate(token, 88);

        (address storedToken, uint256 actionId) = manager.paramsOf(chatGroupId);
        assertEq(storedToken, token);
        assertEq(actionId, 88);
        assertEq(manager.RECENT_ROUNDS(), 3);
        assertEq(manager.chatGroupIdOfAction(token, 88), chatGroupId);
        assertEq(manager.activatedActionsCount(token), 1);
        (uint256[] memory actionIds, uint256[] memory actionChatGroupIds) =
            manager.activatedActions(token, 0, 10, false);
        assertEq(actionIds.length, 1);
        assertEq(actionIds[0], 88);
        assertEq(actionChatGroupIds.length, 1);
        assertEq(actionChatGroupIds[0], chatGroupId);
        _assertStartsWith(groupNft.groupNameOf(chatGroupId), "mgr_action_LOVE20_88_");

        assertTrue(!_canPostAllowed(chatGroupId, senderId, senderOwner));
        protocol.setActionVotes(token, 9, senderOwner, 88, 1);
        assertTrue(_canPostAllowed(chatGroupId, senderId, senderOwner));
        protocol.setActionVotes(token, 9, senderOwner, 88, 0);
        protocol.setJoinedAmount(token, 88, senderOwner, 1);
        assertTrue(_canPostAllowed(chatGroupId, senderId, senderOwner));
        protocol.setJoinedAmount(token, 88, senderOwner, 0);
        protocol.setExtensionJoined(token, 88, senderOwner, true);
        assertTrue(_canPostAllowed(chatGroupId, senderId, senderOwner));
        protocol.setActionVotes(token, 10, senderOwner, 88, 11);
        assertEq(manager.denyVoteWeightOf(chatGroupId, senderOwner), 11);

        uint256 secondChatGroupId = manager.activate(token, 89);
        uint256[] memory queryActionIds = new uint256[](3);
        queryActionIds[0] = 89;
        queryActionIds[1] = 90;
        queryActionIds[2] = 88;
        uint256[] memory chatGroupIds = manager.chatGroupIdsOfActions(token, queryActionIds);
        assertEq(chatGroupIds.length, 3);
        assertEq(chatGroupIds[0], secondChatGroupId);
        assertEq(chatGroupIds[1], 0);
        assertEq(chatGroupIds[2], chatGroupId);

        (actionIds, actionChatGroupIds) = manager.activatedActions(token, 0, 1, true);
        assertEq(actionIds.length, 1);
        assertEq(actionIds[0], 89);
        assertEq(actionChatGroupIds.length, 1);
        assertEq(actionChatGroupIds[0], secondChatGroupId);
    }

    function testT116_tokenManagersPageActivatedTokens() public {
        MockLOVE20Protocols protocol = new MockLOVE20Protocols();
        MockLOVE20Protocols secondProtocol = new MockLOVE20Protocols();
        address token = address(protocol);
        address secondToken = address(secondProtocol);

        TokenGroupChatManager manager =
            new TokenGroupChatManager(address(chat), address(0), address(0), address(0), address(protocol));
        manager.activate(token);
        uint256 secondChatGroupId = manager.activate(secondToken);

        assertEq(manager.activatedTokensCount(), 2);
        (address[] memory tokens, uint256[] memory tokenChatGroupIds) = manager.activatedTokens(0, 10, false);
        assertEq(tokens.length, 2);
        assertEq(tokens[0], token);
        assertEq(tokens[1], secondToken);
        assertEq(tokenChatGroupIds.length, 2);
        assertEq(tokenChatGroupIds[0], manager.chatGroupIdOfToken(token));
        assertEq(tokenChatGroupIds[1], secondChatGroupId);

        (tokens, tokenChatGroupIds) = manager.activatedTokens(0, 1, true);
        assertEq(tokens.length, 1);
        assertEq(tokens[0], secondToken);
        assertEq(tokenChatGroupIds.length, 1);
        assertEq(tokenChatGroupIds[0], secondChatGroupId);

        (tokens, tokenChatGroupIds) = manager.activatedTokens(2, 10, false);
        assertEq(tokens.length, 0);
        assertEq(tokenChatGroupIds.length, 0);

        TokenGovGroupChatManager govManager =
            new TokenGovGroupChatManager(address(chat), address(0), address(0), address(0), address(protocol));
        govManager.activate(token);
        secondChatGroupId = govManager.activate(secondToken);

        assertEq(govManager.activatedTokensCount(), 2);
        (tokens, tokenChatGroupIds) = govManager.activatedTokens(1, 10, false);
        assertEq(tokens.length, 1);
        assertEq(tokens[0], secondToken);
        assertEq(tokenChatGroupIds.length, 1);
        assertEq(tokenChatGroupIds[0], secondChatGroupId);
    }

    function testT114_typedManagerProtocolDependenciesRequireCode() public {
        vm.expectRevert(BaseGroupChatManager.ManagerAddressHasNoCode.selector);
        new TokenGovGroupChatManager(address(chat), address(0), address(0), address(0), other);

        vm.expectRevert(BaseGroupChatManager.ManagerAddressHasNoCode.selector);
        new TokenGroupChatManager(address(chat), address(0), address(0), address(0), other);
    }

    function testT115_tokenManagerMintSurvivesTestPrefixNormalization() public {
        MockLOVE20Protocols protocol = new MockLOVE20Protocols();
        MockERC20Payment payment = new MockERC20Payment();
        payment.setSymbol("TestLOVE");
        groupNft.setMintPayment(address(payment), 10);
        payment.mint(address(this), 10);

        TokenGroupChatManager manager =
            new TokenGroupChatManager(address(chat), address(0), address(0), address(0), address(protocol));
        payment.approve(address(manager), 10);

        chatGroupId = manager.activate(address(protocol));

        assertEq(chat.chatInfo(chatGroupId).owner, address(manager));
        _assertStartsWith(groupNft.groupNameOf(chatGroupId), "Testmgr_token_LOVE20_");
    }

    function _activateToken(TokenGroupChatManager manager, address token) internal returns (uint256) {
        return manager.activate(token);
    }

    function _assertStartsWith(string memory value, string memory prefix) internal pure {
        bytes memory valueBytes = bytes(value);
        bytes memory prefixBytes = bytes(prefix);
        assertTrue(valueBytes.length >= prefixBytes.length);
        for (uint256 i = 0; i < prefixBytes.length; i++) {
            assertEq(valueBytes[i], prefixBytes[i]);
        }
    }
}
