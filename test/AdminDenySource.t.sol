// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChatErrors} from "../src/interfaces/IGroupChat.sol";
import {AdminDenySource} from "../src/sources/deny/AdminDenySource.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";

contract AdminDenySourceTest is GroupChatFixture {
    uint256 internal constant MAX_ADMIN_IDS = 20;

    AdminDenySource internal deny;
    address internal adminOwner = address(0xAD11);
    address internal secondAdminOwner = address(0xAD12);
    address internal stranger = address(0x5757);
    uint256 internal adminId;
    uint256 internal secondAdminId;

    function setUp() public override {
        super.setUp();
        adminId = groupNft.mint(adminOwner);
        secondAdminId = groupNft.mint(secondAdminOwner);
        deny = new AdminDenySource(address(chat), MAX_ADMIN_IDS);
    }

    function testT120_ownerAndDelegateCanConfigureAdminsAndExemptButNotDenyLists() public {
        address[] memory accounts = _addresses(senderOwner);

        vm.prank(chatOwner);
        deny.setAdmins(groupId, _uints(adminId));
        assertTrue(deny.isAdminId(groupId, adminId));
        assertEq(deny.stateVersion(groupId), 1);

        vm.prank(chatOwner);
        vm.expectRevert(AdminDenySource.UnauthorizedDenySourceManager.selector);
        deny.denyBySenderAddresses(groupId, accounts);

        (string[] memory keys, bytes[] memory values) = _emptyMeta();
        vm.prank(chatOwner);
        chat.activateChat(groupId, keys, values, address(0), address(deny), address(0), address(0), delegateId);

        vm.prank(delegateIdOwner);
        deny.exemptSenderIds(groupId, _uints(senderId));
        assertTrue(!deny.isDenied(groupId, senderId, senderOwner));
        assertEq(deny.stateVersion(groupId), 2);

        vm.prank(delegateIdOwner);
        vm.expectRevert(AdminDenySource.UnauthorizedDenySourceManager.selector);
        deny.denyBySenderAddresses(groupId, accounts);
    }

    function testT121_adminRequiresDefaultGroupAndCanOnlyManageDenyLists() public {
        uint256[] memory admins = _uints(adminId);
        address[] memory accounts = _addresses(senderOwner);

        vm.prank(chatOwner);
        deny.setAdmins(groupId, admins);
        assertTrue(deny.isAdminId(groupId, adminId));

        vm.prank(adminOwner);
        vm.expectRevert(AdminDenySource.UnauthorizedDenySourceManager.selector);
        deny.denyBySenderAddresses(groupId, accounts);

        vm.prank(adminOwner);
        groupDefaults.setDefaultGroupId(adminId);

        vm.prank(adminOwner);
        deny.denyBySenderAddresses(groupId, accounts);
        assertTrue(deny.isAddressDenied(groupId, senderOwner));

        vm.prank(adminOwner);
        vm.expectRevert(AdminDenySource.UnauthorizedDenySourceManager.selector);
        deny.exemptSenderIds(groupId, _uints(senderId));

        vm.prank(adminOwner);
        vm.expectRevert(AdminDenySource.UnauthorizedDenySourceManager.selector);
        deny.setAdmins(groupId, new uint256[](0));
    }

    function testT122_denySourceBlocksPostsAndExemptListWins() public {
        _configureAdmin();
        (string[] memory keys, bytes[] memory values) = _emptyMeta();
        vm.prank(chatOwner);
        chat.activateChat(groupId, keys, values, address(0), address(deny), address(0), address(0), 0);

        vm.prank(adminOwner);
        deny.denyBySenderIds(groupId, _uints(senderId));

        (bool allowed, bytes4 reasonCode) = _canPost(groupId, senderId, senderOwner);
        assertTrue(!allowed);
        assertEq(bytes32(reasonCode), bytes32(IGroupChatErrors.DenyRejected.selector));

        vm.roll(originBlocks);
        vm.prank(senderOwner);
        vm.expectRevert(IGroupChatErrors.DenyRejected.selector);
        _post(groupId, senderId, "blocked");

        vm.prank(chatOwner);
        deny.exemptSenderIds(groupId, _uints(senderId));

        assertTrue(!deny.isDenied(groupId, senderId, senderOwner));
        vm.prank(senderOwner);
        _post(groupId, senderId, "allowed");
        assertEq(chat.messagesCount(groupId), 1);
    }

    function testT123_listsAreIsolatedPagedAndStateVersionChangesOncePerBatch() public {
        _configureAdmin();
        uint256 baseVersion = deny.stateVersion(groupId);

        vm.prank(adminOwner);
        deny.denyBySenderAddresses(groupId, _addresses(address(0x101), address(0x102), address(0x103)));
        assertEq(deny.addressDenyListCount(groupId), 3);
        assertEq(deny.stateVersion(groupId), baseVersion + 1);

        vm.prank(adminOwner);
        deny.denyBySenderAddresses(groupId, _addresses(address(0x101)));
        assertEq(deny.stateVersion(groupId), baseVersion + 1);

        address[] memory page = deny.addressDenyList(groupId, 1, 2);
        assertEq(page.length, 2);
        assertEq(page[0], address(0x102));
        assertEq(page[1], address(0x103));

        address[] memory empty = deny.addressDenyList(groupId, 99, 1);
        assertEq(empty.length, 0);
        assertEq(deny.addressDenyListCount(otherGroupId), 0);

        vm.prank(adminOwner);
        deny.undenyBySenderAddresses(groupId, _addresses(address(0x102), address(0x999)));
        assertEq(deny.addressDenyListCount(groupId), 2);
        assertEq(deny.stateVersion(groupId), baseVersion + 2);
        assertTrue(!deny.isAddressDenied(groupId, address(0x102)));
    }

    function testT124_setAdminsReplacesValidatesAndTransferRevokesAdmin() public {
        vm.prank(chatOwner);
        deny.setAdmins(groupId, _uints(adminId, secondAdminId));
        uint256[] memory admins = deny.adminIds(groupId);
        assertEq(admins.length, 2);
        assertEq(admins[0], adminId);
        assertEq(admins[1], secondAdminId);
        assertEq(deny.stateVersion(groupId), 1);

        vm.prank(chatOwner);
        vm.expectRevert(AdminDenySource.DuplicateAdminId.selector);
        deny.setAdmins(groupId, _uints(adminId, adminId));

        vm.prank(chatOwner);
        vm.expectRevert(AdminDenySource.GroupNotExist.selector);
        deny.setAdmins(groupId, _uints(999999));

        vm.prank(adminOwner);
        groupDefaults.setDefaultGroupId(adminId);

        vm.prank(adminOwner);
        deny.denyBySenderIds(groupId, _uints(senderId));
        assertTrue(deny.isSenderIdDenied(groupId, senderId));
        assertTrue(!deny.isAddressDenied(groupId, senderOwner));

        groupNft.transferFrom(adminOwner, stranger, adminId);

        vm.prank(adminOwner);
        vm.expectRevert(AdminDenySource.UnauthorizedDenySourceManager.selector);
        deny.denyBySenderIds(groupId, _uints(otherGroupId));
    }

    function testT124B_setAdminsRejectsAdminCountAboveLimit() public {
        vm.expectRevert(AdminDenySource.MaxAdminIdsZero.selector);
        new AdminDenySource(address(chat), 0);

        uint256[] memory admins = new uint256[](MAX_ADMIN_IDS + 1);
        for (uint256 i = 0; i < admins.length; i++) {
            admins[i] = groupNft.mint(address(uint160(0xA000 + i)));
        }

        vm.prank(chatOwner);
        vm.expectRevert(AdminDenySource.AdminIdsLimitExceeded.selector);
        deny.setAdmins(groupId, admins);
    }

    function testT125_senderIdDenyListsOnlyAffectSenderIds() public {
        _configureAdmin();
        uint256 baseVersion = deny.stateVersion(groupId);

        vm.prank(adminOwner);
        deny.denyBySenderIds(groupId, _uints(senderId, otherGroupId));

        assertTrue(!deny.isAddressDenied(groupId, senderOwner));
        assertTrue(!deny.isAddressDenied(groupId, other));
        assertTrue(deny.isSenderIdDenied(groupId, senderId));
        assertTrue(deny.isSenderIdDenied(groupId, otherGroupId));
        assertTrue(deny.isDenied(groupId, senderId, senderOwner));
        assertTrue(deny.isDenied(groupId, otherGroupId, other));
        assertEq(deny.stateVersion(groupId), baseVersion + 1);

        vm.prank(adminOwner);
        deny.undenyBySenderIds(groupId, _uints(senderId, otherGroupId));

        assertTrue(!deny.isAddressDenied(groupId, senderOwner));
        assertTrue(!deny.isAddressDenied(groupId, other));
        assertTrue(!deny.isSenderIdDenied(groupId, senderId));
        assertTrue(!deny.isSenderIdDenied(groupId, otherGroupId));
        assertTrue(!deny.isDenied(groupId, senderId, senderOwner));
        assertTrue(!deny.isDenied(groupId, otherGroupId, other));
        assertEq(deny.stateVersion(groupId), baseVersion + 2);
    }

    function testT126_senderAddressDenyListsOnlyAffectAddresses() public {
        _configureAdmin();
        uint256 baseVersion = deny.stateVersion(groupId);

        vm.prank(senderOwner);
        groupDefaults.setDefaultGroupId(senderId);

        vm.prank(adminOwner);
        deny.denyBySenderAddresses(groupId, _addresses(senderOwner, stranger));
        assertTrue(deny.isAddressDenied(groupId, senderOwner));
        assertTrue(!deny.isSenderIdDenied(groupId, senderId));
        assertTrue(deny.isAddressDenied(groupId, stranger));
        assertEq(deny.senderIdDenyListCount(groupId), 0);
        assertEq(deny.stateVersion(groupId), baseVersion + 1);

        vm.prank(adminOwner);
        deny.undenyBySenderAddresses(groupId, _addresses(senderOwner, stranger));
        assertTrue(!deny.isAddressDenied(groupId, senderOwner));
        assertTrue(!deny.isSenderIdDenied(groupId, senderId));
        assertTrue(!deny.isAddressDenied(groupId, stranger));
        assertEq(deny.stateVersion(groupId), baseVersion + 2);
    }

    function testT126B_denyBySendersAffectsAddressesAndSenderIdsTogether() public {
        _configureAdmin();
        uint256 baseVersion = deny.stateVersion(groupId);

        vm.prank(stranger);
        vm.expectRevert(AdminDenySource.UnauthorizedDenySourceManager.selector);
        deny.denyBySenders(groupId, _uints(senderId), _addresses(senderOwner, other));

        vm.prank(adminOwner);
        vm.expectRevert(AdminDenySource.SenderPairLengthMismatch.selector);
        deny.denyBySenders(groupId, _uints(senderId), _addresses(senderOwner, other));

        vm.prank(adminOwner);
        deny.denyBySenders(groupId, _uints(senderId, otherGroupId), _addresses(senderOwner, other));

        assertTrue(deny.isAddressDenied(groupId, senderOwner));
        assertTrue(deny.isAddressDenied(groupId, other));
        assertTrue(deny.isSenderIdDenied(groupId, senderId));
        assertTrue(deny.isSenderIdDenied(groupId, otherGroupId));
        assertEq(deny.stateVersion(groupId), baseVersion + 1);

        vm.prank(adminOwner);
        deny.undenyBySenders(groupId, _uints(senderId, otherGroupId), _addresses(senderOwner, other));

        assertTrue(!deny.isAddressDenied(groupId, senderOwner));
        assertTrue(!deny.isAddressDenied(groupId, other));
        assertTrue(!deny.isSenderIdDenied(groupId, senderId));
        assertTrue(!deny.isSenderIdDenied(groupId, otherGroupId));
        assertEq(deny.stateVersion(groupId), baseVersion + 2);
    }

    function testT127_ownerCanManageDenyListsOnlyThroughAdminNftList() public {
        vm.prank(chatOwner);
        deny.setAdmins(groupId, _uints(groupId));

        vm.prank(chatOwner);
        vm.expectRevert(AdminDenySource.UnauthorizedDenySourceManager.selector);
        deny.denyBySenderAddresses(groupId, _addresses(senderOwner));

        vm.prank(chatOwner);
        groupDefaults.setDefaultGroupId(groupId);

        vm.prank(chatOwner);
        deny.denyBySenderAddresses(groupId, _addresses(senderOwner));
        assertTrue(deny.isAddressDenied(groupId, senderOwner));
    }

    function testT128_batchListChecksReturnIndependentCacheSlices() public {
        _configureAdmin();

        vm.prank(adminOwner);
        deny.denyBySenderIds(groupId, _uints(senderId));

        bool[] memory addressDenied = deny.isAddressDeniedBatch(groupId, _addresses(senderOwner, other));
        assertEq(addressDenied.length, 2);
        assertTrue(!addressDenied[0]);
        assertTrue(!addressDenied[1]);

        bool[] memory senderIdDenied = deny.isSenderIdDeniedBatch(groupId, _uints(senderId, otherGroupId));
        assertEq(senderIdDenied.length, 2);
        assertTrue(senderIdDenied[0]);
        assertTrue(!senderIdDenied[1]);

        bool[] memory senderIdExempt = deny.isSenderIdExemptBatch(groupId, _uints(senderId, otherGroupId));
        assertEq(senderIdExempt.length, 2);
        assertTrue(!senderIdExempt[0]);
        assertTrue(!senderIdExempt[1]);

        vm.prank(chatOwner);
        deny.exemptSenderIds(groupId, _uints(senderId));

        senderIdExempt = deny.isSenderIdExemptBatch(groupId, _uints(senderId, otherGroupId));
        assertTrue(senderIdExempt[0]);
        assertTrue(!senderIdExempt[1]);
        assertTrue(!deny.isDenied(groupId, senderId, senderOwner));
    }

    function _configureAdmin() internal {
        vm.prank(chatOwner);
        deny.setAdmins(groupId, _uints(adminId));

        vm.prank(adminOwner);
        groupDefaults.setDefaultGroupId(adminId);
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
