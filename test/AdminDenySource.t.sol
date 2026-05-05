// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChatErrors} from "../src/interfaces/IGroupChat.sol";
import {AdminDenySource} from "../src/sources/deny/AdminDenySource.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";

contract AdminDenySourceTest is GroupChatFixture {
    AdminDenySource internal deny;
    address internal adminOwner = address(0xAD11);
    address internal secondAdminOwner = address(0xAD12);
    address internal stranger = address(0x5757);
    uint256 internal adminGroupId;
    uint256 internal secondAdminGroupId;

    function setUp() public override {
        super.setUp();
        adminGroupId = groupNft.mint(adminOwner);
        secondAdminGroupId = groupNft.mint(secondAdminOwner);
        deny = new AdminDenySource(address(chat));
    }

    function testT120_ownerAndDelegateCanConfigureAdminsAndExemptButNotDenyLists() public {
        address[] memory accounts = _addresses(senderOwner);

        vm.prank(chatOwner);
        deny.setAdmins(chatGroupId, _uints(adminGroupId));
        assertTrue(deny.isAdminGroup(chatGroupId, adminGroupId));
        assertEq(deny.stateVersion(chatGroupId), 1);

        vm.prank(chatOwner);
        vm.expectRevert(AdminDenySource.UnauthorizedDenySourceManager.selector);
        deny.addDenyListsBySenderAddresses(chatGroupId, accounts);

        (string[] memory keys, bytes[] memory values) = _emptyMeta();
        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(0), address(deny), address(0), address(0), delegateGroupId);

        vm.prank(delegateGroupOwner);
        deny.addExemptListBySenderGroupIds(chatGroupId, _uints(senderGroupId));
        assertTrue(!deny.isDenied(chatGroupId, senderGroupId, senderOwner));
        assertEq(deny.stateVersion(chatGroupId), 2);

        vm.prank(delegateGroupOwner);
        vm.expectRevert(AdminDenySource.UnauthorizedDenySourceManager.selector);
        deny.addDenyListsBySenderAddresses(chatGroupId, accounts);
    }

    function testT121_adminRequiresDefaultGroupAndCanOnlyManageDenyLists() public {
        uint256[] memory admins = _uints(adminGroupId);
        address[] memory accounts = _addresses(senderOwner);

        vm.prank(chatOwner);
        deny.setAdmins(chatGroupId, admins);
        assertTrue(deny.isAdminGroup(chatGroupId, adminGroupId));

        vm.prank(adminOwner);
        vm.expectRevert(AdminDenySource.UnauthorizedDenySourceManager.selector);
        deny.addDenyListsBySenderAddresses(chatGroupId, accounts);

        vm.prank(adminOwner);
        groupDefaults.setDefaultGroupId(adminGroupId);

        vm.prank(adminOwner);
        deny.addDenyListsBySenderAddresses(chatGroupId, accounts);
        assertTrue(deny.isAddressDenied(chatGroupId, senderOwner));

        vm.prank(adminOwner);
        vm.expectRevert(AdminDenySource.UnauthorizedDenySourceManager.selector);
        deny.addExemptListBySenderGroupIds(chatGroupId, _uints(senderGroupId));

        vm.prank(adminOwner);
        vm.expectRevert(AdminDenySource.UnauthorizedDenySourceManager.selector);
        deny.setAdmins(chatGroupId, new uint256[](0));
    }

    function testT122_denySourceBlocksPostsAndExemptListWins() public {
        _configureAdmin();
        (string[] memory keys, bytes[] memory values) = _emptyMeta();
        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(0), address(deny), address(0), address(0), 0);

        vm.prank(adminOwner);
        deny.addDenyListsBySenderGroupIds(chatGroupId, _uints(senderGroupId));

        (bool allowed, bytes4 reasonCode) = chat.canPostStatus(chatGroupId, senderGroupId, senderOwner);
        assertTrue(!allowed);
        assertEq(bytes32(reasonCode), bytes32(IGroupChatErrors.DenyRejected.selector));

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        vm.expectRevert(IGroupChatErrors.DenyRejected.selector);
        _post(chatGroupId, senderGroupId, "blocked");

        vm.prank(chatOwner);
        deny.addExemptListBySenderGroupIds(chatGroupId, _uints(senderGroupId));

        assertTrue(!deny.isDenied(chatGroupId, senderGroupId, senderOwner));
        vm.prank(senderOwner);
        _post(chatGroupId, senderGroupId, "allowed");
        assertEq(chat.messagesCount(chatGroupId), 1);
    }

    function testT123_listsAreIsolatedPagedAndStateVersionChangesOncePerBatch() public {
        _configureAdmin();
        uint256 baseVersion = deny.stateVersion(chatGroupId);

        vm.prank(adminOwner);
        deny.addDenyListsBySenderAddresses(chatGroupId, _addresses(address(0x101), address(0x102), address(0x103)));
        assertEq(deny.addressDenyListCount(chatGroupId), 3);
        assertEq(deny.stateVersion(chatGroupId), baseVersion + 1);

        vm.prank(adminOwner);
        deny.addDenyListsBySenderAddresses(chatGroupId, _addresses(address(0x101)));
        assertEq(deny.stateVersion(chatGroupId), baseVersion + 1);

        address[] memory page = deny.addressDenyList(chatGroupId, 1, 2);
        assertEq(page.length, 2);
        assertEq(page[0], address(0x102));
        assertEq(page[1], address(0x103));

        address[] memory empty = deny.addressDenyList(chatGroupId, 99, 1);
        assertEq(empty.length, 0);
        assertEq(deny.addressDenyListCount(otherGroupId), 0);

        vm.prank(adminOwner);
        deny.removeDenyListsBySenderAddresses(chatGroupId, _addresses(address(0x102), address(0x999)));
        assertEq(deny.addressDenyListCount(chatGroupId), 2);
        assertEq(deny.stateVersion(chatGroupId), baseVersion + 2);
        assertTrue(!deny.isAddressDenied(chatGroupId, address(0x102)));
    }

    function testT124_setAdminsReplacesValidatesAndTransferRevokesAdmin() public {
        vm.prank(chatOwner);
        deny.setAdmins(chatGroupId, _uints(adminGroupId, secondAdminGroupId));
        assertEq(deny.adminGroupsCount(chatGroupId), 2);
        assertEq(deny.stateVersion(chatGroupId), 1);

        vm.prank(chatOwner);
        vm.expectRevert(AdminDenySource.DuplicateAdminGroupId.selector);
        deny.setAdmins(chatGroupId, _uints(adminGroupId, adminGroupId));

        vm.prank(chatOwner);
        vm.expectRevert(AdminDenySource.GroupNotExist.selector);
        deny.setAdmins(chatGroupId, _uints(999999));

        vm.prank(adminOwner);
        groupDefaults.setDefaultGroupId(adminGroupId);

        vm.prank(adminOwner);
        deny.addDenyListsBySenderGroupIds(chatGroupId, _uints(senderGroupId));
        assertTrue(deny.isSenderGroupIdDenied(chatGroupId, senderGroupId));
        assertTrue(deny.isAddressDenied(chatGroupId, senderOwner));

        groupNft.transferFrom(adminOwner, stranger, adminGroupId);

        vm.prank(adminOwner);
        vm.expectRevert(AdminDenySource.UnauthorizedDenySourceManager.selector);
        deny.addDenyListsBySenderGroupIds(chatGroupId, _uints(otherGroupId));
    }

    function testT125_senderGroupIdDenyListsResolveOwnersAndAffectAddressesAndNftsTogether() public {
        _configureAdmin();
        uint256 baseVersion = deny.stateVersion(chatGroupId);

        vm.prank(adminOwner);
        deny.addDenyListsBySenderGroupIds(chatGroupId, _uints(senderGroupId, otherGroupId));

        assertTrue(deny.isAddressDenied(chatGroupId, senderOwner));
        assertTrue(deny.isAddressDenied(chatGroupId, other));
        assertTrue(deny.isSenderGroupIdDenied(chatGroupId, senderGroupId));
        assertTrue(deny.isSenderGroupIdDenied(chatGroupId, otherGroupId));
        assertTrue(deny.isDenied(chatGroupId, senderGroupId, senderOwner));
        assertTrue(deny.isDenied(chatGroupId, otherGroupId, other));
        assertEq(deny.stateVersion(chatGroupId), baseVersion + 1);

        vm.prank(adminOwner);
        deny.removeDenyListsBySenderGroupIds(chatGroupId, _uints(senderGroupId, otherGroupId));

        assertTrue(!deny.isAddressDenied(chatGroupId, senderOwner));
        assertTrue(!deny.isAddressDenied(chatGroupId, other));
        assertTrue(!deny.isSenderGroupIdDenied(chatGroupId, senderGroupId));
        assertTrue(!deny.isSenderGroupIdDenied(chatGroupId, otherGroupId));
        assertTrue(!deny.isDenied(chatGroupId, senderGroupId, senderOwner));
        assertTrue(!deny.isDenied(chatGroupId, otherGroupId, other));
        assertEq(deny.stateVersion(chatGroupId), baseVersion + 2);
    }

    function testT126_senderAddressDenyListsUseDefaultGroupWhenPresentAndSkipNftWhenMissing() public {
        _configureAdmin();
        uint256 baseVersion = deny.stateVersion(chatGroupId);

        vm.prank(senderOwner);
        groupDefaults.setDefaultGroupId(senderGroupId);

        vm.prank(adminOwner);
        deny.addDenyListsBySenderAddresses(chatGroupId, _addresses(senderOwner, stranger));
        assertTrue(deny.isAddressDenied(chatGroupId, senderOwner));
        assertTrue(deny.isSenderGroupIdDenied(chatGroupId, senderGroupId));
        assertTrue(deny.isAddressDenied(chatGroupId, stranger));
        assertEq(deny.senderGroupIdDenyListCount(chatGroupId), 1);
        assertEq(deny.stateVersion(chatGroupId), baseVersion + 1);

        vm.prank(adminOwner);
        deny.removeDenyListsBySenderAddresses(chatGroupId, _addresses(senderOwner, stranger));
        assertTrue(!deny.isAddressDenied(chatGroupId, senderOwner));
        assertTrue(!deny.isSenderGroupIdDenied(chatGroupId, senderGroupId));
        assertTrue(!deny.isAddressDenied(chatGroupId, stranger));
        assertEq(deny.stateVersion(chatGroupId), baseVersion + 2);
    }

    function testT127_ownerCanManageDenyListsOnlyThroughAdminNftList() public {
        vm.prank(chatOwner);
        deny.setAdmins(chatGroupId, _uints(chatGroupId));

        vm.prank(chatOwner);
        vm.expectRevert(AdminDenySource.UnauthorizedDenySourceManager.selector);
        deny.addDenyListsBySenderAddresses(chatGroupId, _addresses(senderOwner));

        vm.prank(chatOwner);
        groupDefaults.setDefaultGroupId(chatGroupId);

        vm.prank(chatOwner);
        deny.addDenyListsBySenderAddresses(chatGroupId, _addresses(senderOwner));
        assertTrue(deny.isAddressDenied(chatGroupId, senderOwner));
    }

    function _configureAdmin() internal {
        vm.prank(chatOwner);
        deny.setAdmins(chatGroupId, _uints(adminGroupId));

        vm.prank(adminOwner);
        groupDefaults.setDefaultGroupId(adminGroupId);
    }

    function _addresses(address account) internal pure returns (address[] memory accounts) {
        accounts = new address[](1);
        accounts[0] = account;
    }

    function _addresses(address a, address b) internal pure returns (address[] memory accounts) {
        accounts = new address[](2);
        accounts[0] = a;
        accounts[1] = b;
    }

    function _addresses(address a, address b, address c) internal pure returns (address[] memory accounts) {
        accounts = new address[](3);
        accounts[0] = a;
        accounts[1] = b;
        accounts[2] = c;
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
