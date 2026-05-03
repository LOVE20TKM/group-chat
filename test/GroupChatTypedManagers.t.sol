// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseGroupChatManager} from "../src/managers/BaseGroupChatManager.sol";
import {TokenGroupChatManager} from "../src/managers/TokenGroupChatManager.sol";
import {TokenGovGroupChatManager} from "../src/managers/TokenGovGroupChatManager.sol";
import {TokenActionGovGroupChatManager} from "../src/managers/TokenActionGovGroupChatManager.sol";
import {TokenActionGroupChatManager} from "../src/managers/TokenActionGroupChatManager.sol";
import {MockLOVE20Protocols} from "./mocks/MockLOVE20Protocols.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";

contract GroupChatTypedManagersTest is GroupChatFixture {
    function testT110_tokenManagerStoresTokenAndCombinesEligibility() public {
        MockLOVE20Protocols protocol = new MockLOVE20Protocols();
        address token = address(protocol);
        TokenGroupChatManager manager =
            new TokenGroupChatManager(address(chat), address(0), address(0), address(0), address(protocol));
        _transferAndActivateToken(manager, token);

        assertEq(manager.tokenOf(chatGroupId), token);

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
        manager.activate(chatGroupId, token);
    }

    function testT111_tokenGovManagerStoresParamsAndUsesGovVoteWeight() public {
        MockLOVE20Protocols protocol = new MockLOVE20Protocols();
        address token = address(protocol);
        TokenGovGroupChatManager manager =
            new TokenGovGroupChatManager(address(chat), address(0), address(0), address(0), address(protocol));
        groupNft.transferFrom(chatOwner, address(manager), chatGroupId);
        manager.activate(chatGroupId, token);

        assertEq(manager.tokenOf(chatGroupId), token);

        assertTrue(!chat.canPost(chatGroupId, senderGroupId, senderOwner));
        protocol.setGovVotes(token, senderOwner, 7);
        assertTrue(chat.canPost(chatGroupId, senderGroupId, senderOwner));
        assertEq(manager.denyVoteWeightOf(chatGroupId, senderOwner, other, senderGroupId), 7);
    }

    function testT112_tokenActionGovManagerStoresParamsAndUsesRecentVotes() public {
        MockLOVE20Protocols protocol = new MockLOVE20Protocols();
        address token = address(protocol);
        TokenActionGovGroupChatManager manager =
            new TokenActionGovGroupChatManager(address(chat), address(0), address(0), address(0), address(protocol));
        groupNft.transferFrom(chatOwner, address(manager), chatGroupId);

        vm.expectRevert(BaseGroupChatManager.RecentRoundsZero.selector);
        manager.activate(chatGroupId, token, 42, 0);

        protocol.setCurrentRound(7);
        manager.activate(chatGroupId, token, 42, 3);
        (address storedToken, uint256 actionId, uint256 recentRounds) = manager.paramsOf(chatGroupId);
        assertEq(storedToken, token);
        assertEq(actionId, 42);
        assertEq(recentRounds, 3);

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
            new TokenActionGroupChatManager(address(chat), address(0), address(0), address(0), address(protocol));
        groupNft.transferFrom(chatOwner, address(manager), chatGroupId);
        protocol.setCurrentRound(10);
        manager.activate(chatGroupId, token, 88, 2);

        (address storedToken, uint256 actionId, uint256 recentRounds) = manager.paramsOf(chatGroupId);
        assertEq(storedToken, token);
        assertEq(actionId, 88);
        assertEq(recentRounds, 2);

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

    function _transferAndActivateToken(TokenGroupChatManager manager, address token) internal {
        groupNft.transferFrom(chatOwner, address(manager), chatGroupId);
        manager.activate(chatGroupId, token);
    }
}
