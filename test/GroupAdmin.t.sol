// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {GroupAdmin} from "../src/GroupAdmin.sol";
import {IGroupAdmin} from "../src/interfaces/IGroupAdmin.sol";
import {MockGroupDelegate} from "./mocks/MockGroupDelegate.sol";
import {MockLOVE20Group} from "./mocks/MockLOVE20Group.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";

contract GroupAdminTest is GroupChatFixture {
    uint256 internal constant MAX_ADMIN_IDS = 20;

    GroupAdmin internal groupAdmin;
    address internal adminOwner = address(0xAD11);
    address internal secondAdminOwner = address(0xAD12);
    address internal stranger = address(0x5757);
    uint256 internal adminId;
    uint256 internal secondAdminId;

    function setUp() public override {
        super.setUp();
        adminId = groupNft.mint(adminOwner);
        secondAdminId = groupNft.mint(secondAdminOwner);
        groupAdmin = new GroupAdmin(address(groupDefaults), address(groupDelegate), MAX_ADMIN_IDS);
    }

    function testT129A_constructorStoresDependenciesAndRejectsInvalidConfig() public {
        assertEq(groupAdmin.GROUP_DEFAULTS_ADDRESS(), address(groupDefaults));
        assertEq(groupAdmin.GROUP_DELEGATE_ADDRESS(), address(groupDelegate));
        assertEq(groupAdmin.GROUP_ADDRESS(), address(groupNft));
        assertEq(groupAdmin.MAX_ADMIN_IDS(), MAX_ADMIN_IDS);

        vm.expectRevert(IGroupAdmin.GroupAdminAddressHasNoCode.selector);
        new GroupAdmin(address(0x1234), address(groupDelegate), MAX_ADMIN_IDS);

        vm.expectRevert(IGroupAdmin.GroupAdminAddressHasNoCode.selector);
        new GroupAdmin(address(groupDefaults), address(0x1234), MAX_ADMIN_IDS);

        MockLOVE20Group otherGroup = new MockLOVE20Group();
        MockGroupDelegate mismatchedDelegate = new MockGroupDelegate(address(otherGroup));
        vm.expectRevert(IGroupAdmin.GroupDelegateGroupMismatch.selector);
        new GroupAdmin(address(groupDefaults), address(mismatchedDelegate), MAX_ADMIN_IDS);

        vm.expectRevert(IGroupAdmin.MaxAdminIdsZero.selector);
        new GroupAdmin(address(groupDefaults), address(groupDelegate), 0);
    }

    function testT129B_ownerAndDelegateCanSetAdmins() public {
        vm.prank(chatOwner);
        groupAdmin.setAdmins(groupId, _uints(adminId));
        assertTrue(groupAdmin.isAdminId(groupId, adminId));
        assertEq(groupAdmin.stateVersion(groupId), 1);

        (string[] memory keys, bytes[] memory values) = _emptyMeta();
        vm.prank(chatOwner);
        chat.activateChat(groupId, keys, values, address(0), address(0), address(0), address(0));
        vm.prank(chatOwner);
        groupDelegate.setDelegateId(groupId, delegateId);

        vm.prank(delegateIdOwner);
        groupAdmin.setAdmins(groupId, _uints(secondAdminId));
        assertTrue(!groupAdmin.isAdminId(groupId, adminId));
        assertTrue(groupAdmin.isAdminId(groupId, secondAdminId));
        assertEq(groupAdmin.stateVersion(groupId), 2);

        vm.prank(stranger);
        vm.expectRevert(IGroupAdmin.UnauthorizedGroupAdminManager.selector);
        groupAdmin.setAdmins(groupId, _uints(adminId));
    }

    function testT129C_adminIdOfUsesCurrentDefaultNftAndTransferRevokes() public {
        vm.prank(chatOwner);
        groupAdmin.setAdmins(groupId, _uints(adminId, secondAdminId));

        assertEq(groupAdmin.adminIdOf(groupId, adminOwner), 0);

        vm.prank(adminOwner);
        groupDefaults.setDefaultGroupId(adminId);
        assertEq(groupAdmin.adminIdOf(groupId, adminOwner), adminId);

        groupNft.transferFrom(adminOwner, stranger, adminId);

        assertEq(groupAdmin.adminIdOf(groupId, adminOwner), 0);
        assertEq(groupAdmin.adminIdOf(groupId, stranger), 0);
    }

    function testT129D_setAdminsValidatesInputAndPaginatesFullList() public {
        vm.prank(chatOwner);
        vm.expectRevert(IGroupAdmin.DuplicateAdminId.selector);
        groupAdmin.setAdmins(groupId, _uints(adminId, adminId));

        vm.prank(chatOwner);
        vm.expectRevert(IGroupAdmin.GroupNotExist.selector);
        groupAdmin.setAdmins(groupId, _uints(999999));

        uint256[] memory admins = new uint256[](MAX_ADMIN_IDS + 1);
        for (uint256 i = 0; i < admins.length; i++) {
            admins[i] = groupNft.mint(address(uint160(0xA000 + i)));
        }

        vm.prank(chatOwner);
        vm.expectRevert(IGroupAdmin.AdminIdsLimitExceeded.selector);
        groupAdmin.setAdmins(groupId, admins);

        vm.prank(chatOwner);
        groupAdmin.setAdmins(groupId, _uints(adminId, secondAdminId));

        uint256[] memory listed = groupAdmin.adminIds(groupId);
        assertEq(listed.length, 2);
        assertEq(listed[0], adminId);
        assertEq(listed[1], secondAdminId);
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
