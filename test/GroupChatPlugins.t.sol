// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChat, IGroupChatErrors} from "../src/interfaces/IGroupChat.sol";
import {
    MockAfterPostCapturePlugin,
    MockAfterPostFailPlugin,
    MockAfterPostReenterPlugin,
    MockAfterPostSetMetaPlugin,
    MockBeforePostCapturePlugin,
    MockBeforePostRejectMentionAllPlugin,
    MockBeforePostRejectPlugin,
    MockManagedPlugin,
    MockPostDenyFailSource,
    MockPostDenySource,
    MockPostScopeFailSource,
    MockPostScopeSource
} from "./mocks/MockPlugins.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";
import {Vm} from "./utils/TestBase.sol";

contract GroupChatPluginsTest is GroupChatFixture {
    function testT013T074_stoppedChatBlocksPostingButAllowsConfigWrites() public {
        MockManagedPlugin managedPlugin = new MockManagedPlugin(address(chat));
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        chat.activateChat(
            chatGroupId, keys, values, address(0), address(0), address(managedPlugin), address(0), delegateId
        );

        vm.prank(chatOwner);
        chat.setPostingAllowed(chatGroupId, false);

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        vm.expectRevert(IGroupChatErrors.PostingNotAllowed.selector);
        _post(chatGroupId, senderId, "stopped");

        vm.prank(chatOwner);
        chat.setMeta(chatGroupId, "k", bytes("v"));
        assertEq(chat.metaValue(chatGroupId, "k"), bytes("v"));

        vm.prank(chatOwner);
        chat.setBeforePostPlugin(chatGroupId, address(0));
        assertEq(chat.beforePostPlugin(chatGroupId), address(0));

        vm.prank(chatOwner);
        managedPlugin.configure(chatGroupId, bytes("owner-ok"));
        assertEq(managedPlugin.configValue(chatGroupId), bytes("owner-ok"));

        vm.prank(delegateIdOwner);
        managedPlugin.configure(chatGroupId, bytes("delegate-ok"));
        assertEq(managedPlugin.configValue(chatGroupId), bytes("delegate-ok"));
    }

    function testT070_crossGroupPostWithoutPluginIsAllowedByDefault() public {
        _activateEmpty();

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "default-open");

        assertEq(chat.messagesCount(chatGroupId), 1);
    }

    function testT070A_scopeSourceControlsPostAndCanPostStatus() public {
        MockPostScopeSource scope = new MockPostScopeSource();
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(scope), address(0), address(0), address(0), 0);

        IGroupChat.ChatInfo memory info = chat.chatInfo(chatGroupId);
        assertEq(info.scopeSource, address(scope));
        assertEq(info.denySource, address(0));
        assertEq(info.beforePostPlugin, address(0));
        assertEq(info.afterPostPlugin, address(0));
        assertTrue(chat.canPost(chatGroupId, senderId, senderOwner));

        scope.setAllowed(false);
        assertTrue(!chat.canPost(chatGroupId, senderId, senderOwner));
        (bool allowed, bytes4 reasonCode) = chat.canPostStatus(chatGroupId, senderId, senderOwner);
        assertTrue(!allowed);
        assertEq(reasonCode, IGroupChatErrors.ScopeRejected.selector);

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        vm.expectRevert(IGroupChatErrors.ScopeRejected.selector);
        _post(chatGroupId, senderId, "blocked-by-scope");

        scope.setAllowed(true);
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "allowed-by-scope");
        assertEq(chat.messagesCount(chatGroupId), 1);
    }

    function testT070B_denySourceControlsPostAndCanPostStatus() public {
        MockPostDenySource deny = new MockPostDenySource();
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(0), address(deny), address(0), address(0), 0);

        assertEq(chat.denySource(chatGroupId), address(deny));
        assertTrue(chat.canPost(chatGroupId, senderId, senderOwner));

        deny.setDenied(true);
        (bool allowed, bytes4 reasonCode) = chat.canPostStatus(chatGroupId, senderId, senderOwner);
        assertTrue(!allowed);
        assertEq(reasonCode, IGroupChatErrors.DenyRejected.selector);

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        vm.expectRevert(IGroupChatErrors.DenyRejected.selector);
        _post(chatGroupId, senderId, "blocked-by-deny");

        deny.setDenied(false);
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "allowed-by-deny");
        assertEq(chat.messagesCount(chatGroupId), 1);
    }

    function testT070C_canPostStatusReturnsCoreAndSourceFailureReasons() public {
        (bool allowed, bytes4 reasonCode) = chat.canPostStatus(chatGroupId, senderId, senderOwner);
        assertTrue(!allowed);
        assertEq(reasonCode, IGroupChatErrors.ChatNotActivated.selector);

        (allowed, reasonCode) = chat.canPostStatus(999999, senderId, senderOwner);
        assertTrue(!allowed);
        assertEq(reasonCode, IGroupChatErrors.GroupNotExist.selector);

        _activateEmpty();

        (allowed, reasonCode) = chat.canPostStatus(chatGroupId, 999999, senderOwner);
        assertTrue(!allowed);
        assertEq(reasonCode, IGroupChatErrors.GroupNotExist.selector);

        (allowed, reasonCode) = chat.canPostStatus(chatGroupId, senderId, other);
        assertTrue(!allowed);
        assertEq(reasonCode, IGroupChatErrors.SenderAddressNotSenderIdOwner.selector);

        MockPostScopeFailSource failingScope = new MockPostScopeFailSource();
        vm.prank(chatOwner);
        chat.setScopeSource(chatGroupId, address(failingScope));

        (allowed, reasonCode) = chat.canPostStatus(chatGroupId, senderId, senderOwner);
        assertTrue(!allowed);
        assertEq(reasonCode, IGroupChatErrors.ScopeSourceFailed.selector);

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        vm.expectRevert(MockPostScopeFailSource.ScopeSourceBoom.selector);
        _post(chatGroupId, senderId, "scope-boom");

        vm.prank(chatOwner);
        chat.setScopeSource(chatGroupId, address(0));

        MockPostDenyFailSource failingDeny = new MockPostDenyFailSource();
        vm.prank(chatOwner);
        chat.setDenySource(chatGroupId, address(failingDeny));

        (allowed, reasonCode) = chat.canPostStatus(chatGroupId, senderId, senderOwner);
        assertTrue(!allowed);
        assertEq(reasonCode, IGroupChatErrors.DenySourceFailed.selector);

        vm.prank(senderOwner);
        vm.expectRevert(MockPostDenyFailSource.DenySourceBoom.selector);
        _post(chatGroupId, senderId, "deny-boom");
    }

    function testT070D_scopeSetterPermissionsNoopStoppedStateAndEvents() public {
        MockPostScopeSource scope1 = new MockPostScopeSource();
        MockPostScopeSource scope2 = new MockPostScopeSource();

        _activateEmpty();

        vm.prank(other);
        vm.expectRevert(IGroupChatErrors.NotChatOwnerOrDelegateIdOwner.selector);
        chat.setScopeSource(chatGroupId, address(scope1));

        vm.prank(chatOwner);
        chat.setDelegateId(chatGroupId, delegateId);

        vm.recordLogs();
        vm.prank(delegateIdOwner);
        chat.setScopeSource(chatGroupId, address(scope1));
        Vm.Log[] memory scopeLogs1 = vm.getRecordedLogs();
        (uint256 scopeVersion1, address prevScope1) = abi.decode(scopeLogs1[0].data, (uint256, address));
        assertEq(scopeLogs1.length, 1);
        assertEq(scopeLogs1[0].topics[0], SCOPE_SOURCE_SET_SIG);
        assertEq(scopeVersion1, 3);
        assertEq(prevScope1, address(0));
        assertEq(chat.scopeSource(chatGroupId), address(scope1));

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.PluginAddressUnchanged.selector);
        chat.setScopeSource(chatGroupId, address(scope1));

        vm.recordLogs();
        vm.prank(chatOwner);
        chat.setScopeSource(chatGroupId, address(scope2));
        Vm.Log[] memory scopeLogs2 = vm.getRecordedLogs();
        (uint256 scopeVersion2, address prevScope2) = abi.decode(scopeLogs2[0].data, (uint256, address));
        assertEq(scopeVersion2, 4);
        assertEq(prevScope2, address(scope1));

        vm.prank(chatOwner);
        chat.setScopeSource(chatGroupId, address(0));

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.PluginAddressUnchanged.selector);
        chat.setScopeSource(chatGroupId, address(0));

        vm.prank(chatOwner);
        chat.setPostingAllowed(chatGroupId, false);

        vm.prank(chatOwner);
        chat.setScopeSource(chatGroupId, address(scope1));
        assertEq(chat.scopeSource(chatGroupId), address(scope1));
    }

    function testT070E_denySetterPermissionsNoopStoppedStateAndEvents() public {
        MockPostDenySource deny1 = new MockPostDenySource();
        MockPostDenySource deny2 = new MockPostDenySource();

        _activateEmpty();

        vm.prank(other);
        vm.expectRevert(IGroupChatErrors.NotChatOwnerOrDelegateIdOwner.selector);
        chat.setDenySource(chatGroupId, address(deny1));

        vm.prank(chatOwner);
        chat.setDelegateId(chatGroupId, delegateId);

        vm.recordLogs();
        vm.prank(delegateIdOwner);
        chat.setDenySource(chatGroupId, address(deny1));
        Vm.Log[] memory denyLogs1 = vm.getRecordedLogs();
        (uint256 denyVersion1, address prevDeny1) = abi.decode(denyLogs1[0].data, (uint256, address));
        assertEq(denyLogs1.length, 1);
        assertEq(denyLogs1[0].topics[0], DENY_SOURCE_SET_SIG);
        assertEq(denyVersion1, 3);
        assertEq(prevDeny1, address(0));
        assertEq(chat.denySource(chatGroupId), address(deny1));

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.PluginAddressUnchanged.selector);
        chat.setDenySource(chatGroupId, address(deny1));

        vm.recordLogs();
        vm.prank(chatOwner);
        chat.setDenySource(chatGroupId, address(deny2));
        Vm.Log[] memory denyLogs2 = vm.getRecordedLogs();
        (uint256 denyVersion2, address prevDeny2) = abi.decode(denyLogs2[0].data, (uint256, address));
        assertEq(denyVersion2, 4);
        assertEq(prevDeny2, address(deny1));

        vm.prank(chatOwner);
        chat.setDenySource(chatGroupId, address(0));

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.PluginAddressUnchanged.selector);
        chat.setDenySource(chatGroupId, address(0));

        vm.prank(chatOwner);
        chat.setPostingAllowed(chatGroupId, false);

        vm.prank(chatOwner);
        chat.setDenySource(chatGroupId, address(deny1));
        assertEq(chat.denySource(chatGroupId), address(deny1));
    }

    function testT070F_activateChatEmitsSourceSlotDiffEvents() public {
        MockPostScopeSource scope = new MockPostScopeSource();
        MockPostDenySource deny = new MockPostDenySource();
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.recordLogs();
        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(scope), address(deny), address(0), address(0), 0);
        Vm.Log[] memory activateLogs = vm.getRecordedLogs();

        assertEq(activateLogs.length, 3);
        assertEq(activateLogs[0].topics[0], SCOPE_SOURCE_SET_SIG);
        assertEq(activateLogs[1].topics[0], DENY_SOURCE_SET_SIG);
        assertEq(activateLogs[2].topics[0], CHAT_ACTIVATE_SIG);
        assertEq(_decodeVersionAndAddress(activateLogs[0].data), 1);
        assertEq(_decodeVersionAndAddress(activateLogs[1].data), 1);
        assertEq(_decodeChatActivateVersion(activateLogs[2].data), 1);

        vm.recordLogs();
        vm.prank(chatOwner);
        chat.setScopeSource(chatGroupId, address(0));
        Vm.Log[] memory scopeLogs = vm.getRecordedLogs();

        vm.recordLogs();
        vm.prank(chatOwner);
        chat.setDenySource(chatGroupId, address(0));
        Vm.Log[] memory denyLogs = vm.getRecordedLogs();

        assertEq(scopeLogs.length, 1);
        assertEq(scopeLogs[0].topics[0], SCOPE_SOURCE_SET_SIG);
        assertEq(denyLogs.length, 1);
        assertEq(denyLogs[0].topics[0], DENY_SOURCE_SET_SIG);
        (uint256 scopeVersion, address prevScope) = abi.decode(scopeLogs[0].data, (uint256, address));
        (uint256 denyVersion, address prevDeny) = abi.decode(denyLogs[0].data, (uint256, address));
        assertEq(scopeVersion, 2);
        assertEq(denyVersion, 3);
        assertEq(prevScope, address(scope));
        assertEq(prevDeny, address(deny));
    }

    function testT071_beforePostRejectRevertsWholePost() public {
        MockBeforePostRejectPlugin beforePlugin = new MockBeforePostRejectPlugin();
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(0), address(0), address(beforePlugin), address(0), 0);

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        vm.expectRevert(MockBeforePostRejectPlugin.BeforePostRejected.selector);
        _post(chatGroupId, senderId, "blocked");

        assertEq(chat.messagesCount(chatGroupId), 0);
    }

    function testT072_afterPostFailureDoesNotRollbackAndEventOrderIsCorrect() public {
        MockAfterPostFailPlugin afterPlugin = new MockAfterPostFailPlugin();
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(0), address(0), address(0), address(afterPlugin), 0);

        vm.roll(originBlocks);
        vm.recordLogs();
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "ok");
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(chat.messagesCount(chatGroupId), 1);
        assertEq(logs.length, 2);
        assertEq(logs[0].topics[0], MESSAGE_POST_SIG);
        assertEq(logs[1].topics[0], AFTER_POST_PLUGIN_FAILED_SIG);
        (uint256 round, uint256 messageId) = _decodeMessagePost(logs[0].data);
        assertEq(round, 0);
        assertEq(messageId, 1);
        assertEq(_decodeAfterPostFailedRound(logs[1].data), 0);
    }

    function testT073_pluginAddressWithoutCodeReverts() public {
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.PluginAddressHasNoCode.selector);
        chat.activateChat(chatGroupId, keys, values, other, address(0), address(0), address(0), 0);

        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(0), address(0), address(0), address(0), 0);

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.PluginAddressHasNoCode.selector);
        chat.setScopeSource(chatGroupId, other);

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.PluginAddressHasNoCode.selector);
        chat.setDenySource(chatGroupId, other);

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.PluginAddressHasNoCode.selector);
        chat.setBeforePostPlugin(chatGroupId, other);

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.PluginAddressHasNoCode.selector);
        chat.setAfterPostPlugin(chatGroupId, other);
    }

    function testT075_afterPostReenterIsBlockedByNonReentrant() public {
        MockAfterPostReenterPlugin afterPlugin = new MockAfterPostReenterPlugin(address(chat), chatGroupId, senderId);
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(0), address(0), address(0), address(afterPlugin), 0);

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "outer");

        assertEq(chat.messagesCount(chatGroupId), 1);
    }

    function testT076_afterPostDelegateCannotMutateCoreState() public {
        MockAfterPostSetMetaPlugin afterPlugin = new MockAfterPostSetMetaPlugin(address(chat));
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(0), address(0), address(0), address(afterPlugin), 0);

        vm.roll(originBlocks);
        vm.recordLogs();
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "outer");
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(chat.messagesCount(chatGroupId), 1);
        assertEq(chat.chatInfo(chatGroupId).configVersion, 1);
        assertEq(chat.metaValue(chatGroupId, "hook-write"), bytes(""));
        assertEq(logs.length, 2);
        assertEq(logs[0].topics[0], MESSAGE_POST_SIG);
        assertEq(logs[1].topics[0], AFTER_POST_PLUGIN_FAILED_SIG);
    }

    function testT077_beforePostPluginReceivesMentionArgs() public {
        MockBeforePostCapturePlugin beforePlugin = new MockBeforePostCapturePlugin();
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(0), address(0), address(beforePlugin), address(0), 0);

        uint256[] memory mentionedSenderIds = new uint256[](2);
        mentionedSenderIds[0] = otherGroupId;
        mentionedSenderIds[1] = delegateId;

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _postWithMentionedSenderIds(chatGroupId, senderId, "@all hi", mentionedSenderIds, true);

        assertEq(beforePlugin.lastChatGroupId(), chatGroupId);
        assertEq(beforePlugin.lastSenderId(), senderId);
        assertEq(beforePlugin.lastSenderAddress(), senderOwner);
        assertEq(beforePlugin.lastContent(), "@all hi");
        assertTrue(beforePlugin.lastMentionAll());

        uint256[] memory captured = beforePlugin.lastMentionedSenderIds();
        assertEq(captured.length, 2);
        assertEq(captured[0], otherGroupId);
        assertEq(captured[1], delegateId);
        assertEq(beforePlugin.lastQuotedMessageId(), 0);

        assertEq(chat.messagesCount(chatGroupId), 1);
        assertTrue(chat.messages(chatGroupId, 0, 1, false)[0].mentionAll);
    }

    function testT078_beforePostPluginCanJudgeMentionAll() public {
        MockBeforePostRejectMentionAllPlugin beforePlugin = new MockBeforePostRejectMentionAllPlugin();
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(0), address(0), address(beforePlugin), address(0), 0);

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "plain");

        vm.prank(senderOwner);
        vm.expectRevert(MockBeforePostRejectMentionAllPlugin.MentionAllRejected.selector);
        _postWithMentionedSenderIds(chatGroupId, senderId, "@all", _emptyMentionedSenderIds(), true);

        assertEq(chat.messagesCount(chatGroupId), 1);
        assertTrue(!chat.messages(chatGroupId, 0, 1, false)[0].mentionAll);
    }

    function testT079_beforeAndAfterPostPluginsReceiveQuoteAndMessageContext() public {
        MockBeforePostCapturePlugin beforePlugin = new MockBeforePostCapturePlugin();
        MockAfterPostCapturePlugin afterPlugin = new MockAfterPostCapturePlugin();
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        chat.activateChat(
            chatGroupId, keys, values, address(0), address(0), address(beforePlugin), address(afterPlugin), 0
        );

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "base");

        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "base-1");

        uint256[] memory mentionedSenderIds = new uint256[](1);
        mentionedSenderIds[0] = otherGroupId;

        vm.prank(senderOwner);
        chat.post(chatGroupId, senderId, "quoted", mentionedSenderIds, true, 1);

        assertEq(beforePlugin.lastQuotedMessageId(), 1);

        uint256[] memory beforeMentionedSenderIds = beforePlugin.lastMentionedSenderIds();
        assertEq(beforeMentionedSenderIds.length, 1);
        assertEq(beforeMentionedSenderIds[0], otherGroupId);

        assertEq(afterPlugin.lastChatGroupId(), chatGroupId);
        assertEq(afterPlugin.lastSenderId(), senderId);
        assertEq(afterPlugin.lastSenderAddress(), senderOwner);
        assertEq(afterPlugin.lastContent(), "quoted");
        assertTrue(afterPlugin.lastMentionAll());
        assertEq(afterPlugin.lastQuotedMessageId(), 1);
        assertEq(afterPlugin.lastMessageId(), 3);
        assertEq(afterPlugin.lastBlockNumber(), block.number);
        assertEq(afterPlugin.lastTimestamp(), block.timestamp);

        uint256[] memory afterMentionedSenderIds = afterPlugin.lastMentionedSenderIds();
        assertEq(afterMentionedSenderIds.length, 1);
        assertEq(afterMentionedSenderIds[0], otherGroupId);
    }
}
