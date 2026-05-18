// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {GroupAdmin} from "../src/GroupAdmin.sol";
import {IGroupAdmin} from "../src/interfaces/IGroupAdmin.sol";
import {IGroupChatErrors} from "../src/interfaces/IGroupChat.sol";
import {IGroupMemberScope} from "../src/interfaces/sources/scope/IGroupMemberScope.sol";
import {GroupMemberScope} from "../src/sources/scope/GroupMemberScope.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";

contract GroupMemberScopeTest is GroupChatFixture {
    GroupAdmin internal groupAdmin;
    GroupMemberScope internal scope;
    address internal adminOwner = address(0xAD11);
    uint256 internal adminId;

    function setUp() public override {
        super.setUp();
        adminId = groupNft.mint(adminOwner);
        groupAdmin = new GroupAdmin(address(chat), 20);
        scope = new GroupMemberScope(address(groupAdmin));
    }

    function testT133A_constructorStoresDependenciesAndRejectsNoCodeAdmin() public {
        assertEq(scope.GROUP_ADMIN_ADDRESS(), address(groupAdmin));
        assertEq(scope.GROUP_ADDRESS(), address(groupNft));

        vm.expectRevert(IGroupMemberScope.GroupMemberScopeAddressHasNoCode.selector);
        new GroupMemberScope(address(0x1234));
    }

    function testT133B_adminCanAddAndRemoveMemberIds() public {
        _configureAdmin();

        vm.prank(adminOwner);
        scope.addMemberIds(groupId, _uints(senderId, otherGroupId));
        assertTrue(scope.isMemberId(groupId, senderId));
        assertTrue(scope.isMemberId(groupId, otherGroupId));
        assertEq(scope.memberIdsCount(groupId), 2);
        assertEq(scope.stateVersion(groupId), 1);

        vm.prank(adminOwner);
        scope.addMemberIds(groupId, _uints(senderId));
        assertEq(scope.stateVersion(groupId), 1);

        uint256[] memory page = scope.memberIds(groupId, 1, 1);
        assertEq(page.length, 1);
        assertEq(page[0], otherGroupId);

        bool[] memory listed = scope.isMemberIdBatch(groupId, _uints(senderId, groupId));
        assertTrue(listed[0]);
        assertTrue(!listed[1]);

        vm.prank(adminOwner);
        scope.removeMemberIds(groupId, _uints(senderId));
        assertTrue(!scope.isMemberId(groupId, senderId));
        assertTrue(scope.isMemberId(groupId, otherGroupId));
        assertEq(scope.stateVersion(groupId), 2);
    }

    function testT133C_memberIdsControlGroupChatPostAndTransferFollowsNft() public {
        _configureAdmin();
        (string[] memory keys, bytes[] memory values) = _emptyMeta();
        vm.prank(chatOwner);
        chat.activateChat(groupId, keys, values, address(scope), address(0), address(0), address(0), 0);

        (bool allowed, bytes4 reasonCode) = _canPost(groupId, senderId, senderOwner);
        assertTrue(!allowed);
        assertEq(reasonCode, IGroupChatErrors.ScopeRejected.selector);

        vm.prank(adminOwner);
        scope.addMemberIds(groupId, _uints(senderId));

        assertTrue(_canPostAllowed(groupId, senderId, senderOwner));

        groupNft.transferFrom(senderOwner, other, senderId);

        assertTrue(!_canPostAllowed(groupId, senderId, senderOwner));
        assertTrue(_canPostAllowed(groupId, senderId, other));
    }

    function testT133D_permissionsTargetsAndGroupIsolation() public {
        vm.prank(chatOwner);
        groupAdmin.setAdmins(groupId, _uints(adminId));

        vm.prank(adminOwner);
        vm.expectRevert(IGroupMemberScope.UnauthorizedGroupMemberScopeManager.selector);
        scope.addMemberIds(groupId, _uints(senderId));

        vm.prank(adminOwner);
        groupDefaults.setDefaultGroupId(adminId);

        vm.prank(adminOwner);
        vm.expectRevert(IGroupMemberScope.TargetMemberIdZero.selector);
        scope.addMemberIds(groupId, _uints(0));

        vm.prank(adminOwner);
        vm.expectRevert(IGroupMemberScope.GroupNotExist.selector);
        scope.addMemberIds(groupId, _uints(999999));

        vm.prank(adminOwner);
        scope.addMemberIds(groupId, _uints(senderId));

        assertTrue(scope.isMemberId(groupId, senderId));
        assertTrue(!scope.isMemberId(otherGroupId, senderId));

        vm.prank(adminOwner);
        vm.expectRevert(IGroupMemberScope.UnauthorizedGroupMemberScopeManager.selector);
        scope.addMemberIds(otherGroupId, _uints(senderId));

        vm.prank(chatOwner);
        vm.expectRevert(IGroupAdmin.UnauthorizedGroupAdminManager.selector);
        groupAdmin.setAdmins(otherGroupId, _uints(adminId));
    }

    function _configureAdmin() internal {
        vm.prank(chatOwner);
        groupAdmin.setAdmins(groupId, _uints(adminId));

        vm.prank(adminOwner);
        groupDefaults.setDefaultGroupId(adminId);
    }

    function _uints(uint256 value) internal pure returns (uint256[] memory values) {
        values = new uint256[](1);
        values[0] = value;
    }

    function _uints(uint256 a, uint256 b) internal pure returns (uint256[] memory values) {
        values = new uint256[](2);
        values[0] = a;
        values[1] = b;
    }
}
