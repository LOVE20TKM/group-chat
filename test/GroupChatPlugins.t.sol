// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChatErrors} from "../src/interfaces/IGroupChat.sol";
import {
    MockAfterPostFailPlugin,
    MockAfterPostReenterPlugin,
    MockAfterPostSetMetaPlugin,
    MockBeforePostRejectPlugin,
    MockManagedPlugin
} from "./mocks/MockPlugins.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";
import {Vm} from "./utils/TestBase.sol";

contract GroupChatPluginsTest is GroupChatFixture {
    function testT013T074_closedChatBlocksMainWritesButAllowsPluginInternalConfig() public {
        MockManagedPlugin managedPlugin = new MockManagedPlugin(address(chat));
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        chat.activateChat(
            chatGroupId,
            keys,
            values,
            address(managedPlugin),
            address(0),
            delegate
        );

        vm.prank(chatOwner);
        chat.deactivateChat(chatGroupId);

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.ChatNotActive.selector);
        chat.setMeta(chatGroupId, "k", bytes("v"));

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.ChatNotActive.selector);
        chat.setBeforePostPlugin(chatGroupId, address(0));

        vm.prank(chatOwner);
        managedPlugin.configure(chatGroupId, bytes("owner-ok"));
        assertEq(managedPlugin.configValue(chatGroupId), bytes("owner-ok"));

        vm.prank(delegate);
        managedPlugin.configure(chatGroupId, bytes("delegate-ok"));
        assertEq(managedPlugin.configValue(chatGroupId), bytes("delegate-ok"));
    }

    function testT070_crossGroupPostWithoutPluginIsAllowedByDefault() public {
        _activateEmpty();

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        chat.post(chatGroupId, senderGroupId, "default-open");

        assertEq(chat.messagesCount(chatGroupId), 1);
    }

    function testT071_beforePostRejectRevertsWholePost() public {
        MockBeforePostRejectPlugin beforePlugin = new MockBeforePostRejectPlugin();
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        chat.activateChat(
            chatGroupId,
            keys,
            values,
            address(beforePlugin),
            address(0),
            address(0)
        );

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        vm.expectRevert(MockBeforePostRejectPlugin.BeforePostRejected.selector);
        chat.post(chatGroupId, senderGroupId, "blocked");

        assertEq(chat.messagesCount(chatGroupId), 0);
    }

    function testT072_afterPostFailureDoesNotRollbackAndEventOrderIsCorrect() public {
        MockAfterPostFailPlugin afterPlugin = new MockAfterPostFailPlugin();
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        chat.activateChat(
            chatGroupId,
            keys,
            values,
            address(0),
            address(afterPlugin),
            address(0)
        );

        vm.roll(originBlocks);
        vm.recordLogs();
        vm.prank(senderOwner);
        chat.post(chatGroupId, senderGroupId, "ok");
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(chat.messagesCount(chatGroupId), 1);
        assertEq(logs.length, 2);
        assertEq(logs[0].topics[0], MESSAGE_POST_SIG);
        assertEq(logs[1].topics[0], AFTER_POST_PLUGIN_FAILED_SIG);
        assertEq(_decodeMessagePostVersion(logs[0].data), 1);
        assertEq(_decodeAfterPostFailedVersion(logs[1].data), 1);
    }

    function testT073_pluginAddressWithoutCodeReverts() public {
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.PluginAddressHasNoCode.selector);
        chat.activateChat(chatGroupId, keys, values, other, address(0), address(0));

        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(0), address(0), address(0));

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.PluginAddressHasNoCode.selector);
        chat.setBeforePostPlugin(chatGroupId, other);

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.PluginAddressHasNoCode.selector);
        chat.setAfterPostPlugin(chatGroupId, other);
    }

    function testT075_afterPostReenterIsBlockedByNonReentrant() public {
        MockAfterPostReenterPlugin afterPlugin =
            new MockAfterPostReenterPlugin(address(chat), chatGroupId, senderGroupId);
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        chat.activateChat(
            chatGroupId,
            keys,
            values,
            address(0),
            address(afterPlugin),
            address(0)
        );

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        chat.post(chatGroupId, senderGroupId, "outer");

        assertEq(chat.messagesCount(chatGroupId), 1);
    }

    function testT076_afterPostDelegateCannotMutateCoreState() public {
        MockAfterPostSetMetaPlugin afterPlugin = new MockAfterPostSetMetaPlugin(address(chat));
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        chat.activateChat(
            chatGroupId,
            keys,
            values,
            address(0),
            address(afterPlugin),
            address(afterPlugin)
        );

        vm.roll(originBlocks);
        vm.recordLogs();
        vm.prank(senderOwner);
        chat.post(chatGroupId, senderGroupId, "outer");
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(chat.messagesCount(chatGroupId), 1);
        assertEq(chat.chatInfo(chatGroupId).configVersion, 1);
        assertEq(chat.metaValue(chatGroupId, "hook-write"), bytes(""));
        assertEq(logs.length, 2);
        assertEq(logs[0].topics[0], MESSAGE_POST_SIG);
        assertEq(logs[1].topics[0], AFTER_POST_PLUGIN_FAILED_SIG);
    }
}
