// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {GroupChat} from "../src/GroupChat.sol";
import {IGroupChat, IGroupChatErrors} from "../src/interfaces/IGroupChat.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";
import {Vm} from "./utils/TestBase.sol";

contract GroupChatLifecycleTest is GroupChatFixture {
    function testT001_constructorStoresConfigAndRoundNotStarted() public {
        assertEq(chat.GROUP_ADDRESS(), address(groupNft));
        assertEq(chat.GROUP_DEFAULTS_ADDRESS(), address(groupDefaults));
        assertEq(chat.originBlocks(), originBlocks);
        assertEq(chat.phaseBlocks(), phaseBlocks);

        vm.expectRevert(IGroupChatErrors.RoundNotStarted.selector);
        chat.currentRound();
    }

    function testT002_constructorRejectsRegistryWithoutCode() public {
        vm.expectRevert(IGroupChatErrors.GroupDefaultsHasNoCode.selector);
        new GroupChat(other, originBlocks, phaseBlocks);
    }

    function testT003_constructorRejectsZeroPhaseBlocks() public {
        vm.expectRevert(IGroupChatErrors.PhaseBlocksZero.selector);
        new GroupChat(address(groupDefaults), originBlocks, 0);
    }

    function testT010_activateChat_requiresCurrentOwner() public {
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(other);
        vm.expectRevert(IGroupChatErrors.NotChatOwner.selector);
        chat.activateChat(groupId, keys, values, address(0), address(0), address(0), address(0), 0);
    }

    function testT011_activateChat_setsLiveStateAndFirstActivationSnapshot() public {
        _activateEmpty();

        IGroupChat.ChatInfo memory info = chat.chatInfo(groupId);
        assertEq(info.groupId, groupId);
        assertEq(info.owner, chatOwner);
        assertTrue(info.activated);
        assertTrue(info.postingAllowed);
        assertTrue(chat.postingAllowed(groupId));
        assertEq(info.configVersion, 1);
        assertEq(info.delegateId, 0);
        assertEq(info.scopeSource, address(0));
        assertEq(info.denySource, address(0));
        assertEq(info.beforePostPlugin, address(0));
        assertEq(info.afterPostPlugin, address(0));
        assertEq(info.firstActivatedOwner, chatOwner);
        assertEq(info.firstActivatedBlockNumber, block.number);
        assertEq(info.firstActivatedTimestamp, block.timestamp);

        assertEq(chat.groupIdsCount(), 1);

        uint256[] memory allChats = chat.groupIds(0, 10, false);
        assertEq(allChats.length, 1);
        assertEq(allChats[0], groupId);
    }

    function testT012_activateCannotRepeat() public {
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        chat.activateChat(groupId, keys, values, address(0), address(0), address(0), address(0), 0);

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.ChatAlreadyActivated.selector);
        chat.activateChat(groupId, keys, values, address(0), address(0), address(0), address(0), 0);

        assertEq(chat.groupIdsCount(), 1);
    }

    function testT013_postingAllowedStopsAndResumesPostingOnly() public {
        string[] memory keys1 = new string[](1);
        bytes[] memory values1 = new bytes[](1);
        keys1[0] = "k1";
        values1[0] = bytes("v1");

        vm.prank(chatOwner);
        chat.activateChat(groupId, keys1, values1, address(0), address(0), address(0), address(0), 0);

        IGroupChat.ChatInfo memory firstInfo = chat.chatInfo(groupId);

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(groupId, senderId, "old-message");

        vm.prank(chatOwner);
        chat.setPostingAllowed(groupId, false);

        assertTrue(!chat.postingAllowed(groupId));
        assertTrue(!_canPostAllowed(groupId, senderId, senderOwner));
        vm.prank(senderOwner);
        vm.expectRevert(IGroupChatErrors.PostingNotAllowed.selector);
        _post(groupId, senderId, "stopped");

        vm.prank(chatOwner);
        chat.setMeta(groupId, "k2", bytes("v2"));
        vm.prank(chatOwner);
        chat.setDelegateId(groupId, delegateId);
        vm.prank(chatOwner);
        chat.setPostingAllowed(groupId, true);
        assertTrue(chat.postingAllowed(groupId));

        IGroupChat.ChatInfo memory secondInfo = chat.chatInfo(groupId);
        assertEq(secondInfo.firstActivatedOwner, firstInfo.firstActivatedOwner);
        assertEq(secondInfo.firstActivatedBlockNumber, firstInfo.firstActivatedBlockNumber);
        assertEq(secondInfo.firstActivatedTimestamp, firstInfo.firstActivatedTimestamp);
        assertEq(chat.metaValue(groupId, "k1"), bytes("v1"));
        assertEq(chat.metaValue(groupId, "k2"), bytes("v2"));
        assertEq(chat.messagesCount(groupId), 1);
        IGroupChat.Message[] memory fetched = chat.messages(groupId, 0, 1, false);
        assertEq(fetched.length, 1);
        assertEq(fetched[0].content, "old-message");
        assertEq(fetched[0].mentionedSenderIds.length, 0);
        assertTrue(!fetched[0].mentionAll);
        assertEq(chat.delegateIdOf(groupId), delegateId);
        assertEq(chat.chatInfo(groupId).delegateId, delegateId);
        assertEq(chat.groupIdsCount(), 1);

        vm.prank(senderOwner);
        _post(groupId, senderId, "resumed");
        assertEq(chat.messagesCount(groupId), 2);
    }

    function testT014_postingAllowedPermissionsAndNoop() public {
        _activateEmpty();

        vm.prank(other);
        vm.expectRevert(IGroupChatErrors.NotChatOwnerOrDelegateIdOwner.selector);
        chat.setPostingAllowed(groupId, false);

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.PostingAllowedUnchanged.selector);
        chat.setPostingAllowed(groupId, true);

        vm.prank(chatOwner);
        chat.setDelegateId(groupId, delegateId);

        vm.recordLogs();
        vm.prank(delegateIdOwner);
        chat.setPostingAllowed(groupId, false);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], POSTING_ALLOWED_SET_SIG);
        IGroupChat.ChatInfo memory info = chat.chatInfo(groupId);
        assertTrue(!info.postingAllowed);
        assertEq(info.configVersion, 3);
    }

    function testT016_groupDiscoveryIndexesTrackActivatedChats() public {
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        assertEq(chat.groupIdsCount(), 0);

        vm.prank(chatOwner);
        chat.activateChat(groupId, keys, values, address(0), address(0), address(0), address(0), 0);

        vm.prank(senderOwner);
        chat.activateChat(senderId, keys, values, address(0), address(0), address(0), address(0), 0);

        uint256[] memory allChats = chat.groupIds(0, 10, false);
        assertEq(allChats.length, 2);
        assertEq(allChats[0], groupId);
        assertEq(allChats[1], senderId);

        uint256[] memory allChatsReverse = chat.groupIds(0, 10, true);
        assertEq(allChatsReverse.length, 2);
        assertEq(allChatsReverse[0], senderId);
        assertEq(allChatsReverse[1], groupId);

        vm.prank(chatOwner);
        chat.setPostingAllowed(groupId, false);

        assertEq(chat.groupIdsCount(), 2);

        uint256[] memory allAfterStop = chat.groupIds(0, 10, false);
        assertEq(allAfterStop.length, 2);
        assertEq(allAfterStop[0], groupId);
        assertEq(allAfterStop[1], senderId);
    }
}
