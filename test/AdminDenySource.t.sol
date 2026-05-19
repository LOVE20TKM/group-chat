// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {GroupAdmin} from "../src/GroupAdmin.sol";
import {IGroupAdmin} from "../src/interfaces/IGroupAdmin.sol";
import {IGroupChatErrors} from "../src/interfaces/IGroupChat.sol";
import {IAdminDenySource} from "../src/interfaces/sources/deny/IAdminDenySource.sol";
import {AdminDenySource} from "../src/sources/deny/AdminDenySource.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";

contract AdminDenySourceTest is GroupChatFixture {
    uint256 internal constant MAX_ADMIN_IDS = 20;

    GroupAdmin internal groupAdmin;
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
        groupAdmin = new GroupAdmin(address(chat), MAX_ADMIN_IDS);
        deny = new AdminDenySource(address(groupAdmin));
    }

    function testT120_ownerAndDelegateCanConfigureAdminsButNotDenyLists() public {
        address[] memory accounts = _addresses(senderOwner);

        vm.prank(chatOwner);
        groupAdmin.setAdmins(groupId, _uints(adminId));
        assertTrue(groupAdmin.isAdminId(groupId, adminId));
        assertEq(groupAdmin.stateVersion(groupId), 1);

        vm.prank(chatOwner);
        vm.expectRevert(IAdminDenySource.UnauthorizedDenySourceManager.selector);
        deny.denyBySenderAddresses(groupId, accounts);

        (string[] memory keys, bytes[] memory values) = _emptyMeta();
        vm.prank(chatOwner);
        chat.activateChat(groupId, keys, values, address(0), address(deny), address(0), address(0), delegateId);

        vm.prank(delegateIdOwner);
        vm.expectRevert(IAdminDenySource.UnauthorizedDenySourceManager.selector);
        deny.denyBySenderAddresses(groupId, accounts);
    }

    function testT121_adminRequiresDefaultGroupAndCanOnlyManageDenyLists() public {
        uint256[] memory admins = _uints(adminId);
        address[] memory accounts = _addresses(senderOwner);

        vm.prank(chatOwner);
        groupAdmin.setAdmins(groupId, admins);
        assertTrue(groupAdmin.isAdminId(groupId, adminId));

        vm.prank(adminOwner);
        vm.expectRevert(IAdminDenySource.UnauthorizedDenySourceManager.selector);
        deny.denyBySenderAddresses(groupId, accounts);

        vm.prank(adminOwner);
        groupDefaults.setDefaultGroupId(adminId);

        vm.prank(adminOwner);
        deny.denyBySenderAddresses(groupId, accounts);
        assertTrue(deny.isAddressDenied(groupId, senderOwner));

        vm.prank(adminOwner);
        vm.expectRevert(IGroupAdmin.UnauthorizedGroupAdminManager.selector);
        groupAdmin.setAdmins(groupId, new uint256[](0));
    }

    function testT122_denySourceBlocksPostsAndUndenyRestoresPosting() public {
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

        vm.prank(adminOwner);
        deny.undenyBySenderIds(groupId, _uints(senderId));

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

        (address[] memory page, address[] memory operatorAddresses, uint256[] memory operatorIds) =
            deny.addressDenyList(groupId, 1, 2);
        assertEq(page.length, 2);
        assertEq(operatorAddresses.length, 2);
        assertEq(operatorIds.length, 2);
        assertEq(page[0], address(0x102));
        assertEq(page[1], address(0x103));
        assertEq(operatorAddresses[0], adminOwner);
        assertEq(operatorAddresses[1], adminOwner);
        assertEq(operatorIds[0], adminId);
        assertEq(operatorIds[1], adminId);

        (address[] memory empty, address[] memory emptyOperatorAddresses, uint256[] memory emptyOperatorIds) =
            deny.addressDenyList(groupId, 99, 1);
        assertEq(empty.length, 0);
        assertEq(emptyOperatorAddresses.length, 0);
        assertEq(emptyOperatorIds.length, 0);
        assertEq(deny.addressDenyListCount(otherGroupId), 0);

        vm.prank(adminOwner);
        deny.undenyBySenderAddresses(groupId, _addresses(address(0x102), address(0x999)));
        assertEq(deny.addressDenyListCount(groupId), 2);
        assertEq(deny.stateVersion(groupId), baseVersion + 2);
        assertTrue(!deny.isAddressDenied(groupId, address(0x102)));
    }

    function testT124_setAdminsReplacesValidatesAndTransferRevokesAdmin() public {
        vm.prank(chatOwner);
        groupAdmin.setAdmins(groupId, _uints(adminId, secondAdminId));
        uint256[] memory admins = groupAdmin.adminIds(groupId);
        assertEq(admins.length, 2);
        assertEq(admins[0], adminId);
        assertEq(admins[1], secondAdminId);
        assertEq(groupAdmin.stateVersion(groupId), 1);

        vm.prank(chatOwner);
        vm.expectRevert(IGroupAdmin.DuplicateAdminId.selector);
        groupAdmin.setAdmins(groupId, _uints(adminId, adminId));

        vm.prank(chatOwner);
        vm.expectRevert(IGroupAdmin.GroupNotExist.selector);
        groupAdmin.setAdmins(groupId, _uints(999999));

        vm.prank(adminOwner);
        groupDefaults.setDefaultGroupId(adminId);

        vm.prank(adminOwner);
        deny.denyBySenderIds(groupId, _uints(senderId));
        assertTrue(deny.isSenderIdDenied(groupId, senderId));
        assertTrue(!deny.isAddressDenied(groupId, senderOwner));

        groupNft.transferFrom(adminOwner, stranger, adminId);

        vm.prank(adminOwner);
        vm.expectRevert(IAdminDenySource.UnauthorizedDenySourceManager.selector);
        deny.denyBySenderIds(groupId, _uints(otherGroupId));
    }

    function testT124B_setAdminsRejectsAdminCountAboveLimit() public {
        vm.expectRevert(IGroupAdmin.MaxAdminIdsZero.selector);
        new GroupAdmin(address(chat), 0);

        uint256[] memory admins = new uint256[](MAX_ADMIN_IDS + 1);
        for (uint256 i = 0; i < admins.length; i++) {
            admins[i] = groupNft.mint(address(uint160(0xA000 + i)));
        }

        vm.prank(chatOwner);
        vm.expectRevert(IGroupAdmin.AdminIdsLimitExceeded.selector);
        groupAdmin.setAdmins(groupId, admins);
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
        vm.expectRevert(IAdminDenySource.UnauthorizedDenySourceManager.selector);
        deny.denyBySenders(groupId, _uints(senderId), _addresses(senderOwner, other));

        vm.prank(adminOwner);
        vm.expectRevert(IAdminDenySource.SenderPairLengthMismatch.selector);
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
        groupAdmin.setAdmins(groupId, _uints(groupId));

        vm.prank(chatOwner);
        vm.expectRevert(IAdminDenySource.UnauthorizedDenySourceManager.selector);
        deny.denyBySenderAddresses(groupId, _addresses(senderOwner));

        vm.prank(chatOwner);
        groupDefaults.setDefaultGroupId(groupId);

        vm.prank(chatOwner);
        deny.denyBySenderAddresses(groupId, _addresses(senderOwner));
        assertTrue(deny.isAddressDenied(groupId, senderOwner));
    }

    function testT128_denyDetailsReturnIndependentCacheSlicesAndOperators() public {
        _configureAdmin();

        vm.prank(adminOwner);
        deny.denyBySenderIds(groupId, _uints(senderId));

        (bool[] memory addressDenied, address[] memory addressOperatorAddresses, uint256[] memory addressOperatorIds) =
            deny.addressDenyDetails(groupId, _addresses(senderOwner, other));
        assertEq(addressDenied.length, 2);
        assertEq(addressOperatorAddresses.length, 2);
        assertEq(addressOperatorIds.length, 2);
        assertTrue(!addressDenied[0]);
        assertTrue(!addressDenied[1]);
        assertEq(addressOperatorAddresses[0], address(0));
        assertEq(addressOperatorAddresses[1], address(0));
        assertEq(addressOperatorIds[0], 0);
        assertEq(addressOperatorIds[1], 0);

        (bool[] memory senderIdDenied, address[] memory senderIdOperatorAddresses, uint256[] memory senderIdOperatorIds)
        = deny.senderIdDenyDetails(groupId, _uints(senderId, otherGroupId));
        assertEq(senderIdDenied.length, 2);
        assertEq(senderIdOperatorAddresses.length, 2);
        assertEq(senderIdOperatorIds.length, 2);
        assertTrue(senderIdDenied[0]);
        assertTrue(!senderIdDenied[1]);
        assertEq(senderIdOperatorAddresses[0], adminOwner);
        assertEq(senderIdOperatorAddresses[1], address(0));
        assertEq(senderIdOperatorIds[0], adminId);
        assertEq(senderIdOperatorIds[1], 0);

        assertTrue(deny.isDenied(groupId, senderId, senderOwner));
    }

    function testT128B_denyListPagesReturnCurrentListerAndClearOnUndeny() public {
        _configureAdmin();

        vm.prank(adminOwner);
        deny.denyBySenderAddresses(groupId, _addresses(senderOwner, other));

        (address[] memory addressPage, address[] memory operatorAddresses, uint256[] memory operatorIds) =
            deny.addressDenyList(groupId, 0, 2);
        assertEq(addressPage.length, 2);
        assertEq(operatorAddresses.length, 2);
        assertEq(operatorIds.length, 2);
        assertEq(addressPage[0], senderOwner);
        assertEq(addressPage[1], other);
        assertEq(operatorAddresses[0], adminOwner);
        assertEq(operatorIds[0], adminId);
        assertEq(operatorAddresses[1], adminOwner);
        assertEq(operatorIds[1], adminId);

        vm.prank(adminOwner);
        deny.denyBySenderIds(groupId, _uints(senderId, otherGroupId));

        (
            uint256[] memory senderIdPage,
            address[] memory senderIdPageOperatorAddresses,
            uint256[] memory senderIdPageOperatorIds
        ) = deny.senderIdDenyList(groupId, 0, 2);
        assertEq(senderIdPage.length, 2);
        assertEq(senderIdPageOperatorAddresses.length, 2);
        assertEq(senderIdPageOperatorIds.length, 2);
        assertEq(senderIdPage[0], senderId);
        assertEq(senderIdPage[1], otherGroupId);
        assertEq(senderIdPageOperatorAddresses[0], adminOwner);
        assertEq(senderIdPageOperatorAddresses[1], adminOwner);
        assertEq(senderIdPageOperatorIds[0], adminId);
        assertEq(senderIdPageOperatorIds[1], adminId);

        vm.prank(chatOwner);
        groupAdmin.setAdmins(groupId, _uints(adminId, secondAdminId));

        vm.prank(secondAdminOwner);
        groupDefaults.setDefaultGroupId(secondAdminId);

        vm.prank(secondAdminOwner);
        deny.denyBySenderAddresses(groupId, _addresses(other));

        (addressPage, operatorAddresses, operatorIds) = deny.addressDenyList(groupId, 1, 1);
        assertEq(addressPage[0], other);
        assertEq(operatorAddresses[0], adminOwner);
        assertEq(operatorIds[0], adminId);

        vm.prank(adminOwner);
        deny.undenyBySenderAddresses(groupId, _addresses(senderOwner));

        vm.prank(secondAdminOwner);
        deny.denyBySenderAddresses(groupId, _addresses(senderOwner));

        (addressPage, operatorAddresses, operatorIds) = deny.addressDenyList(groupId, 0, 2);
        assertEq(addressPage.length, 2);
        _assertAddressPageOperator(addressPage, operatorAddresses, operatorIds, other, adminOwner, adminId);
        _assertAddressPageOperator(
            addressPage, operatorAddresses, operatorIds, senderOwner, secondAdminOwner, secondAdminId
        );
    }

    function _assertAddressPageOperator(
        address[] memory accounts,
        address[] memory operatorAddresses,
        uint256[] memory operatorIds,
        address account,
        address expectedOperatorAddress,
        uint256 expectedOperatorId
    ) internal pure {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] == account) {
                assertEq(operatorAddresses[i], expectedOperatorAddress);
                assertEq(operatorIds[i], expectedOperatorId);
                return;
            }
        }
        assertTrue(false);
    }

    function _configureAdmin() internal {
        vm.prank(chatOwner);
        groupAdmin.setAdmins(groupId, _uints(adminId));

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
