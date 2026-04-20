// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChatErrors} from "../src/interfaces/IGroupChat.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";

contract GroupChatDelegateTest is GroupChatFixture {
    function testT030AndT034AndT035_delegateInvalidatesAndRestoresAcrossTransfer() public {
        _activateEmpty();

        vm.prank(chatOwner);
        chat.setDelegate(chatGroupId, delegate);
        assertEq(chat.delegateOf(chatGroupId), delegate);
        assertEq(chat.chatInfo(chatGroupId).configVersion, 2);

        groupNft.transferFrom(chatOwner, other, chatGroupId);
        assertEq(chat.delegateOf(chatGroupId), address(0));
        assertEq(chat.chatInfo(chatGroupId).owner, other);
        assertEq(chat.chatInfo(chatGroupId).configVersion, 2);

        groupNft.transferFrom(other, chatOwner, chatGroupId);
        assertEq(chat.delegateOf(chatGroupId), delegate);
    }

    function testT031T032T033T036_delegateEdgeCases() public {
        _activateEmpty();

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.DelegateCannotBeOwner.selector);
        chat.setDelegate(chatGroupId, chatOwner);

        vm.prank(chatOwner);
        chat.setDelegate(chatGroupId, delegate);

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.DelegateUnchanged.selector);
        chat.setDelegate(chatGroupId, delegate);

        vm.prank(chatOwner);
        chat.setDelegate(chatGroupId, address(0));
        assertEq(chat.delegateOf(chatGroupId), address(0));

        groupNft.transferFrom(chatOwner, other, chatGroupId);
        groupNft.transferFrom(other, chatOwner, chatGroupId);
        assertEq(chat.delegateOf(chatGroupId), address(0));

        vm.prank(chatOwner);
        chat.setDelegate(chatGroupId, delegate);
        groupNft.transferFrom(chatOwner, other, chatGroupId);

        vm.prank(delegate);
        vm.expectRevert(IGroupChatErrors.NotChatOwnerOrDelegate.selector);
        chat.setMeta(chatGroupId, "k", bytes("v"));

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.NotChatOwner.selector);
        chat.setDelegate(chatGroupId, address(0));
    }
}
