// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {GroupChat} from "../src/GroupChat.sol";
import {IGroupChatErrors, IGroupChatStructs} from "../src/interfaces/IGroupChat.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";
import {Vm} from "./utils/TestBase.sol";

contract GroupChatMessagesTest is GroupChatFixture {
    function testT040_post_ownerCanPostWithOwnedSenderId() public {
        _activateEmpty();

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "hello");

        assertEq(chat.messagesCount(chatGroupId), 1);

        IGroupChatStructs.Message[] memory result = chat.messages(chatGroupId, 0, 1, false);
        assertEq(result.length, 1);
        assertEq(result[0].chatGroupId, chatGroupId);
        assertEq(result[0].senderId, senderId);
        assertEq(result[0].senderAddress, senderOwner);
        assertEq(result[0].round, 0);
        assertEq(result[0].messageId, 1);
        assertEq(result[0].content, "hello");
        assertEq(result[0].blockNumber, originBlocks);
        assertEq(result[0].timestamp, block.timestamp);
        assertEq(result[0].mentions.length, 0);
        assertTrue(!result[0].mentionAll);
        assertEq(result[0].quotedMessageId, 0);
    }

    function testT041_crossGroupPostWithoutPluginIsAllowedByDefault() public {
        _activateEmpty();

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "cross-group");

        IGroupChatStructs.Message[] memory result = chat.messages(chatGroupId, 0, 1, false);
        assertEq(result.length, 1);
        assertEq(result[0].chatGroupId, chatGroupId);
        assertEq(result[0].senderId, senderId);
        assertTrue(chatGroupId != senderId);
    }

    function testT042_post_revertsForNonSenderOwner() public {
        _activateEmpty();

        vm.roll(originBlocks);
        vm.prank(other);
        vm.expectRevert(IGroupChatErrors.SenderAddressNotSenderIdOwner.selector);
        _post(chatGroupId, senderId, "hello");
    }

    function testT043T044T045T046T047_postInvalidCases() public {
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(0), address(0), address(0), address(0), delegateId);

        vm.roll(originBlocks);
        vm.prank(delegateIdOwner);
        vm.expectRevert(IGroupChatErrors.SenderAddressNotSenderIdOwner.selector);
        _post(chatGroupId, senderId, "delegate-send");

        vm.prank(chatOwner);
        chat.deactivateChat(chatGroupId);

        vm.prank(senderOwner);
        vm.expectRevert(IGroupChatErrors.ChatNotActive.selector);
        _post(chatGroupId, senderId, "closed");

        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(0), address(0), address(0), address(0), delegateId);

        vm.prank(senderOwner);
        vm.expectRevert(IGroupChatErrors.ContentEmpty.selector);
        _post(chatGroupId, senderId, "");

        uint256 maxContentLength = chat.MAX_CONTENT_LENGTH();
        bytes memory tooLongBytes = new bytes(maxContentLength + 1);
        string memory tooLong = string(tooLongBytes);
        vm.prank(senderOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IGroupChatErrors.ContentTooLong.selector, maxContentLength + 1, maxContentLength)
        );
        _post(chatGroupId, senderId, tooLong);

        GroupChat futureChat = new GroupChat(address(groupDefaults), block.number + 1000, phaseBlocks);
        vm.prank(chatOwner);
        futureChat.activateChat(chatGroupId, keys, values, address(0), address(0), address(0), address(0), 0);

        vm.prank(senderOwner);
        vm.expectRevert(IGroupChatErrors.RoundNotStarted.selector);
        futureChat.post(chatGroupId, senderId, "early", _emptyMentions(), false, 0);
    }

    function testT048_postStoresMentionsAndMentionIndexes() public {
        _activateEmpty();

        uint256[] memory mentions = new uint256[](2);
        mentions[0] = otherGroupId;
        mentions[1] = delegateId;

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _postWithMentions(chatGroupId, senderId, "hello @two", mentions, false);

        IGroupChatStructs.Message[] memory result = chat.messages(chatGroupId, 0, 1, false);
        assertEq(result.length, 1);
        assertEq(result[0].mentions.length, 2);
        assertEq(result[0].mentions[0], otherGroupId);
        assertEq(result[0].mentions[1], delegateId);
        assertTrue(!result[0].mentionAll);
        assertEq(result[0].quotedMessageId, 0);

        assertEq(chat.messagesByMentionCount(chatGroupId, otherGroupId), 1);
        assertEq(chat.messagesByMentionCount(chatGroupId, delegateId), 1);
        assertEq(chat.messagesByMentionCount(chatGroupId, 999999), 0);

        IGroupChatStructs.Message[] memory byMention =
            chat.messagesByMention(chatGroupId, delegateId, 0, 10, false);
        assertEq(byMention.length, 1);
        assertEq(byMention[0].messageId, 1);
        assertEq(byMention[0].mentions.length, 2);

        uint256[] memory indexes = chat.messageIdsByMention(chatGroupId, otherGroupId, 0, 10, false);
        assertEq(indexes.length, 1);
        assertEq(indexes[0], 1);
        assertEq(chat.messagesByMention(chatGroupId, 999999, 0, 10, false).length, 0);
        assertEq(chat.messageIdsByMention(chatGroupId, 999999, 0, 10, false).length, 0);
    }

    function testT049_postRejectsDuplicateMentionsAndIndexesMentionAll() public {
        (string[] memory keys, bytes[] memory values) = _emptyMeta();
        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(0), address(0), address(0), address(0), delegateId);

        uint256[] memory duplicateMentions = new uint256[](2);
        duplicateMentions[0] = otherGroupId;
        duplicateMentions[1] = otherGroupId;

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        vm.expectRevert(IGroupChatErrors.DuplicateMentionSenderId.selector);
        _postWithMentions(chatGroupId, senderId, "dup", duplicateMentions, false);

        vm.prank(senderOwner);
        _postWithMentions(chatGroupId, senderId, "@all-0", _emptyMentions(), true);

        vm.prank(other);
        _post(chatGroupId, otherGroupId, "plain");

        vm.prank(senderOwner);
        _postWithMentions(chatGroupId, senderId, "@all-1", _emptyMentions(), true);

        IGroupChatStructs.Message[] memory result = chat.messages(chatGroupId, 0, 10, false);
        assertEq(result.length, 3);
        assertTrue(result[0].mentionAll);
        assertTrue(!result[1].mentionAll);
        assertTrue(result[2].mentionAll);

        assertEq(chat.messagesByMentionAllCount(chatGroupId), 2);

        IGroupChatStructs.Message[] memory byMentionAll = chat.messagesByMentionAll(chatGroupId, 0, 10, false);
        assertEq(byMentionAll.length, 2);
        assertEq(byMentionAll[0].messageId, 1);
        assertEq(byMentionAll[1].messageId, 3);

        IGroupChatStructs.Message[] memory byMentionAllReverse = chat.messagesByMentionAll(chatGroupId, 0, 1, true);
        assertEq(byMentionAllReverse.length, 1);
        assertEq(byMentionAllReverse[0].messageId, 3);

        uint256[] memory indexes = chat.messageIdsByMentionAll(chatGroupId, 0, 10, false);
        assertEq(indexes.length, 2);
        assertEq(indexes[0], 1);
        assertEq(indexes[1], 3);

        uint256[] memory reverseIndexes = chat.messageIdsByMentionAll(chatGroupId, 1, 1, true);
        assertEq(reverseIndexes.length, 1);
        assertEq(reverseIndexes[0], 1);
    }

    function testT050_roundInfoAcrossRounds() public {
        _activateEmpty();

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "r0-0");
        vm.prank(other);
        _post(chatGroupId, otherGroupId, "r0-1");

        vm.roll(originBlocks + phaseBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "r1-0");

        assertEq(chat.roundsCount(chatGroupId), 2);

        IGroupChatStructs.RoundSpan memory round0 = chat.roundInfo(chatGroupId, 0);
        assertEq(round0.round, 0);
        assertEq(round0.startMessageId, 1);
        assertEq(round0.endMessageId, 3);
        assertEq(round0.messageCount, 2);

        IGroupChatStructs.RoundSpan memory round1 = chat.roundInfo(chatGroupId, 1);
        assertEq(round1.round, 1);
        assertEq(round1.startMessageId, 3);
        assertEq(round1.endMessageId, 4);
        assertEq(round1.messageCount, 1);
    }

    function testT051T052T053T054T055_roundAndPaginationBoundaries() public {
        _activateEmpty();

        assertEq(chat.messagesByRoundCount(chatGroupId, 99), 0);
        IGroupChatStructs.RoundSpan memory emptyRound = chat.roundInfo(chatGroupId, 99);
        assertEq(emptyRound.round, 99);
        assertEq(emptyRound.startMessageId, 0);
        assertEq(emptyRound.endMessageId, 0);
        assertEq(emptyRound.messageCount, 0);

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "m0");
        vm.prank(other);
        _post(chatGroupId, otherGroupId, "m1");
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "m2");

        vm.roll(originBlocks + phaseBlocks);
        vm.prank(other);
        _post(chatGroupId, otherGroupId, "m3");

        vm.roll(originBlocks + phaseBlocks * 2);
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "m4");

        IGroupChatStructs.Message[] memory messagesForward = chat.messages(chatGroupId, 1, 2, false);
        assertEq(messagesForward.length, 2);
        assertEq(messagesForward[0].messageId, 2);
        assertEq(messagesForward[1].messageId, 3);

        IGroupChatStructs.Message[] memory messagesReverse = chat.messages(chatGroupId, 1, 2, true);
        assertEq(messagesReverse.length, 2);
        assertEq(messagesReverse[0].messageId, 4);
        assertEq(messagesReverse[1].messageId, 3);

        IGroupChatStructs.Message[] memory round0Reverse = chat.messagesByRound(chatGroupId, 0, 1, 2, true);
        assertEq(round0Reverse.length, 2);
        assertEq(round0Reverse[0].messageId, 2);
        assertEq(round0Reverse[1].messageId, 1);

        IGroupChatStructs.RoundSpan[] memory roundsForward = chat.rounds(chatGroupId, 1, 2, false);
        assertEq(roundsForward.length, 2);
        assertEq(roundsForward[0].round, 1);
        assertEq(roundsForward[1].round, 2);

        IGroupChatStructs.RoundSpan[] memory roundsReverse = chat.rounds(chatGroupId, 1, 2, true);
        assertEq(roundsReverse.length, 2);
        assertEq(roundsReverse[0].round, 1);
        assertEq(roundsReverse[1].round, 0);

        assertEq(chat.messages(chatGroupId, 99, 10, false).length, 0);
        assertEq(chat.messagesByRound(chatGroupId, 0, 99, 10, false).length, 0);
        assertEq(chat.rounds(chatGroupId, 99, 10, false).length, 0);
        assertEq(chat.messages(chatGroupId, 0, 0, false).length, 0);
        assertEq(chat.messagesByRound(chatGroupId, 0, 0, 0, false).length, 0);
        assertEq(chat.rounds(chatGroupId, 0, 0, false).length, 0);
    }

    function testT060AndT062_messagesBySenderAndIndexesStayAligned() public {
        _activateEmpty();

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "s-0");
        vm.prank(other);
        _post(chatGroupId, otherGroupId, "o-1");
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "s-2");

        assertEq(chat.messagesBySenderCount(chatGroupId, senderId), 2);

        IGroupChatStructs.Message[] memory senderMessages =
            chat.messagesBySender(chatGroupId, senderId, 0, 10, false);
        assertEq(senderMessages.length, 2);
        assertEq(senderMessages[0].messageId, 1);
        assertEq(senderMessages[1].messageId, 3);

        uint256[] memory indexes = chat.messageIdsBySender(chatGroupId, senderId, 0, 10, false);
        assertEq(indexes.length, 2);
        assertEq(indexes[0], 1);
        assertEq(indexes[1], 3);

        uint256[] memory reverseIndexes = chat.messageIdsBySender(chatGroupId, senderId, 0, 10, true);
        assertEq(reverseIndexes.length, 2);
        assertEq(reverseIndexes[0], 3);
        assertEq(reverseIndexes[1], 1);
    }

    function testT061T064_senderCountMatchesAndNonexistentSenderDoesNotRevert() public {
        _activateEmpty();

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "m0");
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "m1");

        assertEq(chat.messagesBySenderCount(chatGroupId, senderId), 2);
        assertEq(chat.messagesBySender(chatGroupId, senderId, 0, 10, false).length, 2);
        assertEq(chat.messageIdsBySender(chatGroupId, senderId, 0, 10, false).length, 2);

        assertEq(chat.messagesBySenderCount(chatGroupId, 999999), 0);
        assertEq(chat.messagesBySender(chatGroupId, 999999, 0, 10, false).length, 0);
        assertEq(chat.messageIdsBySender(chatGroupId, 999999, 0, 10, false).length, 0);
    }

    function testT063T068_senderEmptyViewsAndPaginationBoundaries() public {
        _activateEmpty();

        assertEq(chat.messagesBySenderCount(chatGroupId, 999), 0);
        assertEq(chat.messagesBySender(chatGroupId, 999, 0, 10, false).length, 0);
        assertEq(chat.messageIdsBySender(chatGroupId, 999, 0, 10, false).length, 0);
        assertEq(chat.senderIdsCount(chatGroupId), 0);
        assertEq(chat.senderIds(chatGroupId, 0, 0, false).length, 0);
        assertEq(chat.senderIds(chatGroupId, 99, 10, false).length, 0);
    }

    function testT065AndT066AndT067_senderIdsKeepFirstAppearanceOrder() public {
        _activateEmpty();

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "s-0");
        vm.prank(other);
        _post(chatGroupId, otherGroupId, "o-1");
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "s-2");

        assertEq(chat.senderIdsCount(chatGroupId), 2);

        uint256[] memory senders = chat.senderIds(chatGroupId, 0, 10, false);
        assertEq(senders.length, 2);
        assertEq(senders[0], senderId);
        assertEq(senders[1], otherGroupId);

        uint256[] memory reverseSenders = chat.senderIds(chatGroupId, 0, 10, true);
        assertEq(reverseSenders.length, 2);
        assertEq(reverseSenders[0], otherGroupId);
        assertEq(reverseSenders[1], senderId);
    }

    function testT083_messageEventActsAsSignalAndBodyComesFromView() public {
        _activateEmpty();

        vm.roll(originBlocks);
        vm.recordLogs();
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "signal");
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], MESSAGE_POST_SIG);
        (uint256 messageRound, uint256 messageId) = _decodeMessagePost(logs[0].data);
        assertEq(messageRound, 0);
        assertEq(messageId, 1);

        IGroupChatStructs.Message memory fetched = chat.message(chatGroupId, messageId);
        assertEq(fetched.content, "signal");
        assertEq(fetched.messageId, messageId);
        assertEq(fetched.round, messageRound);
        assertEq(fetched.senderId, senderId);
        assertEq(fetched.mentions.length, 0);
        assertTrue(!fetched.mentionAll);
        assertEq(fetched.quotedMessageId, 0);
    }

    function testT084_messageViewReadsSingleMessageAndRevertsWhenMissing() public {
        _activateEmpty();

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "single");

        IGroupChatStructs.Message memory fetched = chat.message(chatGroupId, 1);
        assertEq(fetched.chatGroupId, chatGroupId);
        assertEq(fetched.senderId, senderId);
        assertEq(fetched.content, "single");
        assertEq(fetched.messageId, 1);
        assertEq(fetched.quotedMessageId, 0);

        vm.expectRevert(IGroupChatErrors.InvalidMessageId.selector);
        chat.message(chatGroupId, 0);

        vm.expectRevert(IGroupChatErrors.InvalidMessageId.selector);
        chat.message(chatGroupId, 2);
    }

    function testT085_postStoresQuotedMessageIdAndRejectsInvalidQuote() public {
        _activateEmpty();

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "m0");

        vm.prank(senderOwner);
        _post(chatGroupId, senderId, "m1");

        vm.prank(other);
        _postWithQuote(chatGroupId, otherGroupId, "quote-m0", 1);

        IGroupChatStructs.Message memory fetched = chat.message(chatGroupId, 3);
        assertEq(fetched.messageId, 3);
        assertEq(fetched.quotedMessageId, 1);

        vm.prank(other);
        vm.expectRevert(IGroupChatErrors.InvalidQuotedMessageId.selector);
        _postWithQuote(chatGroupId, otherGroupId, "future", 4);
    }

    function testT086_postRejectsTooManyMentions() public {
        _activateEmpty();

        uint256 maxMentions = chat.MAX_MENTIONS();
        uint256[] memory mentions = new uint256[](maxMentions + 1);
        for (uint256 i = 0; i < maxMentions; i++) {
            mentions[i] = senderId;
        }
        mentions[maxMentions] = otherGroupId;

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        vm.expectRevert(abi.encodeWithSelector(IGroupChatErrors.TooManyMentions.selector, maxMentions + 1, maxMentions));
        _postWithMentions(chatGroupId, senderId, "too-many", mentions, false);
    }
}
