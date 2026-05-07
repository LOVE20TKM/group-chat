// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChatErrors} from "../src/interfaces/IGroupChat.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";

contract GroupChatDelegateTest is GroupChatFixture {
    function testT030AndT034AndT035_delegateIdInvalidatesAndRestoresAcrossTransfer() public {
        _activateEmpty();

        vm.prank(chatOwner);
        chat.setDelegateId(chatGroupId, delegateId);
        assertEq(chat.delegateIdOf(chatGroupId), delegateId);
        assertEq(chat.chatInfo(chatGroupId).configVersion, 2);

        groupNft.transferFrom(chatOwner, other, chatGroupId);
        assertEq(chat.delegateIdOf(chatGroupId), 0);
        assertEq(chat.chatInfo(chatGroupId).owner, other);
        assertEq(chat.chatInfo(chatGroupId).configVersion, 2);

        groupNft.transferFrom(other, chatOwner, chatGroupId);
        assertEq(chat.delegateIdOf(chatGroupId), delegateId);
    }

    function testT031T032T033T036_delegateIdEdgeCases() public {
        _activateEmpty();

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.DelegateIdCannotBeChatGroupId.selector);
        chat.setDelegateId(chatGroupId, chatGroupId);

        vm.prank(chatOwner);
        chat.setDelegateId(chatGroupId, delegateId);

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.DelegateIdUnchanged.selector);
        chat.setDelegateId(chatGroupId, delegateId);

        vm.prank(chatOwner);
        chat.setDelegateId(chatGroupId, 0);
        assertEq(chat.delegateIdOf(chatGroupId), 0);

        groupNft.transferFrom(chatOwner, other, chatGroupId);
        groupNft.transferFrom(other, chatOwner, chatGroupId);
        assertEq(chat.delegateIdOf(chatGroupId), 0);

        vm.prank(chatOwner);
        chat.setDelegateId(chatGroupId, delegateId);
        groupNft.transferFrom(chatOwner, other, chatGroupId);

        vm.prank(delegateIdOwner);
        vm.expectRevert(IGroupChatErrors.NotChatOwnerOrDelegateIdOwner.selector);
        chat.setMeta(chatGroupId, "k", bytes("v"));

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.NotChatOwner.selector);
        chat.setDelegateId(chatGroupId, 0);
    }
}
