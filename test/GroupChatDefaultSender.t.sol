// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChatErrors, IGroupChatStructs} from "../src/interfaces/IGroupChat.sol";
import {IGroupDefaultsErrors} from "../src/interfaces/external/IGroupDefaults.sol";
import {MockGroupDefaults} from "./mocks/MockGroupDefaults.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";
import {Vm} from "./utils/TestBase.sol";

contract GroupChatDefaultSenderTest is GroupChatFixture {
    function testT087_setDefaultSenderAndPostByDefaultSender() public {
        _activateEmpty();

        vm.recordLogs();
        vm.prank(senderOwner);
        groupDefaults.setDefaultGroupId(senderGroupId);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], DEFAULT_GROUP_ID_SET_SIG);
        assertEq(groupDefaults.defaultGroupIdOf(senderOwner), senderGroupId);

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _postByDefaultSender(chatGroupId, "default-post");

        IGroupChatStructs.Message memory fetched = chat.message(chatGroupId, 0);
        assertEq(fetched.senderGroupId, senderGroupId);
        assertEq(fetched.senderAddress, senderOwner);
        assertEq(fetched.content, "default-post");
    }

    function testT088_defaultSenderInvalidatesOnTransferAndAutoRestores() public {
        vm.prank(senderOwner);
        groupDefaults.setDefaultGroupId(senderGroupId);
        assertEq(groupDefaults.defaultGroupIdOf(senderOwner), senderGroupId);

        vm.prank(senderOwner);
        groupNft.transferFrom(senderOwner, other, senderGroupId);
        assertEq(groupDefaults.defaultGroupIdOf(senderOwner), 0);

        _activateEmpty();
        vm.roll(originBlocks);
        vm.prank(senderOwner);
        vm.expectRevert(IGroupChatErrors.DefaultGroupIdNotSet.selector);
        _postByDefaultSender(chatGroupId, "stale");

        vm.prank(other);
        groupNft.transferFrom(other, senderOwner, senderGroupId);
        assertEq(groupDefaults.defaultGroupIdOf(senderOwner), senderGroupId);
    }

    function testT089_clearDefaultSenderUsesStoredValueEvenWhenInvalid() public {
        vm.prank(senderOwner);
        groupDefaults.setDefaultGroupId(senderGroupId);

        vm.prank(senderOwner);
        groupNft.transferFrom(senderOwner, other, senderGroupId);
        assertEq(groupDefaults.defaultGroupIdOf(senderOwner), 0);

        vm.recordLogs();
        vm.prank(senderOwner);
        groupDefaults.clearDefaultGroupId();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], DEFAULT_GROUP_ID_CLEARED_SIG);
        assertEq(groupDefaults.defaultGroupIdOf(senderOwner), 0);

        vm.prank(other);
        groupNft.transferFrom(other, senderOwner, senderGroupId);
        assertEq(groupDefaults.defaultGroupIdOf(senderOwner), 0);
    }

    function testT090_defaultSenderSetAndClearRejectNoOpStates() public {
        vm.prank(senderOwner);
        vm.expectRevert(IGroupDefaultsErrors.DefaultGroupIdNotSet.selector);
        groupDefaults.clearDefaultGroupId();

        vm.prank(senderOwner);
        groupDefaults.setDefaultGroupId(senderGroupId);

        vm.prank(senderOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IGroupDefaultsErrors.DefaultGroupIdAlreadySet.selector,
                senderGroupId
            )
        );
        groupDefaults.setDefaultGroupId(senderGroupId);
    }
}
