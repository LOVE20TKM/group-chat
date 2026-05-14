// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChatErrors} from "../src/interfaces/IGroupChat.sol";
import {AdminDenySource} from "../src/sources/deny/AdminDenySource.sol";
import {GroupJoinScopeSource} from "../src/sources/scope/GroupJoinScopeSource.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";

contract MockGroupJoin {
    mapping(uint256 => mapping(address => uint256)) public counts;

    function setTokenAddressCount(uint256 groupId, address account, uint256 count) external {
        counts[groupId][account] = count;
    }

    function gTokenAddressesByGroupIdByAccountCount(uint256 groupId, address account) external view returns (uint256) {
        return counts[groupId][account];
    }
}

contract GroupJoinScopeSourceTest is GroupChatFixture {
    MockGroupJoin internal groupJoin;
    GroupJoinScopeSource internal scope;

    function setUp() public override {
        super.setUp();
        groupJoin = new MockGroupJoin();
        scope = new GroupJoinScopeSource(address(groupJoin));
    }

    function testT130_constructorRequiresGroupJoinCode() public {
        vm.expectRevert(GroupJoinScopeSource.GroupJoinScopeSourceAddressHasNoCode.selector);
        new GroupJoinScopeSource(address(0x1234));
    }

    function testT131_groupJoinMembershipControlsPost() public {
        (string[] memory keys, bytes[] memory values) = _emptyMeta();
        vm.prank(chatOwner);
        chat.activateChat(groupId, keys, values, address(scope), address(0), address(0), address(0), 0);

        (bool allowed, bytes4 reasonCode) = _canPost(groupId, senderId, senderOwner);
        assertTrue(!allowed);
        assertEq(reasonCode, IGroupChatErrors.ScopeRejected.selector);

        groupJoin.setTokenAddressCount(groupId, senderOwner, 1);

        (allowed, reasonCode) = _canPost(groupId, senderId, senderOwner);
        assertTrue(allowed);
        assertEq(reasonCode, bytes4(0));

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(groupId, senderId, "joined-group");
        assertEq(chat.messagesCount(groupId), 1);

        groupJoin.setTokenAddressCount(groupId, senderOwner, 0);

        vm.prank(senderOwner);
        vm.expectRevert(IGroupChatErrors.ScopeRejected.selector);
        _post(groupId, senderId, "exited-group");
    }

    function testT132_groupJoinScopeCombinesWithAdminDenySource() public {
        AdminDenySource deny = new AdminDenySource(address(chat), 20);
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        chat.activateChat(groupId, keys, values, address(scope), address(deny), address(0), address(0), 0);

        groupJoin.setTokenAddressCount(groupId, senderOwner, 1);

        vm.prank(chatOwner);
        deny.setAdmins(groupId, _uints(groupId));

        vm.prank(chatOwner);
        groupDefaults.setDefaultGroupId(groupId);

        vm.prank(chatOwner);
        deny.denyBySenderIds(groupId, _uints(senderId));

        (bool allowed, bytes4 reasonCode) = _canPost(groupId, senderId, senderOwner);
        assertTrue(!allowed);
        assertEq(reasonCode, IGroupChatErrors.DenyRejected.selector);

        vm.prank(chatOwner);
        deny.exemptSenderIds(groupId, _uints(senderId));

        assertTrue(_canPostAllowed(groupId, senderId, senderOwner));
    }

    function _uints(uint256 value) internal pure returns (uint256[] memory values) {
        values = new uint256[](1);
        values[0] = value;
    }
}
