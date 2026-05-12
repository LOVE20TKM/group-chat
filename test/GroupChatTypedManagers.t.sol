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
        groupId = _activateToken(manager, token);

        assertEq(manager.tokenOfGroup(groupId), token);
        assertEq(manager.groupIdOfToken(token), groupId);
        assertEq(manager.tokensCount(), 1);
        (address[] memory tokens, uint256[] memory tokenGroupIds) = manager.tokens(0, 10, false);
        assertEq(tokens.length, 1);
        assertEq(tokens[0], token);
        assertEq(tokenGroupIds.length, 1);
        assertEq(tokenGroupIds[0], groupId);
        _assertStartsWith(groupNft.groupNameOf(groupId), "mgr_token_LOVE20_");

        assertTrue(!_canPostAllowed(groupId, senderId, senderOwner));
        protocol.setBalance(senderOwner, 1);
        assertTrue(!_canPostAllowed(groupId, senderId, senderOwner));
        protocol.setBalance(senderOwner, 2);
        assertTrue(_canPostAllowed(groupId, senderId, senderOwner));
        protocol.setBalance(senderOwner, 0);
        protocol.setGovVotes(token, senderOwner, 9);
        assertTrue(_canPostAllowed(groupId, senderId, senderOwner));
        assertEq(manager.denyVoteWeightOf(groupId, senderOwner), 9);
        assertEq(manager.denyVoteTotalWeightOf(groupId), 9);
        protocol.setGovVotes(token, senderOwner, 0);
        protocol.setJoinedAmountByAccount(token, senderOwner, 1);
        assertTrue(_canPostAllowed(groupId, senderId, senderOwner));
        protocol.setJoinedAmountByAccount(token, senderOwner, 0);
        protocol.setCurrentRound(20);
        protocol.setExtensionJoinedAmount(senderOwner, 1);
        protocol.setVotedAction(token, 19, 99, address(protocol));
        assertTrue(!_canPostAllowed(groupId, senderId, senderOwner));
        protocol.setVotedAction(token, 20, 100, other);
        assertTrue(!_canPostAllowed(groupId, senderId, senderOwner));
        protocol.setVotedAction(token, 20, 101, address(protocol));
        protocol.setExtensionJoined(token, 101, senderOwner, true);
        assertTrue(_canPostAllowed(groupId, senderId, senderOwner));

        vm.expectRevert(BaseGroupChatManager.ChatAlreadyManaged.selector);
        manager.activate(token);
    }

    function testT111_tokenGovManagerStoresParamsAndUsesGovVoteWeight() public {
        MockLOVE20Protocols protocol = new MockLOVE20Protocols();
        address token = address(protocol);
        TokenGovGroupChatManager manager =
            new TokenGovGroupChatManager(address(chat), address(0), address(0), address(0), address(protocol));
        groupId = manager.activate(token);

        assertEq(manager.tokenOfGroup(groupId), token);
        assertEq(manager.groupIdOfToken(token), groupId);
        assertEq(manager.tokensCount(), 1);
        (address[] memory tokens, uint256[] memory tokenGroupIds) = manager.tokens(0, 10, false);
        assertEq(tokens.length, 1);
        assertEq(tokens[0], token);
        assertEq(tokenGroupIds.length, 1);
        assertEq(tokenGroupIds[0], groupId);
        _assertStartsWith(groupNft.groupNameOf(groupId), "mgr_token_gov_LOVE20_");

        assertTrue(!_canPostAllowed(groupId, senderId, senderOwner));
        protocol.setGovVotes(token, senderOwner, 7);
        assertTrue(_canPostAllowed(groupId, senderId, senderOwner));
        assertEq(manager.denyVoteWeightOf(groupId, senderOwner), 7);
        assertEq(manager.denyVoteTotalWeightOf(groupId), 7);
    }

    function testT112_tokenActionGovManagerStoresParamsAndUsesRecentVotes() public {
        MockLOVE20Protocols protocol = new MockLOVE20Protocols();
        address token = address(protocol);
        TokenActionGovGroupChatManager manager =
            new TokenActionGovGroupChatManager(address(chat), address(0), address(0), address(0), address(protocol), 3);

        vm.expectRevert(BaseGroupChatManager.RecentRoundsZero.selector);
        new TokenActionGovGroupChatManager(address(chat), address(0), address(0), address(0), address(protocol), 0);

        protocol.setCurrentRound(7);
        groupId = manager.activate(token, 42);
        (address storedToken, uint256 actionId) = manager.actionOfGroup(groupId);
        assertEq(storedToken, token);
        assertEq(actionId, 42);
        assertEq(manager.RECENT_ROUNDS(), 3);
        assertEq(manager.groupIdOfAction(token, 42), groupId);
        assertEq(manager.actionsByTokenCount(token), 1);
        (uint256[] memory actionIds, uint256[] memory actionGroupIds) = manager.actionsByToken(token, 0, 10, false);
        assertEq(actionIds.length, 1);
        assertEq(actionIds[0], 42);
        assertEq(actionGroupIds.length, 1);
        assertEq(actionGroupIds[0], groupId);
        _assertStartsWith(groupNft.groupNameOf(groupId), "mgr_action_gov_LOVE20_42_");

        assertTrue(!_canPostAllowed(groupId, senderId, senderOwner));
        protocol.setActionVotes(token, 5, senderOwner, 42, 1);
        assertTrue(_canPostAllowed(groupId, senderId, senderOwner));
        protocol.setActionVotes(token, 7, senderOwner, 42, 5);
        protocol.setGovVotes(token, senderOwner, 5);
        assertEq(manager.denyVoteWeightOf(groupId, senderOwner), 5);
        assertEq(manager.denyVoteTotalWeightOf(groupId), 5);

        uint256 secondGroupId = manager.activate(token, 43);
        uint256[] memory queryActionIds = new uint256[](3);
        queryActionIds[0] = 43;
        queryActionIds[1] = 44;
        queryActionIds[2] = 42;
        uint256[] memory groupIds = manager.groupIdsOfActions(token, queryActionIds);
        assertEq(groupIds.length, 3);
        assertEq(groupIds[0], secondGroupId);
        assertEq(groupIds[1], 0);
        assertEq(groupIds[2], groupId);
        (address[] memory actionTokens, uint256[] memory actionIdsOfGroups) = manager.actionsOfGroups(groupIds);
        assertEq(actionTokens.length, 3);
        assertEq(actionTokens[0], token);
        assertEq(actionTokens[1], address(0));
        assertEq(actionTokens[2], token);
        assertEq(actionIdsOfGroups.length, 3);
        assertEq(actionIdsOfGroups[0], 43);
        assertEq(actionIdsOfGroups[1], 0);
        assertEq(actionIdsOfGroups[2], 42);

        (actionIds, actionGroupIds) = manager.actionsByToken(token, 0, 1, true);
        assertEq(actionIds.length, 1);
        assertEq(actionIds[0], 43);
        assertEq(actionGroupIds.length, 1);
        assertEq(actionGroupIds[0], secondGroupId);
    }

    function testT113_tokenActionManagerStoresParamsAndAllowsVoteOrParticipation() public {
        MockLOVE20Protocols protocol = new MockLOVE20Protocols();
        address token = address(protocol);
        TokenActionGroupChatManager manager =
            new TokenActionGroupChatManager(address(chat), address(0), address(0), address(0), address(protocol), 3);
        protocol.setCurrentRound(10);
        groupId = manager.activate(token, 88);

        (address storedToken, uint256 actionId) = manager.actionOfGroup(groupId);
        assertEq(storedToken, token);
        assertEq(actionId, 88);
        assertEq(manager.RECENT_ROUNDS(), 3);
        assertEq(manager.groupIdOfAction(token, 88), groupId);
        assertEq(manager.actionsByTokenCount(token), 1);
        (uint256[] memory actionIds, uint256[] memory actionGroupIds) = manager.actionsByToken(token, 0, 10, false);
        assertEq(actionIds.length, 1);
        assertEq(actionIds[0], 88);
        assertEq(actionGroupIds.length, 1);
        assertEq(actionGroupIds[0], groupId);
        _assertStartsWith(groupNft.groupNameOf(groupId), "mgr_action_LOVE20_88_");

        assertTrue(!_canPostAllowed(groupId, senderId, senderOwner));
        protocol.setActionVotes(token, 9, senderOwner, 88, 1);
        assertTrue(_canPostAllowed(groupId, senderId, senderOwner));
        protocol.setActionVotes(token, 9, senderOwner, 88, 0);
        protocol.setJoinedAmount(token, 88, senderOwner, 1);
        assertTrue(_canPostAllowed(groupId, senderId, senderOwner));
        protocol.setJoinedAmount(token, 88, senderOwner, 0);
        protocol.setExtensionJoined(token, 88, senderOwner, true);
        assertTrue(_canPostAllowed(groupId, senderId, senderOwner));
        protocol.setActionVotes(token, 10, senderOwner, 88, 11);
        protocol.setGovVotes(token, senderOwner, 11);
        assertEq(manager.denyVoteWeightOf(groupId, senderOwner), 11);
        assertEq(manager.denyVoteTotalWeightOf(groupId), 11);

        uint256 secondGroupId = manager.activate(token, 89);
        uint256[] memory queryActionIds = new uint256[](3);
        queryActionIds[0] = 89;
        queryActionIds[1] = 90;
        queryActionIds[2] = 88;
        uint256[] memory groupIds = manager.groupIdsOfActions(token, queryActionIds);
        assertEq(groupIds.length, 3);
        assertEq(groupIds[0], secondGroupId);
        assertEq(groupIds[1], 0);
        assertEq(groupIds[2], groupId);
        (address[] memory actionTokens, uint256[] memory actionIdsOfGroups) = manager.actionsOfGroups(groupIds);
        assertEq(actionTokens.length, 3);
        assertEq(actionTokens[0], token);
        assertEq(actionTokens[1], address(0));
        assertEq(actionTokens[2], token);
        assertEq(actionIdsOfGroups.length, 3);
        assertEq(actionIdsOfGroups[0], 89);
        assertEq(actionIdsOfGroups[1], 0);
        assertEq(actionIdsOfGroups[2], 88);

        (actionIds, actionGroupIds) = manager.actionsByToken(token, 0, 1, true);
        assertEq(actionIds.length, 1);
        assertEq(actionIds[0], 89);
        assertEq(actionGroupIds.length, 1);
        assertEq(actionGroupIds[0], secondGroupId);
    }

    function testT116_tokenManagersPageTokens() public {
        MockLOVE20Protocols protocol = new MockLOVE20Protocols();
        MockLOVE20Protocols secondProtocol = new MockLOVE20Protocols();
        address token = address(protocol);
        address secondToken = address(secondProtocol);

        TokenGroupChatManager manager =
            new TokenGroupChatManager(address(chat), address(0), address(0), address(0), address(protocol));
        manager.activate(token);
        uint256 secondGroupId = manager.activate(secondToken);

        assertEq(manager.tokensCount(), 2);
        (address[] memory tokens, uint256[] memory tokenGroupIds) = manager.tokens(0, 10, false);
        assertEq(tokens.length, 2);
        assertEq(tokens[0], token);
        assertEq(tokens[1], secondToken);
        assertEq(tokenGroupIds.length, 2);
        assertEq(tokenGroupIds[0], manager.groupIdOfToken(token));
        assertEq(tokenGroupIds[1], secondGroupId);

        (tokens, tokenGroupIds) = manager.tokens(0, 1, true);
        assertEq(tokens.length, 1);
        assertEq(tokens[0], secondToken);
        assertEq(tokenGroupIds.length, 1);
        assertEq(tokenGroupIds[0], secondGroupId);

        (tokens, tokenGroupIds) = manager.tokens(2, 10, false);
        assertEq(tokens.length, 0);
        assertEq(tokenGroupIds.length, 0);

        TokenGovGroupChatManager govManager =
            new TokenGovGroupChatManager(address(chat), address(0), address(0), address(0), address(protocol));
        govManager.activate(token);
        secondGroupId = govManager.activate(secondToken);

        assertEq(govManager.tokensCount(), 2);
        (tokens, tokenGroupIds) = govManager.tokens(1, 10, false);
        assertEq(tokens.length, 1);
        assertEq(tokens[0], secondToken);
        assertEq(tokenGroupIds.length, 1);
        assertEq(tokenGroupIds[0], secondGroupId);
    }

    function testT114_typedManagerProtocolDependenciesRequireCode() public {
        vm.expectRevert(BaseGroupChatManager.ManagerAddressHasNoCode.selector);
        new TokenGovGroupChatManager(address(chat), address(0), address(0), address(0), other);

        vm.expectRevert(BaseGroupChatManager.ManagerAddressHasNoCode.selector);
        new TokenGroupChatManager(address(chat), address(0), address(0), address(0), other);

        MockLOVE20Protocols protocol = new MockLOVE20Protocols();
        address token = address(protocol);
        protocol.setLOVE20Token(token, false);
        TokenGovGroupChatManager manager =
            new TokenGovGroupChatManager(address(chat), address(0), address(0), address(0), address(protocol));

        vm.expectRevert(BaseGroupChatManager.TokenNotLOVE20.selector);
        manager.activate(token);
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

        groupId = manager.activate(address(protocol));

        assertEq(chat.chatInfo(groupId).owner, address(manager));
        _assertStartsWith(groupNft.groupNameOf(groupId), "Testmgr_token_LOVE20_");
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
