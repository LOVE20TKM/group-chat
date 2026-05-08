// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChatErrors, IGroupChatStructs} from "../src/interfaces/IGroupChat.sol";
import {MockAfterPostFailPlugin, MockBeforePostRejectPlugin} from "./mocks/MockPlugins.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";
import {Vm} from "./utils/TestBase.sol";

contract GroupChatMetaTest is GroupChatFixture {
    function testT020T021T022T027_metaUpdatesAndBatchShareOneConfigVersion() public {
        _activateEmpty();

        vm.prank(chatOwner);
        chat.setMeta(chatGroupId, "name", bytes("v1"));
        assertEq(chat.chatInfo(chatGroupId).configVersion, 2);
        assertEq(chat.metaValue(chatGroupId, "name"), bytes("v1"));

        vm.prank(chatOwner);
        chat.setMeta(chatGroupId, "name", bytes("v2"));
        assertEq(chat.chatInfo(chatGroupId).configVersion, 3);
        assertEq(chat.metaValue(chatGroupId, "name"), bytes("v2"));

        string[] memory batchKeys = new string[](2);
        bytes[] memory batchValues = new bytes[](2);
        batchKeys[0] = "name";
        batchValues[0] = bytes("v3");
        batchKeys[1] = "topic";
        batchValues[1] = bytes("chat");

        vm.recordLogs();
        vm.prank(chatOwner);
        chat.setMetaBatch(chatGroupId, batchKeys, batchValues);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(chat.chatInfo(chatGroupId).configVersion, 4);
        assertEq(logs.length, 2);
        assertEq(logs[0].topics[0], META_SET_SIG);
        assertEq(logs[1].topics[0], META_SET_SIG);
        assertEq(_decodeMetaConfigVersion(logs[0].data), 4);
        assertEq(_decodeMetaConfigVersion(logs[1].data), 4);

        vm.prank(chatOwner);
        chat.setMeta(chatGroupId, "topic", bytes(""));
        assertEq(chat.chatInfo(chatGroupId).configVersion, 5);
        assertEq(chat.metaValue(chatGroupId, "topic"), bytes(""));

        IGroupChatStructs.MetaEntry[] memory entries = chat.metaEntries(chatGroupId, 0, 10, false);
        assertEq(entries.length, 1);
        assertEq(entries[0].key, "name");
        assertEq(entries[0].value, bytes("v3"));
    }

    function testT023T024T025T026_metaInvalidCasesRevert() public {
        _activateEmpty();

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.MetaKeyNotFound.selector);
        chat.setMeta(chatGroupId, "missing", bytes(""));

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.MetaKeyEmpty.selector);
        chat.setMeta(chatGroupId, "", bytes("v"));

        vm.prank(chatOwner);
        chat.setMeta(chatGroupId, "same", bytes("v1"));

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.MetaValueUnchanged.selector);
        chat.setMeta(chatGroupId, "same", bytes("v1"));

        string[] memory batchKeys = new string[](2);
        bytes[] memory batchValues = new bytes[](2);
        batchKeys[0] = "dup";
        batchValues[0] = bytes("1");
        batchKeys[1] = "dup";
        batchValues[1] = bytes("2");

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.DuplicateMetaKey.selector);
        chat.setMetaBatch(chatGroupId, batchKeys, batchValues);
    }

    function testT028T082_activateChatWritesInitialMetaAndChatActivateLast() public {
        MockBeforePostRejectPlugin beforePlugin = new MockBeforePostRejectPlugin();
        MockAfterPostFailPlugin afterPlugin = new MockAfterPostFailPlugin();

        string[] memory keys1 = new string[](2);
        bytes[] memory values1 = new bytes[](2);
        keys1[0] = "a";
        values1[0] = bytes("1");
        keys1[1] = "b";
        values1[1] = bytes("2");

        vm.recordLogs();
        vm.prank(chatOwner);
        chat.activateChat(
            chatGroupId, keys1, values1, address(0), address(0), address(beforePlugin), address(afterPlugin), delegateId
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(chat.chatInfo(chatGroupId).configVersion, 1);

        IGroupChatStructs.MetaEntry[] memory entries = chat.metaEntries(chatGroupId, 0, 10, false);
        assertEq(entries.length, 2);
        assertEq(entries[0].key, "a");
        assertEq(entries[0].value, bytes("1"));
        assertEq(entries[1].key, "b");
        assertEq(entries[1].value, bytes("2"));

        assertEq(logs.length, 6);
        assertEq(logs[0].topics[0], META_SET_SIG);
        assertEq(_decodeMetaConfigVersion(logs[0].data), 1);
        assertEq(_decodeMetaKey(logs[0].data), "a");
        assertEq(_decodeMetaValue(logs[0].data), bytes("1"));
        assertEq(_decodeMetaPrevValue(logs[0].data), bytes(""));

        assertEq(logs[1].topics[0], META_SET_SIG);
        assertEq(_decodeMetaKey(logs[1].data), "b");
        assertEq(_decodeMetaValue(logs[1].data), bytes("2"));
        assertEq(_decodeMetaPrevValue(logs[1].data), bytes(""));

        assertEq(logs[2].topics[0], DELEGATE_GROUP_ID_SET_SIG);
        assertEq(_decodeVersionAndUint256(logs[2].data), 1);
        assertEq(logs[3].topics[0], BEFORE_POST_PLUGIN_SET_SIG);
        assertEq(_decodeVersionAndAddress(logs[3].data), 1);
        assertEq(logs[4].topics[0], AFTER_POST_PLUGIN_SET_SIG);
        assertEq(_decodeVersionAndAddress(logs[4].data), 1);
        assertEq(logs[5].topics[0], CHAT_ACTIVATE_SIG);
        assertEq(_decodeChatActivateVersion(logs[5].data), 1);
    }

    function testT029_setMetaBatchTreatsExplicitEmptyMetaAsDeletion() public {
        string[] memory keys1 = new string[](2);
        bytes[] memory values1 = new bytes[](2);
        keys1[0] = "a";
        values1[0] = bytes("1");
        keys1[1] = "b";
        values1[1] = bytes("2");

        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys1, values1, address(0), address(0), address(0), address(0), 0);

        string[] memory keys2 = new string[](1);
        bytes[] memory values2 = new bytes[](1);
        keys2[0] = "a";
        values2[0] = bytes("");

        vm.recordLogs();
        vm.prank(chatOwner);
        chat.setMetaBatch(chatGroupId, keys2, values2);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        IGroupChatStructs.MetaEntry[] memory entries = chat.metaEntries(chatGroupId, 0, 10, false);
        assertEq(entries.length, 1);
        assertEq(entries[0].key, "b");
        assertEq(entries[0].value, bytes("2"));
        assertEq(chat.metaValue(chatGroupId, "a"), bytes(""));

        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], META_SET_SIG);
        assertEq(_decodeMetaConfigVersion(logs[0].data), 2);
        assertEq(_decodeMetaKey(logs[0].data), "a");
        assertEq(_decodeMetaValue(logs[0].data), bytes(""));
        assertEq(_decodeMetaPrevValue(logs[0].data), bytes("1"));
    }

    function testT080T081_versionsStayConsistentAcrossConfigWrites() public {
        _activateEmpty();

        vm.recordLogs();
        vm.prank(chatOwner);
        chat.setDelegateId(chatGroupId, delegateId);
        Vm.Log[] memory logs1 = vm.getRecordedLogs();

        assertEq(logs1.length, 1);
        assertEq(logs1[0].topics[0], DELEGATE_GROUP_ID_SET_SIG);
        assertEq(_decodeVersionAndUint256(logs1[0].data), chat.chatInfo(chatGroupId).configVersion);

        string[] memory batchKeys = new string[](2);
        bytes[] memory batchValues = new bytes[](2);
        batchKeys[0] = "k1";
        batchValues[0] = bytes("v1");
        batchKeys[1] = "k2";
        batchValues[1] = bytes("v2");

        vm.recordLogs();
        vm.prank(chatOwner);
        chat.setMetaBatch(chatGroupId, batchKeys, batchValues);
        Vm.Log[] memory logs2 = vm.getRecordedLogs();
        uint256 versionAfterBatch = chat.chatInfo(chatGroupId).configVersion;

        assertEq(logs2.length, 2);
        assertEq(_decodeMetaConfigVersion(logs2[0].data), versionAfterBatch);
        assertEq(_decodeMetaConfigVersion(logs2[1].data), versionAfterBatch);
    }
}
