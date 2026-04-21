// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {GroupChat} from "../src/GroupChat.sol";
import {
    IGroupChatErrors,
    IGroupChatStructs
} from "../src/interfaces/IGroupChat.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";
import {Vm} from "./utils/TestBase.sol";

contract GroupChatMessagesTest is GroupChatFixture {
    function testT040_post_ownerCanPostWithOwnedSenderGroup() public {
        _activateEmpty();

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderGroupId, "hello");

        assertEq(chat.messagesCount(chatGroupId), 1);

        IGroupChatStructs.Message[] memory result = chat.messages(chatGroupId, 0, 1, false);
        assertEq(result.length, 1);
        assertEq(result[0].chatGroupId, chatGroupId);
        assertEq(result[0].senderGroupId, senderGroupId);
        assertEq(result[0].senderAddress, senderOwner);
        assertEq(result[0].round, 0);
        assertEq(result[0].messageIndex, 0);
        assertEq(result[0].content, "hello");
        assertEq(result[0].blockNumber, originBlocks);
        assertEq(result[0].timestamp, block.timestamp);
        assertEq(result[0].mentions.length, 0);
        assertTrue(!result[0].mentionAll);
    }

    function testT041_crossGroupPostWithoutPluginIsAllowedByDefault() public {
        _activateEmpty();

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderGroupId, "cross-group");

        IGroupChatStructs.Message[] memory result = chat.messages(chatGroupId, 0, 1, false);
        assertEq(result.length, 1);
        assertEq(result[0].chatGroupId, chatGroupId);
        assertEq(result[0].senderGroupId, senderGroupId);
        assertTrue(chatGroupId != senderGroupId);
    }

    function testT042_post_revertsForNonSenderOwner() public {
        _activateEmpty();

        vm.roll(originBlocks);
        vm.prank(other);
        vm.expectRevert(IGroupChatErrors.SenderNotGroupOwner.selector);
        _post(chatGroupId, senderGroupId, "hello");
    }

    function testT043T044T045T046T047_postInvalidCases() public {
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(0), address(0), delegateGroupId);

        vm.roll(originBlocks);
        vm.prank(delegateGroupOwner);
        vm.expectRevert(IGroupChatErrors.SenderNotGroupOwner.selector);
        _post(chatGroupId, senderGroupId, "delegate-send");

        vm.prank(chatOwner);
        chat.deactivateChat(chatGroupId);

        vm.prank(senderOwner);
        vm.expectRevert(IGroupChatErrors.ChatNotActive.selector);
        _post(chatGroupId, senderGroupId, "closed");

        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(0), address(0), delegateGroupId);

        vm.prank(senderOwner);
        vm.expectRevert(IGroupChatErrors.ContentEmpty.selector);
        _post(chatGroupId, senderGroupId, "");

        bytes memory tooLongBytes = new bytes(chat.MAX_CONTENT_LENGTH() + 1);
        string memory tooLong = string(tooLongBytes);
        vm.prank(senderOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IGroupChatErrors.ContentTooLong.selector,
                chat.MAX_CONTENT_LENGTH() + 1,
                chat.MAX_CONTENT_LENGTH()
            )
        );
        _post(chatGroupId, senderGroupId, tooLong);

        GroupChat futureChat =
            new GroupChat(address(groupNft), block.number + 1000, phaseBlocks);
        vm.prank(chatOwner);
        futureChat.activateChat(chatGroupId, keys, values, address(0), address(0), 0);

        vm.prank(senderOwner);
        vm.expectRevert(IGroupChatErrors.RoundNotStarted.selector);
        futureChat.post(chatGroupId, senderGroupId, "early", _emptyMentions(), false);
    }

    function testT048_postStoresMentionsAndMentionIndexes() public {
        _activateEmpty();

        uint256[] memory mentions = new uint256[](2);
        mentions[0] = otherGroupId;
        mentions[1] = delegateGroupId;

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _postWithMentions(chatGroupId, senderGroupId, "hello @two", mentions, false);

        IGroupChatStructs.Message[] memory result = chat.messages(chatGroupId, 0, 1, false);
        assertEq(result.length, 1);
        assertEq(result[0].mentions.length, 2);
        assertEq(result[0].mentions[0], otherGroupId);
        assertEq(result[0].mentions[1], delegateGroupId);
        assertTrue(!result[0].mentionAll);

        assertEq(chat.messagesByMentionCount(chatGroupId, otherGroupId), 1);
        assertEq(chat.messagesByMentionCount(chatGroupId, delegateGroupId), 1);
        assertEq(chat.messagesByMentionCount(chatGroupId, 999999), 0);

        IGroupChatStructs.Message[] memory byMention =
            chat.messagesByMention(chatGroupId, delegateGroupId, 0, 10, false);
        assertEq(byMention.length, 1);
        assertEq(byMention[0].messageIndex, 0);
        assertEq(byMention[0].mentions.length, 2);

        uint256[] memory indexes =
            chat.messageIndexesByMention(chatGroupId, otherGroupId, 0, 10, false);
        assertEq(indexes.length, 1);
        assertEq(indexes[0], 0);
        assertEq(chat.messagesByMention(chatGroupId, 999999, 0, 10, false).length, 0);
        assertEq(chat.messageIndexesByMention(chatGroupId, 999999, 0, 10, false).length, 0);
    }

    function testT049_postRejectsDuplicateMentionsAndIndexesMentionAll() public {
        (string[] memory keys, bytes[] memory values) = _emptyMeta();
        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(0), address(0), delegateGroupId);

        uint256[] memory duplicateMentions = new uint256[](2);
        duplicateMentions[0] = otherGroupId;
        duplicateMentions[1] = otherGroupId;

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        vm.expectRevert(IGroupChatErrors.DuplicateMentionGroupId.selector);
        _postWithMentions(
            chatGroupId,
            senderGroupId,
            "dup",
            duplicateMentions,
            false
        );

        vm.prank(senderOwner);
        _postWithMentions(chatGroupId, senderGroupId, "@all-0", _emptyMentions(), true);

        vm.prank(other);
        _post(chatGroupId, otherGroupId, "plain");

        vm.prank(senderOwner);
        _postWithMentions(
            chatGroupId,
            senderGroupId,
            "@all-1",
            _emptyMentions(),
            true
        );

        IGroupChatStructs.Message[] memory result = chat.messages(chatGroupId, 0, 10, false);
        assertEq(result.length, 3);
        assertTrue(result[0].mentionAll);
        assertTrue(!result[1].mentionAll);
        assertTrue(result[2].mentionAll);

        assertEq(chat.messagesByMentionAllCount(chatGroupId), 2);

        IGroupChatStructs.Message[] memory byMentionAll =
            chat.messagesByMentionAll(chatGroupId, 0, 10, false);
        assertEq(byMentionAll.length, 2);
        assertEq(byMentionAll[0].messageIndex, 0);
        assertEq(byMentionAll[1].messageIndex, 2);

        IGroupChatStructs.Message[] memory byMentionAllReverse =
            chat.messagesByMentionAll(chatGroupId, 0, 1, true);
        assertEq(byMentionAllReverse.length, 1);
        assertEq(byMentionAllReverse[0].messageIndex, 2);

        uint256[] memory indexes = chat.messageIndexesByMentionAll(
            chatGroupId,
            0,
            10,
            false
        );
        assertEq(indexes.length, 2);
        assertEq(indexes[0], 0);
        assertEq(indexes[1], 2);

        uint256[] memory reverseIndexes = chat.messageIndexesByMentionAll(
            chatGroupId,
            1,
            1,
            true
        );
        assertEq(reverseIndexes.length, 1);
        assertEq(reverseIndexes[0], 0);
    }

    function testT050_roundInfoAcrossRounds() public {
        _activateEmpty();

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderGroupId, "r0-0");
        vm.prank(other);
        _post(chatGroupId, otherGroupId, "r0-1");

        vm.roll(originBlocks + phaseBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderGroupId, "r1-0");

        assertEq(chat.roundsCount(chatGroupId), 2);

        IGroupChatStructs.RoundSpan memory round0 = chat.roundInfo(chatGroupId, 0);
        assertEq(round0.round, 0);
        assertEq(round0.startIndex, 0);
        assertEq(round0.endIndex, 2);
        assertEq(round0.messageCount, 2);

        IGroupChatStructs.RoundSpan memory round1 = chat.roundInfo(chatGroupId, 1);
        assertEq(round1.round, 1);
        assertEq(round1.startIndex, 2);
        assertEq(round1.endIndex, 3);
        assertEq(round1.messageCount, 1);
    }

    function testT051T052T053T054T055_roundAndPaginationBoundaries() public {
        _activateEmpty();

        assertEq(chat.messagesByRoundCount(chatGroupId, 99), 0);
        IGroupChatStructs.RoundSpan memory emptyRound = chat.roundInfo(chatGroupId, 99);
        assertEq(emptyRound.round, 99);
        assertEq(emptyRound.startIndex, 0);
        assertEq(emptyRound.endIndex, 0);
        assertEq(emptyRound.messageCount, 0);

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderGroupId, "m0");
        vm.prank(other);
        _post(chatGroupId, otherGroupId, "m1");
        vm.prank(senderOwner);
        _post(chatGroupId, senderGroupId, "m2");

        vm.roll(originBlocks + phaseBlocks);
        vm.prank(other);
        _post(chatGroupId, otherGroupId, "m3");

        vm.roll(originBlocks + phaseBlocks * 2);
        vm.prank(senderOwner);
        _post(chatGroupId, senderGroupId, "m4");

        IGroupChatStructs.Message[] memory messagesForward = chat.messages(
            chatGroupId,
            1,
            2,
            false
        );
        assertEq(messagesForward.length, 2);
        assertEq(messagesForward[0].messageIndex, 1);
        assertEq(messagesForward[1].messageIndex, 2);

        IGroupChatStructs.Message[] memory messagesReverse = chat.messages(
            chatGroupId,
            1,
            2,
            true
        );
        assertEq(messagesReverse.length, 2);
        assertEq(messagesReverse[0].messageIndex, 3);
        assertEq(messagesReverse[1].messageIndex, 2);

        IGroupChatStructs.Message[] memory round0Reverse = chat.messagesByRound(
            chatGroupId,
            0,
            1,
            2,
            true
        );
        assertEq(round0Reverse.length, 2);
        assertEq(round0Reverse[0].messageIndex, 1);
        assertEq(round0Reverse[1].messageIndex, 0);

        IGroupChatStructs.RoundSpan[] memory roundsForward = chat.rounds(
            chatGroupId,
            1,
            2,
            false
        );
        assertEq(roundsForward.length, 2);
        assertEq(roundsForward[0].round, 1);
        assertEq(roundsForward[1].round, 2);

        IGroupChatStructs.RoundSpan[] memory roundsReverse = chat.rounds(
            chatGroupId,
            1,
            2,
            true
        );
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
        _post(chatGroupId, senderGroupId, "s-0");
        vm.prank(other);
        _post(chatGroupId, otherGroupId, "o-1");
        vm.prank(senderOwner);
        _post(chatGroupId, senderGroupId, "s-2");

        assertEq(chat.messagesBySenderCount(chatGroupId, senderGroupId), 2);

        IGroupChatStructs.Message[] memory senderMessages =
            chat.messagesBySender(chatGroupId, senderGroupId, 0, 10, false);
        assertEq(senderMessages.length, 2);
        assertEq(senderMessages[0].messageIndex, 0);
        assertEq(senderMessages[1].messageIndex, 2);

        uint256[] memory indexes =
            chat.messageIndexesBySender(chatGroupId, senderGroupId, 0, 10, false);
        assertEq(indexes.length, 2);
        assertEq(indexes[0], 0);
        assertEq(indexes[1], 2);

        uint256[] memory reverseIndexes =
            chat.messageIndexesBySender(chatGroupId, senderGroupId, 0, 10, true);
        assertEq(reverseIndexes.length, 2);
        assertEq(reverseIndexes[0], 2);
        assertEq(reverseIndexes[1], 0);
    }

    function testT061T064_senderCountMatchesAndNonexistentSenderDoesNotRevert() public {
        _activateEmpty();

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderGroupId, "m0");
        vm.prank(senderOwner);
        _post(chatGroupId, senderGroupId, "m1");

        assertEq(chat.messagesBySenderCount(chatGroupId, senderGroupId), 2);
        assertEq(chat.messagesBySender(chatGroupId, senderGroupId, 0, 10, false).length, 2);
        assertEq(chat.messageIndexesBySender(chatGroupId, senderGroupId, 0, 10, false).length, 2);

        assertEq(chat.messagesBySenderCount(chatGroupId, 999999), 0);
        assertEq(chat.messagesBySender(chatGroupId, 999999, 0, 10, false).length, 0);
        assertEq(chat.messageIndexesBySender(chatGroupId, 999999, 0, 10, false).length, 0);
    }

    function testT063T068_senderEmptyViewsAndPaginationBoundaries() public {
        _activateEmpty();

        assertEq(chat.messagesBySenderCount(chatGroupId, 999), 0);
        assertEq(chat.messagesBySender(chatGroupId, 999, 0, 10, false).length, 0);
        assertEq(chat.messageIndexesBySender(chatGroupId, 999, 0, 10, false).length, 0);
        assertEq(chat.senderGroupIdsCount(chatGroupId), 0);
        assertEq(chat.senderGroupIds(chatGroupId, 0, 0, false).length, 0);
        assertEq(chat.senderGroupIds(chatGroupId, 99, 10, false).length, 0);
    }

    function testT065AndT066AndT067_senderGroupIdsKeepFirstAppearanceOrder() public {
        _activateEmpty();

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderGroupId, "s-0");
        vm.prank(other);
        _post(chatGroupId, otherGroupId, "o-1");
        vm.prank(senderOwner);
        _post(chatGroupId, senderGroupId, "s-2");

        assertEq(chat.senderGroupIdsCount(chatGroupId), 2);

        uint256[] memory senders = chat.senderGroupIds(chatGroupId, 0, 10, false);
        assertEq(senders.length, 2);
        assertEq(senders[0], senderGroupId);
        assertEq(senders[1], otherGroupId);

        uint256[] memory reverseSenders = chat.senderGroupIds(chatGroupId, 0, 10, true);
        assertEq(reverseSenders.length, 2);
        assertEq(reverseSenders[0], otherGroupId);
        assertEq(reverseSenders[1], senderGroupId);
    }

    function testT083_messageEventActsAsSignalAndBodyComesFromView() public {
        _activateEmpty();

        vm.roll(originBlocks);
        vm.recordLogs();
        vm.prank(senderOwner);
        _post(chatGroupId, senderGroupId, "signal");
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], MESSAGE_POST_SIG);
        (uint256 messageVersion, uint256 messageRound, uint256 messageIndex) =
            _decodeMessagePost(logs[0].data);
        assertEq(messageVersion, chat.chatInfo(chatGroupId).configVersion);
        assertEq(messageRound, 0);
        assertEq(messageIndex, 0);

        IGroupChatStructs.Message[] memory fetched = chat.messages(
            chatGroupId,
            messageIndex,
            1,
            false
        );
        assertEq(fetched.length, 1);
        assertEq(fetched[0].content, "signal");
        assertEq(fetched[0].messageIndex, messageIndex);
        assertEq(fetched[0].round, messageRound);
        assertEq(fetched[0].senderGroupId, senderGroupId);
        assertEq(fetched[0].mentions.length, 0);
        assertTrue(!fetched[0].mentionAll);
    }
}
