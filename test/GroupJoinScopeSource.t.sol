// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChatErrors} from "../src/interfaces/IGroupChat.sol";
import {AdminDenySource} from "../src/sources/deny/AdminDenySource.sol";
import {GroupJoinScopeSource} from "../src/sources/scope/GroupJoinScopeSource.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";

contract MockGroupJoinGlobal {
    mapping(uint256 => mapping(address => uint256)) public counts;

    function setTokenAddressCount(uint256 groupId, address account, uint256 count) external {
        counts[groupId][account] = count;
    }

    function gTokenAddressesByGroupIdByAccountCount(uint256 groupId, address account) external view returns (uint256) {
        return counts[groupId][account];
    }
}

contract GroupJoinScopeSourceTest is GroupChatFixture {
    MockGroupJoinGlobal internal groupJoin;
    GroupJoinScopeSource internal scope;

    function setUp() public override {
        super.setUp();
        groupJoin = new MockGroupJoinGlobal();
        scope = new GroupJoinScopeSource(address(groupJoin));
    }

    function testT130_constructorRequiresGroupJoinCode() public {
        vm.expectRevert(GroupJoinScopeSource.GroupJoinScopeSourceAddressHasNoCode.selector);
        new GroupJoinScopeSource(address(0x1234));
    }

    function testT131_groupJoinGlobalMembershipControlsPost() public {
        (string[] memory keys, bytes[] memory values) = _emptyMeta();
        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(scope), address(0), address(0), address(0), 0);

        (bool allowed, bytes4 reasonCode) = chat.canPostStatus(chatGroupId, senderGroupId, senderOwner);
        assertTrue(!allowed);
        assertEq(reasonCode, IGroupChatErrors.ScopeRejected.selector);

        groupJoin.setTokenAddressCount(chatGroupId, senderOwner, 1);

        (allowed, reasonCode) = chat.canPostStatus(chatGroupId, senderGroupId, senderOwner);
        assertTrue(allowed);
        assertEq(reasonCode, bytes4(0));

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        _post(chatGroupId, senderGroupId, "joined-group");
        assertEq(chat.messagesCount(chatGroupId), 1);

        groupJoin.setTokenAddressCount(chatGroupId, senderOwner, 0);

        vm.prank(senderOwner);
        vm.expectRevert(IGroupChatErrors.ScopeRejected.selector);
        _post(chatGroupId, senderGroupId, "exited-group");
    }

    function testT132_groupJoinScopeCombinesWithAdminDenySource() public {
        AdminDenySource deny = new AdminDenySource(address(chat));
        (string[] memory keys, bytes[] memory values) = _emptyMeta();

        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(scope), address(deny), address(0), address(0), 0);

        groupJoin.setTokenAddressCount(chatGroupId, senderOwner, 1);

        vm.prank(chatOwner);
        deny.setAdmins(chatGroupId, _uints(chatGroupId));

        vm.prank(chatOwner);
        groupDefaults.setDefaultGroupId(chatGroupId);

        vm.prank(chatOwner);
        deny.addDenyListsBySenderGroupIds(chatGroupId, _uints(senderGroupId));

        (bool allowed, bytes4 reasonCode) = chat.canPostStatus(chatGroupId, senderGroupId, senderOwner);
        assertTrue(!allowed);
        assertEq(reasonCode, IGroupChatErrors.DenyRejected.selector);

        vm.prank(chatOwner);
        deny.addExemptListBySenderGroupIds(chatGroupId, _uints(senderGroupId));

        assertTrue(chat.canPost(chatGroupId, senderGroupId, senderOwner));
    }

    function _uints(uint256 value) internal pure returns (uint256[] memory values) {
        values = new uint256[](1);
        values[0] = value;
    }
}
