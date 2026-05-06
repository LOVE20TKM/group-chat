// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {GroupChat} from "../src/GroupChat.sol";
import {IGroupChatErrors, IGroupChatStructs} from "../src/interfaces/IGroupChat.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";

contract GroupChatLifecycleTest is GroupChatFixture {
    function testT001_constructorStoresConfigAndRoundNotStarted() public {
        assertEq(chat.LOVE20_GROUP(), address(groupNft));
        assertEq(chat.GROUP_DEFAULTS(), address(groupDefaults));
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
        chat.activateChat(chatGroupId, keys, values, address(0), address(0), address(0), address(0), 0);
    }

    function testT011_activateChat_setsLiveStateAndFirstActivationSnapshot() public {
        _activateEmpty();

        IGroupChatStructs.ChatInfo memory info = chat.chatInfo(chatGroupId);
        assertEq(info.groupId, chatGroupId);
        assertEq(info.owner, chatOwner);
        assertTrue(info.active);
        assertEq(info.configVersion, 1);
        assertEq(info.firstActivatedOwner, chatOwner);
        assertEq(info.firstActivatedBlockNumber, block.number);
        assertEq(info.firstActivatedTimestamp, block.timestamp);
    }

    function testT012T014_activateAndDeactivateCannotRepeat() public {
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(0), address(0), address(0), address(0), 0);

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.ChatAlreadyActive.selector);
        chat.activateChat(chatGroupId, keys, values, address(0), address(0), address(0), address(0), 0);

        vm.prank(chatOwner);
        chat.deactivateChat(chatGroupId);

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.ChatAlreadyInactive.selector);
        chat.deactivateChat(chatGroupId);
    }

    function testT015_reactivatePreservesFirstActivationAndHistory() public {
        string[] memory keys1 = new string[](1);
        bytes[] memory values1 = new bytes[](1);
        keys1[0] = "k1";
        values1[0] = bytes("v1");

        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys1, values1, address(0), address(0), address(0), address(0), 0);

        IGroupChatStructs.ChatInfo memory firstInfo = chat.chatInfo(chatGroupId);

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderGroupId, "old-message");

        vm.prank(chatOwner);
        chat.deactivateChat(chatGroupId);

        string[] memory keys2 = new string[](1);
        bytes[] memory values2 = new bytes[](1);
        keys2[0] = "k2";
        values2[0] = bytes("v2");

        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys2, values2, address(0), address(0), address(0), address(0), delegateGroupId);

        IGroupChatStructs.ChatInfo memory secondInfo = chat.chatInfo(chatGroupId);
        assertEq(secondInfo.firstActivatedOwner, firstInfo.firstActivatedOwner);
        assertEq(secondInfo.firstActivatedBlockNumber, firstInfo.firstActivatedBlockNumber);
        assertEq(secondInfo.firstActivatedTimestamp, firstInfo.firstActivatedTimestamp);
        assertEq(chat.metaValue(chatGroupId, "k1"), bytes(""));
        assertEq(chat.metaValue(chatGroupId, "k2"), bytes("v2"));
        assertEq(chat.messagesCount(chatGroupId), 1);
        IGroupChatStructs.Message[] memory fetched = chat.messages(chatGroupId, 0, 1, false);
        assertEq(fetched.length, 1);
        assertEq(fetched[0].content, "old-message");
        assertEq(fetched[0].mentions.length, 0);
        assertTrue(!fetched[0].mentionAll);
        assertEq(chat.delegateGroupIdOf(chatGroupId), delegateGroupId);
    }
}
