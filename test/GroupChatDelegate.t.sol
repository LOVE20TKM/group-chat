// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChatErrors} from "../src/interfaces/IGroupChat.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";

contract GroupChatDelegateTest is GroupChatFixture {
    function testT030AndT034AndT035_delegateGroupIdInvalidatesAndRestoresAcrossTransfer() public {
        _activateEmpty();

        vm.prank(chatOwner);
        chat.setDelegateGroupId(chatGroupId, delegateGroupId);
        assertEq(chat.delegateGroupIdOf(chatGroupId), delegateGroupId);
        assertEq(chat.chatInfo(chatGroupId).configVersion, 2);

        groupNft.transferFrom(chatOwner, other, chatGroupId);
        assertEq(chat.delegateGroupIdOf(chatGroupId), 0);
        assertEq(chat.chatInfo(chatGroupId).owner, other);
        assertEq(chat.chatInfo(chatGroupId).configVersion, 2);

        groupNft.transferFrom(other, chatOwner, chatGroupId);
        assertEq(chat.delegateGroupIdOf(chatGroupId), delegateGroupId);
    }

    function testT031T032T033T036_delegateGroupIdEdgeCases() public {
        _activateEmpty();

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.DelegateGroupIdCannotBeChatGroupId.selector);
        chat.setDelegateGroupId(chatGroupId, chatGroupId);

        vm.prank(chatOwner);
        chat.setDelegateGroupId(chatGroupId, delegateGroupId);

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.DelegateGroupIdUnchanged.selector);
        chat.setDelegateGroupId(chatGroupId, delegateGroupId);

        vm.prank(chatOwner);
        chat.setDelegateGroupId(chatGroupId, 0);
        assertEq(chat.delegateGroupIdOf(chatGroupId), 0);

        groupNft.transferFrom(chatOwner, other, chatGroupId);
        groupNft.transferFrom(other, chatOwner, chatGroupId);
        assertEq(chat.delegateGroupIdOf(chatGroupId), 0);

        vm.prank(chatOwner);
        chat.setDelegateGroupId(chatGroupId, delegateGroupId);
        groupNft.transferFrom(chatOwner, other, chatGroupId);

        vm.prank(delegateGroupOwner);
        vm.expectRevert(IGroupChatErrors.NotChatOwnerOrDelegateGroupOwner.selector);
        chat.setMeta(chatGroupId, "k", bytes("v"));

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.NotChatOwner.selector);
        chat.setDelegateGroupId(chatGroupId, 0);
    }
}
