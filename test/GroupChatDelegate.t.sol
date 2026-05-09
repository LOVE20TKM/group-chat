// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChatErrors} from "../src/interfaces/IGroupChat.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";

contract GroupChatDelegateTest is GroupChatFixture {
    function testT030AndT034AndT035_delegateIdInvalidatesAndRestoresAcrossTransfer() public {
        _activateEmpty();

        vm.prank(chatOwner);
        chat.setDelegateId(groupId, delegateId);
        assertEq(chat.delegateIdOf(groupId), delegateId);
        assertEq(chat.chatInfo(groupId).delegateId, delegateId);
        assertEq(chat.chatInfo(groupId).configVersion, 2);

        groupNft.transferFrom(chatOwner, other, groupId);
        assertEq(chat.delegateIdOf(groupId), 0);
        assertEq(chat.chatInfo(groupId).delegateId, 0);
        assertEq(chat.chatInfo(groupId).owner, other);
        assertEq(chat.chatInfo(groupId).configVersion, 2);

        groupNft.transferFrom(other, chatOwner, groupId);
        assertEq(chat.delegateIdOf(groupId), delegateId);
        assertEq(chat.chatInfo(groupId).delegateId, delegateId);
    }

    function testT031T032T033T036_delegateIdEdgeCases() public {
        _activateEmpty();

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.DelegateIdCannotBeGroupId.selector);
        chat.setDelegateId(groupId, groupId);

        vm.prank(chatOwner);
        chat.setDelegateId(groupId, delegateId);

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.DelegateIdUnchanged.selector);
        chat.setDelegateId(groupId, delegateId);

        vm.prank(chatOwner);
        chat.setDelegateId(groupId, 0);
        assertEq(chat.delegateIdOf(groupId), 0);
        assertEq(chat.chatInfo(groupId).delegateId, 0);

        groupNft.transferFrom(chatOwner, other, groupId);
        groupNft.transferFrom(other, chatOwner, groupId);
        assertEq(chat.delegateIdOf(groupId), 0);

        vm.prank(chatOwner);
        chat.setDelegateId(groupId, delegateId);
        groupNft.transferFrom(chatOwner, other, groupId);

        vm.prank(delegateIdOwner);
        vm.expectRevert(IGroupChatErrors.NotChatOwnerOrDelegateIdOwner.selector);
        chat.setMeta(groupId, "k", bytes("v"));

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.NotChatOwner.selector);
        chat.setDelegateId(groupId, 0);
    }
}
