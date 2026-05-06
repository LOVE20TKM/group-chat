// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseGroupChatManager} from "../src/managers/BaseGroupChatManager.sol";
import {TokenGroupChatManager} from "../src/managers/TokenGroupChatManager.sol";
import {TokenGovGroupChatManager} from "../src/managers/TokenGovGroupChatManager.sol";
import {TokenActionGovGroupChatManager} from "../src/managers/TokenActionGovGroupChatManager.sol";
import {TokenActionGroupChatManager} from "../src/managers/TokenActionGroupChatManager.sol";
import {MockLOVE20Protocols} from "./mocks/MockLOVE20Protocols.sol";
import {MockERC20Payment} from "./mocks/MockLOVE20Group.sol";
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
        _assertStartsWith(groupNft.groupNameOf(chatGroupId), "mgr_token_LOVE20_");

        assertTrue(!chat.canPost(chatGroupId, senderGroupId, senderOwner));
        protocol.setBalance(senderOwner, 1);
        assertTrue(!chat.canPost(chatGroupId, senderGroupId, senderOwner));
        protocol.setBalance(senderOwner, 2);
        assertTrue(chat.canPost(chatGroupId, senderGroupId, senderOwner));
        protocol.setBalance(senderOwner, 0);
        protocol.setGovVotes(token, senderOwner, 9);
        assertTrue(chat.canPost(chatGroupId, senderGroupId, senderOwner));
        assertEq(manager.denyVoteWeightOf(chatGroupId, senderOwner, other, senderGroupId), 9);
        protocol.setGovVotes(token, senderOwner, 0);
        protocol.setJoinedAmountByAccount(token, senderOwner, 1);
        assertTrue(chat.canPost(chatGroupId, senderGroupId, senderOwner));
        protocol.setJoinedAmountByAccount(token, senderOwner, 0);
        protocol.setCurrentRound(20);
        protocol.setExtensionJoinedAmount(senderOwner, 1);
        protocol.setVotedAction(token, 19, 99, address(protocol));
        assertTrue(!chat.canPost(chatGroupId, senderGroupId, senderOwner));
        protocol.setVotedAction(token, 20, 100, other);
        assertTrue(!chat.canPost(chatGroupId, senderGroupId, senderOwner));
        protocol.setVotedAction(token, 20, 101, address(protocol));
        assertTrue(chat.canPost(chatGroupId, senderGroupId, senderOwner));

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
        _assertStartsWith(groupNft.groupNameOf(chatGroupId), "mgr_token_gov_LOVE20_");

        assertTrue(!chat.canPost(chatGroupId, senderGroupId, senderOwner));
        protocol.setGovVotes(token, senderOwner, 7);
        assertTrue(chat.canPost(chatGroupId, senderGroupId, senderOwner));
        assertEq(manager.denyVoteWeightOf(chatGroupId, senderOwner, other, senderGroupId), 7);
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
        _assertStartsWith(groupNft.groupNameOf(chatGroupId), "mgr_action_gov_LOVE20_42_");

        assertTrue(!chat.canPost(chatGroupId, senderGroupId, senderOwner));
        protocol.setActionVotes(token, 5, senderOwner, 42, 1);
        assertTrue(chat.canPost(chatGroupId, senderGroupId, senderOwner));
        protocol.setActionVotes(token, 7, senderOwner, 42, 5);
        assertEq(manager.denyVoteWeightOf(chatGroupId, senderOwner, other, senderGroupId), 5);
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
        _assertStartsWith(groupNft.groupNameOf(chatGroupId), "mgr_action_LOVE20_88_");

        assertTrue(!chat.canPost(chatGroupId, senderGroupId, senderOwner));
        protocol.setActionVotes(token, 9, senderOwner, 88, 1);
        assertTrue(chat.canPost(chatGroupId, senderGroupId, senderOwner));
        protocol.setActionVotes(token, 9, senderOwner, 88, 0);
        protocol.setJoinedAmount(token, 88, senderOwner, 1);
        assertTrue(chat.canPost(chatGroupId, senderGroupId, senderOwner));
        protocol.setJoinedAmount(token, 88, senderOwner, 0);
        protocol.setExtensionJoined(token, 88, senderOwner, true);
        assertTrue(chat.canPost(chatGroupId, senderGroupId, senderOwner));
        protocol.setActionVotes(token, 10, senderOwner, 88, 11);
        assertEq(manager.denyVoteWeightOf(chatGroupId, senderOwner, other, senderGroupId), 11);
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
