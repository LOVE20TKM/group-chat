// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChat, IGroupChatErrors} from "../src/interfaces/IGroupChat.sol";
import {IERC721Receiver} from "../src/interfaces/external/IERC721Receiver.sol";
import {BaseManager} from "../src/managers/BaseManager.sol";

import {MockERC20Payment} from "./mocks/MockLOVE20Group.sol";
import {MockManager} from "./mocks/MockManagers.sol";
import {MockBeforePostRejectPlugin, MockPostDenySource} from "./mocks/MockPlugins.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";

contract ManagerTest is GroupChatFixture {
    function testT100_managerActivatesChatWithImmutableConfigAndNoDelegate() public {
        MockPostDenySource deny = new MockPostDenySource();
        MockBeforePostRejectPlugin beforePlugin = new MockBeforePostRejectPlugin();
        MockManager manager = new MockManager(address(chat), address(deny), address(beforePlugin), address(0));

        groupId = manager.activateMockManagedGroup();
        assertEq(chat.chatInfo(groupId).owner, address(manager));

        assertTrue(chat.chatInfo(groupId).activated);
        assertTrue(chat.chatInfo(groupId).postingAllowed);
        assertEq(chat.delegateIdOf(groupId), 0);
        IGroupChat.ChatInfo memory info = chat.chatInfo(groupId);
        assertEq(info.delegateId, 0);
        assertEq(info.scopeSource, address(manager));
        assertEq(info.denySource, address(deny));
        assertEq(info.beforePostPlugin, address(beforePlugin));
        assertEq(info.afterPostPlugin, address(0));

        assertTrue(manager.canPost(groupId, senderId, senderOwner));
        assertEq(manager.voteWeightOf(groupId, senderOwner), 1);
    }

    function testT101_managerOwnerCannotStopPostingThroughGroupChat() public {
        MockManager manager = new MockManager(address(chat), address(0), address(0), address(0));

        groupId = manager.activateMockManagedGroup();

        vm.prank(chatOwner);
        vm.expectRevert(IGroupChatErrors.NotChatOwnerOrDelegateIdOwner.selector);
        chat.setPostingAllowed(groupId, false);
    }

    function testT102_managerDoesNotExposeReconfigureEntrypoints() public {
        MockManager manager = new MockManager(address(chat), address(0), address(0), address(0));

        _expectUnknownSelector(
            address(manager), abi.encodeWithSignature("setPostingAllowed(uint256,bool)", groupId, false)
        );
        _expectUnknownSelector(
            address(manager), abi.encodeWithSignature("setScopeSource(uint256,address)", groupId, other)
        );
        _expectUnknownSelector(
            address(manager), abi.encodeWithSignature("setDenySource(uint256,address)", groupId, other)
        );
        _expectUnknownSelector(
            address(manager), abi.encodeWithSignature("setBeforePostPlugin(uint256,address)", groupId, other)
        );
        _expectUnknownSelector(
            address(manager), abi.encodeWithSignature("setAfterPostPlugin(uint256,address)", groupId, other)
        );
        _expectUnknownSelector(address(manager), abi.encodeWithSignature("setDelegateId(uint256,uint256)", groupId, 0));
    }

    function testT103_managerDoesNotExposeGenericCallEntrypoints() public {
        MockManager manager = new MockManager(address(chat), address(0), address(0), address(0));

        _expectUnknownSelector(address(manager), abi.encodeWithSignature("call(address,bytes)", other, ""));
        _expectUnknownSelector(address(manager), abi.encodeWithSignature("delegatecall(address,bytes)", other, ""));
        _expectUnknownSelector(
            address(manager), abi.encodeWithSignature("execute(address,uint256,bytes)", other, 0, "")
        );
    }

    function testT104_managerConstructorRejectsNoCodeAddressesAndReceivesErc721() public {
        vm.expectRevert(BaseManager.ManagerAddressHasNoCode.selector);
        new MockManager(other, address(0), address(0), address(0));

        vm.expectRevert(BaseManager.ManagerAddressHasNoCode.selector);
        new MockManager(address(chat), other, address(0), address(0));

        MockManager manager = new MockManager(address(chat), address(0), address(0), address(0));
        bytes4 received = manager.onERC721Received(chatOwner, chatOwner, groupId, "");
        assertEq(received, IERC721Receiver.onERC721Received.selector);
    }

    function testT105_managerPullsMintCostAndPaysGroupNft() public {
        MockERC20Payment token = new MockERC20Payment();
        groupNft.setMintPayment(address(token), 10);
        token.mint(address(this), 10);

        MockManager manager = new MockManager(address(chat), address(0), address(0), address(0));
        token.approve(address(manager), 10);

        groupId = manager.activateMockManagedGroup();

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(manager)), 0);
        assertEq(token.balanceOf(address(groupNft)), 10);
        assertEq(chat.chatInfo(groupId).owner, address(manager));
    }

    function _expectUnknownSelector(address target, bytes memory data) internal {
        (bool ok,) = target.call(data);
        assertTrue(!ok);
    }
}
