// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChatErrors} from "../src/interfaces/IGroupChat.sol";
import {MockAfterPostFailPlugin, MockBeforePostRejectPlugin} from "./mocks/MockPlugins.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";
import {Vm} from "./utils/TestBase.sol";

contract GroupChatMetaTest is GroupChatFixture {
    function testT020T021T022T027_metaUpdatesAndBatchShareOneConfigVersion() public {
        _activateEmpty();

        vm.prank(chatOwner);
        chat.setMeta(groupId, "name", bytes("v1"));
        assertEq(chat.chatInfo(groupId).configVersion, 2);
        assertEq(chat.metaValue(groupId, "name"), bytes("v1"));
        assertEq(chat.metaEntriesCount(groupId), 1);

        vm.prank(chatOwner);
        chat.setMeta(groupId, "name", bytes("v2"));
        assertEq(chat.chatInfo(groupId).configVersion, 3);
        assertEq(chat.metaValue(groupId, "name"), bytes("v2"));

        string[] memory batchKeys = new string[](2);
        bytes[] memory batchValues = new bytes[](2);
        batchKeys[0] = "name";
        batchValues[0] = bytes("v3");
        batchKeys[1] = "topic";
        batchValues[1] = bytes("chat");

        vm.recordLogs();
        vm.prank(chatOwner);
        chat.setMetaBatch(groupId, batchKeys, batchValues);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(chat.chatInfo(groupId).configVersion, 4);
        assertEq(logs.length, 2);
        assertEq(logs[0].topics[0], META_SET_SIG);
        assertEq(logs[1].topics[0], META_SET_SIG);
        assertEq(_decodeMetaConfigVersion(logs[0].data), 4);
        assertEq(_decodeMetaConfigVersion(logs[1].data), 4);

        vm.prank(chatOwner);
        chat.setMeta(groupId, "topic", bytes(""));
        assertEq(chat.chatInfo(groupId).configVersion, 5);
        assertEq(chat.metaValue(groupId, "topic"), bytes(""));
        assertEq(chat.metaEntriesCount(groupId), 1);

        (string[] memory entryKeys, bytes[] memory entryValues) = chat.metaEntries(groupId, 0, 10, false);
        assertEq(entryKeys.length, 1);
        assertEq(entryValues.length, 1);
        assertEq(entryKeys[0], "name");
        assertEq(entryValues[0], bytes("v3"));
    }

    function testT023T024T025T026_metaInvalidCasesRevert() public {
        _activateEmpty();

        uint256 versionBeforeMissingDelete = chat.chatInfo(groupId).configVersion;
        vm.recordLogs();
        vm.prank(chatOwner);
        chat.setMeta(groupId, "missing", bytes(""));
        Vm.Log[] memory missingDeleteLogs = vm.getRecordedLogs();
        assertEq(missingDeleteLogs.length, 0);
        assertEq(chat.chatInfo(groupId).configVersion, versionBeforeMissingDelete);

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.MetaKeyEmpty.selector);
        chat.setMeta(groupId, "", bytes("v"));

        vm.prank(chatOwner);
        chat.setMeta(groupId, "same", bytes("v1"));

        uint256 versionBeforeSameValue = chat.chatInfo(groupId).configVersion;
        vm.recordLogs();
        vm.prank(chatOwner);
        chat.setMeta(groupId, "same", bytes("v1"));
        Vm.Log[] memory sameValueLogs = vm.getRecordedLogs();
        assertEq(sameValueLogs.length, 0);
        assertEq(chat.chatInfo(groupId).configVersion, versionBeforeSameValue);

        string[] memory batchKeys = new string[](2);
        bytes[] memory batchValues = new bytes[](2);
        batchKeys[0] = "dup";
        batchValues[0] = bytes("1");
        batchKeys[1] = "dup";
        batchValues[1] = bytes("2");

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.DuplicateMetaKey.selector);
        chat.setMetaBatch(groupId, batchKeys, batchValues);
    }

    function testT028T082_activateChatWritesInitialMetaAndActivateLast() public {
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
        chat.activateChat(groupId, keys1, values1, address(0), address(0), address(beforePlugin), address(afterPlugin));
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(chat.chatInfo(groupId).configVersion, 1);
        assertEq(chat.metaEntriesCount(groupId), 2);

        (string[] memory entryKeys, bytes[] memory entryValues) = chat.metaEntries(groupId, 0, 10, false);
        assertEq(entryKeys.length, 2);
        assertEq(entryValues.length, 2);
        assertEq(entryKeys[0], "a");
        assertEq(entryValues[0], bytes("1"));
        assertEq(entryKeys[1], "b");
        assertEq(entryValues[1], bytes("2"));

        assertEq(logs.length, 5);
        assertEq(logs[0].topics[0], META_SET_SIG);
        assertEq(_decodeMetaConfigVersion(logs[0].data), 1);
        assertEq(_decodeMetaKey(logs[0].data), "a");
        assertEq(_decodeMetaValue(logs[0].data), bytes("1"));
        assertEq(_decodeMetaPrevValue(logs[0].data), bytes(""));

        assertEq(logs[1].topics[0], META_SET_SIG);
        assertEq(_decodeMetaKey(logs[1].data), "b");
        assertEq(_decodeMetaValue(logs[1].data), bytes("2"));
        assertEq(_decodeMetaPrevValue(logs[1].data), bytes(""));

        assertEq(logs[2].topics[0], BEFORE_POST_PLUGIN_SET_SIG);
        assertEq(_decodeVersionAndAddress(logs[2].data), 1);
        assertEq(logs[3].topics[0], AFTER_POST_PLUGIN_SET_SIG);
        assertEq(_decodeVersionAndAddress(logs[3].data), 1);
        assertEq(logs[4].topics[0], ACTIVATE_SIG);
        assertEq(_decodeActivateVersion(logs[4].data), 1);
    }

    function testT029_setMetaBatchTreatsExplicitEmptyMetaAsDeletion() public {
        string[] memory keys1 = new string[](2);
        bytes[] memory values1 = new bytes[](2);
        keys1[0] = "a";
        values1[0] = bytes("1");
        keys1[1] = "b";
        values1[1] = bytes("2");

        vm.prank(chatOwner);
        chat.activateChat(groupId, keys1, values1, address(0), address(0), address(0), address(0));

        string[] memory keys2 = new string[](1);
        bytes[] memory values2 = new bytes[](1);
        keys2[0] = "a";
        values2[0] = bytes("");

        vm.recordLogs();
        vm.prank(chatOwner);
        chat.setMetaBatch(groupId, keys2, values2);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        (string[] memory entryKeys, bytes[] memory entryValues) = chat.metaEntries(groupId, 0, 10, false);
        assertEq(entryKeys.length, 1);
        assertEq(entryValues.length, 1);
        assertEq(chat.metaEntriesCount(groupId), 1);
        assertEq(entryKeys[0], "b");
        assertEq(entryValues[0], bytes("2"));
        assertEq(chat.metaValue(groupId, "a"), bytes(""));

        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], META_SET_SIG);
        assertEq(_decodeMetaConfigVersion(logs[0].data), 2);
        assertEq(_decodeMetaKey(logs[0].data), "a");
        assertEq(_decodeMetaValue(logs[0].data), bytes(""));
        assertEq(_decodeMetaPrevValue(logs[0].data), bytes("1"));
    }

    function testT094_setMetaBatchSkipsNoopEntriesWhenOtherEntriesChange() public {
        string[] memory keys1 = new string[](2);
        bytes[] memory values1 = new bytes[](2);
        keys1[0] = "a";
        values1[0] = bytes("1");
        keys1[1] = "b";
        values1[1] = bytes("2");

        vm.prank(chatOwner);
        chat.activateChat(groupId, keys1, values1, address(0), address(0), address(0), address(0));

        string[] memory batchKeys = new string[](3);
        bytes[] memory batchValues = new bytes[](3);
        batchKeys[0] = "missing";
        batchValues[0] = bytes("");
        batchKeys[1] = "b";
        batchValues[1] = bytes("2");
        batchKeys[2] = "c";
        batchValues[2] = bytes("3");

        vm.recordLogs();
        vm.prank(chatOwner);
        chat.setMetaBatch(groupId, batchKeys, batchValues);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        (string[] memory entryKeys, bytes[] memory entryValues) = chat.metaEntries(groupId, 0, 10, false);
        assertEq(entryKeys.length, 3);
        assertEq(entryValues.length, 3);
        assertEq(chat.metaEntriesCount(groupId), 3);
        assertEq(entryKeys[0], "a");
        assertEq(entryValues[0], bytes("1"));
        assertEq(entryKeys[1], "b");
        assertEq(entryValues[1], bytes("2"));
        assertEq(entryKeys[2], "c");
        assertEq(entryValues[2], bytes("3"));
        assertEq(chat.metaValue(groupId, "a"), bytes("1"));
        assertEq(chat.metaValue(groupId, "missing"), bytes(""));

        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], META_SET_SIG);
        assertEq(_decodeMetaConfigVersion(logs[0].data), 2);
        assertEq(_decodeMetaKey(logs[0].data), "c");
        assertEq(_decodeMetaValue(logs[0].data), bytes("3"));
        assertEq(_decodeMetaPrevValue(logs[0].data), bytes(""));
    }

    function testT080T081_versionsStayConsistentAcrossConfigWrites() public {
        _activateEmpty();

        string[] memory batchKeys = new string[](2);
        bytes[] memory batchValues = new bytes[](2);
        batchKeys[0] = "k1";
        batchValues[0] = bytes("v1");
        batchKeys[1] = "k2";
        batchValues[1] = bytes("v2");

        vm.recordLogs();
        vm.prank(chatOwner);
        chat.setMetaBatch(groupId, batchKeys, batchValues);
        Vm.Log[] memory logs2 = vm.getRecordedLogs();
        uint256 versionAfterBatch = chat.chatInfo(groupId).configVersion;

        assertEq(logs2.length, 2);
        assertEq(_decodeMetaConfigVersion(logs2[0].data), versionAfterBatch);
        assertEq(_decodeMetaConfigVersion(logs2[1].data), versionAfterBatch);
    }

    function testT091_metaLimitsRejectActivationAndOversizedValue() public {
        uint256 maxKeys = chat.MAX_META_KEYS();
        assertEq(maxKeys, 32);
        assertEq(chat.MAX_META_VALUE_LENGTH(), 4096);

        (string[] memory tooManyKeys, bytes[] memory tooManyValues) = _filledMeta(maxKeys + 1, bytes("v"));
        vm.prank(chatOwner);
        vm.expectRevert(abi.encodeWithSelector(IGroupChatErrors.TooManyMetaKeys.selector, maxKeys + 1, maxKeys));
        chat.activateChat(groupId, tooManyKeys, tooManyValues, address(0), address(0), address(0), address(0));

        _activateEmpty();

        uint256 maxValueLength = chat.MAX_META_VALUE_LENGTH();
        bytes memory tooLongValue = new bytes(maxValueLength + 1);
        vm.prank(chatOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IGroupChatErrors.MetaValueTooLong.selector, maxValueLength + 1, maxValueLength)
        );
        chat.setMeta(groupId, "long", tooLongValue);
    }

    function testT092_metaKeyLimitAllowsUpdateDeleteAndFinalBatchLength() public {
        _activateEmpty();

        uint256 maxKeys = chat.MAX_META_KEYS();
        (string[] memory keys, bytes[] memory values) = _filledMeta(maxKeys, bytes("v"));
        vm.prank(chatOwner);
        chat.setMetaBatch(groupId, keys, values);
        assertEq(chat.metaEntriesCount(groupId), maxKeys);

        vm.prank(chatOwner);
        chat.setMeta(groupId, "k0", bytes("v2"));
        assertEq(chat.metaEntriesCount(groupId), maxKeys);
        assertEq(chat.metaValue(groupId, "k0"), bytes("v2"));

        vm.prank(chatOwner);
        vm.expectRevert(abi.encodeWithSelector(IGroupChatErrors.TooManyMetaKeys.selector, maxKeys + 1, maxKeys));
        chat.setMeta(groupId, "overflow", bytes("v"));

        string[] memory replaceKeys = new string[](2);
        bytes[] memory replaceValues = new bytes[](2);
        replaceKeys[0] = "replacement";
        replaceValues[0] = bytes("v");
        replaceKeys[1] = "k0";
        replaceValues[1] = bytes("");

        vm.prank(chatOwner);
        chat.setMetaBatch(groupId, replaceKeys, replaceValues);
        assertEq(chat.metaEntriesCount(groupId), maxKeys);
        assertEq(chat.metaValue(groupId, "k0"), bytes(""));
        assertEq(chat.metaValue(groupId, "replacement"), bytes("v"));

        vm.prank(chatOwner);
        chat.setMeta(groupId, "k1", bytes(""));
        assertEq(chat.metaEntriesCount(groupId), maxKeys - 1);

        vm.prank(chatOwner);
        chat.setMeta(groupId, "replacement2", bytes("v"));
        assertEq(chat.metaEntriesCount(groupId), maxKeys);
    }

    function testT093_metaBatchLimitChecksFinalLengthBeforeWriting() public {
        _activateEmpty();

        uint256 maxKeys = chat.MAX_META_KEYS();
        (string[] memory keys, bytes[] memory values) = _filledMeta(maxKeys - 1, bytes("v"));
        vm.prank(chatOwner);
        chat.setMetaBatch(groupId, keys, values);

        string[] memory batchKeys = new string[](2);
        bytes[] memory batchValues = new bytes[](2);
        batchKeys[0] = "extra1";
        batchValues[0] = bytes("v");
        batchKeys[1] = "extra2";
        batchValues[1] = bytes("v");

        uint256 versionBefore = chat.chatInfo(groupId).configVersion;
        vm.prank(chatOwner);
        vm.expectRevert(abi.encodeWithSelector(IGroupChatErrors.TooManyMetaKeys.selector, maxKeys + 1, maxKeys));
        chat.setMetaBatch(groupId, batchKeys, batchValues);

        assertEq(chat.metaEntriesCount(groupId), maxKeys - 1);
        assertEq(chat.metaValue(groupId, "extra1"), bytes(""));
        assertEq(chat.metaValue(groupId, "extra2"), bytes(""));
        assertEq(chat.chatInfo(groupId).configVersion, versionBefore);
    }

    function _filledMeta(uint256 count, bytes memory value)
        internal
        pure
        returns (string[] memory keys, bytes[] memory values)
    {
        keys = new string[](count);
        values = new bytes[](count);
        for (uint256 i = 0; i < count; i++) {
            keys[i] = string(abi.encodePacked("k", _uintToString(i)));
            values[i] = value;
        }
    }

    function _uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }
        return string(buffer);
    }
}
