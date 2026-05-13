// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChatErrors} from "../src/interfaces/IGroupChat.sol";

import {TokenActionGovManager} from "../src/managers/TokenActionGovManager.sol";
import {TokenGovManager} from "../src/managers/TokenGovManager.sol";
import {GovVotedDenySource} from "../src/sources/deny/GovVotedDenySource.sol";
import {MockLOVE20Protocols} from "./mocks/MockLOVE20Protocols.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";

contract MissingTotalDenyVoteWeightSource {
    uint256 internal immutable _voteWeight;

    constructor(uint256 voteWeight_) {
        _voteWeight = voteWeight_;
    }

    function denyVoteWeightOf(uint256, address) external view returns (uint256) {
        return _voteWeight;
    }
}

contract GovVotedDenySourceTest is GroupChatFixture {
    MockLOVE20Protocols internal protocol;
    GovVotedDenySource internal deny;
    TokenGovManager internal tokenGovManager;
    TokenActionGovManager internal actionGovManager;
    address internal token;
    address internal voter2 = address(0xB0B2);
    uint256 internal voter2GroupId;

    function setUp() public override {
        super.setUp();
        protocol = new MockLOVE20Protocols();
        token = address(protocol);
        deny = new GovVotedDenySource(address(groupNft), address(groupDefaults), 30);
        tokenGovManager = new TokenGovManager(address(chat), address(deny), address(0), address(0), address(protocol));
        actionGovManager =
            new TokenActionGovManager(address(chat), address(deny), address(0), address(0), address(protocol), 3);
        voter2GroupId = groupNft.mint(voter2);
    }

    function testT130_tokenGovVoteAndOpposeAffectIsDeniedAndGroupChat() public {
        _activateTokenGovManager();
        protocol.setGovVotes(token, senderOwner, 7);
        protocol.setGovVotes(token, voter2, 5);

        vm.prank(senderOwner);
        deny.voteDenyAddress(groupId, senderOwner);

        (uint256 supportWeight, uint256 opposeWeight) = deny.addressDenyTallyOf(groupId, senderOwner);
        assertEq(supportWeight, 7);
        assertEq(opposeWeight, 0);
        assertTrue(deny.isDenied(groupId, senderId, senderOwner));

        (bool allowed, bytes4 reasonCode) = _canPost(groupId, senderId, senderOwner);
        assertTrue(!allowed);
        assertEq(bytes32(reasonCode), bytes32(IGroupChatErrors.DenyRejected.selector));

        vm.prank(voter2);
        deny.opposeDenyAddress(groupId, senderOwner);

        (supportWeight, opposeWeight) = deny.addressDenyTallyOf(groupId, senderOwner);
        assertEq(supportWeight, 7);
        assertEq(opposeWeight, 5);
        assertTrue(deny.isDenied(groupId, senderId, senderOwner));

        protocol.setGovVotes(token, voter2, 8);
        vm.prank(voter2);
        deny.opposeDenyAddress(groupId, senderOwner);

        (supportWeight, opposeWeight) = deny.addressDenyTallyOf(groupId, senderOwner);
        assertEq(supportWeight, 7);
        assertEq(opposeWeight, 8);
        assertTrue(!deny.isDenied(groupId, senderId, senderOwner));
    }

    function testT131_clearAndRevalidateUpdateSettledWeightAndRemoveVoteAtZero() public {
        _activateTokenGovManager();
        protocol.setGovVotes(token, senderOwner, 9);

        vm.prank(senderOwner);
        deny.voteDenySenderId(groupId, senderId);
        assertTrue(deny.isDenied(groupId, senderId, senderOwner));
        assertEq(deny.senderIdDenyTargetsCount(groupId), 1);
        assertEq(deny.stateVersion(groupId), 1);

        protocol.setGovVotes(token, senderOwner, 4);
        deny.revalidateDenySenderIdVote(groupId, senderId, senderOwner);
        (bool supportDeny, uint256 settledWeight) = deny.senderIdDenyVoteOf(groupId, senderId, senderOwner);
        assertTrue(supportDeny);
        assertEq(settledWeight, 4);
        assertEq(deny.stateVersion(groupId), 2);

        protocol.setGovVotes(token, senderOwner, 0);
        deny.revalidateDenySenderIdVote(groupId, senderId, senderOwner);
        (supportDeny, settledWeight) = deny.senderIdDenyVoteOf(groupId, senderId, senderOwner);
        assertTrue(!supportDeny);
        assertEq(settledWeight, 0);
        assertEq(deny.senderIdDenyTargetsCount(groupId), 0);
        assertEq(deny.stateVersion(groupId), 3);

        protocol.setGovVotes(token, senderOwner, 6);
        vm.prank(senderOwner);
        deny.voteDenySenderId(groupId, senderId);
        vm.prank(senderOwner);
        deny.clearDenySenderIdVote(groupId, senderId);
        assertEq(deny.senderIdDenyTargetsCount(groupId), 0);
        assertEq(deny.stateVersion(groupId), 5);
    }

    function testT132_zeroWeightUnchangedAndMissingVoteRevert() public {
        _activateTokenGovManager();

        vm.prank(senderOwner);
        vm.expectRevert(GovVotedDenySource.VoteWeightZero.selector);
        deny.voteDenyAddress(groupId, senderOwner);

        protocol.setGovVotes(token, senderOwner, 3);
        vm.prank(senderOwner);
        deny.voteDenyAddress(groupId, senderOwner);

        vm.prank(senderOwner);
        vm.expectRevert(GovVotedDenySource.VoteUnchanged.selector);
        deny.voteDenyAddress(groupId, senderOwner);

        vm.expectRevert(GovVotedDenySource.VoteNotFound.selector);
        deny.revalidateDenyAddressVote(groupId, other, senderOwner);

        vm.prank(voter2);
        vm.expectRevert(GovVotedDenySource.VoteNotFound.selector);
        deny.clearDenyAddressVote(groupId, senderOwner);
    }

    function testT133_readerDegradesWhenSourceUnavailable() public {
        assertEq(deny.addressDenyTargetsCount(groupId), 0);
        assertEq(deny.senderIdDenyTargetsCount(groupId), 0);
        assertTrue(!deny.isDenied(groupId, senderId, senderOwner));
        (uint256 supportWeight, uint256 opposeWeight) = deny.addressDenyTallyOf(groupId, senderOwner);
        assertEq(supportWeight, 0);
        assertEq(opposeWeight, 0);
        (bool supportDeny, uint256 settledWeight) = deny.addressDenyVoteOf(groupId, senderOwner, senderOwner);
        assertTrue(!supportDeny);
        assertEq(settledWeight, 0);
        address[] memory voters;
        bool[] memory supportDenies;
        uint256[] memory settledWeights;
        (voters, supportDenies, settledWeights) = deny.addressDenyVoters(groupId, senderOwner, 0, 10);
        assertEq(voters.length, 0);
        assertEq(supportDenies.length, 0);
        assertEq(settledWeights.length, 0);

        vm.prank(senderOwner);
        vm.expectRevert(GovVotedDenySource.DenyVoteWeightSourceUnavailable.selector);
        deny.voteDenyAddress(groupId, senderOwner);
    }

    function testT134_actionGovManagerActsAsWeightSource() public {
        protocol.setCurrentRound(7);
        groupId = actionGovManager.activate(token, 42);

        protocol.setActionVotes(token, 7, senderOwner, 42, 11);
        vm.prank(senderOwner);
        deny.voteDenySenderId(groupId, senderId);

        (uint256 supportWeight, uint256 opposeWeight) = deny.senderIdDenyTallyOf(groupId, senderId);
        assertEq(supportWeight, 11);
        assertEq(opposeWeight, 0);
    }

    function testT134B_thresholdRequiresMinimumSupport() public {
        _activateTokenGovManager();
        address whale = address(0xABCD);
        protocol.setGovVotes(token, senderOwner, 29);
        protocol.setGovVotes(token, voter2, 1);
        protocol.setGovVotes(token, whale, 9969);

        vm.prank(senderOwner);
        deny.voteDenyAddress(groupId, senderOwner);
        assertTrue(!deny.isDenied(groupId, senderId, senderOwner));

        vm.prank(voter2);
        deny.voteDenyAddress(groupId, senderOwner);
        assertTrue(deny.isDenied(groupId, senderId, senderOwner));
    }

    function testT134C_totalWeightFailureDoesNotSilentlyAllow() public {
        MissingTotalDenyVoteWeightSource source = new MissingTotalDenyVoteWeightSource(1);
        uint256 managedGroupId = groupNft.mint(address(source));
        assertTrue(!deny.isDenied(managedGroupId, senderId, senderOwner));

        vm.prank(senderOwner);
        vm.expectRevert(GovVotedDenySource.DenyVoteWeightSourceUnavailable.selector);
        deny.voteDenyAddress(managedGroupId, senderOwner);
    }

    function testT134D_thresholdIsSettledOnWriteAndRefreshNotEveryRead() public {
        _activateTokenGovManager();
        address whale = address(0xABCD);
        protocol.setGovVotes(token, senderOwner, 30);

        vm.prank(senderOwner);
        deny.voteDenyAddress(groupId, senderOwner);
        assertTrue(deny.isDenied(groupId, senderId, senderOwner));

        protocol.setGovVotes(token, whale, 10000);
        assertTrue(deny.isDenied(groupId, senderId, senderOwner));

        deny.revalidateDenyAddressVote(groupId, senderOwner, senderOwner);
        assertTrue(!deny.isDenied(groupId, senderId, senderOwner));
    }

    function testT135_targetAndVoterPagination() public {
        _activateTokenGovManager();
        protocol.setGovVotes(token, senderOwner, 2);
        protocol.setGovVotes(token, voter2, 4);

        vm.prank(senderOwner);
        deny.voteDenyAddress(groupId, senderOwner);
        vm.prank(senderOwner);
        deny.voteDenyAddress(groupId, other);
        vm.prank(voter2);
        deny.opposeDenyAddress(groupId, senderOwner);

        (
            address[] memory targetAddresses,
            uint256[] memory supportWeights,
            uint256[] memory opposeWeights,
            uint256[] memory voterCounts
        ) = deny.addressDenyTargets(groupId, 0, 10);
        assertEq(targetAddresses.length, 2);
        assertEq(supportWeights.length, 2);
        assertEq(opposeWeights.length, 2);
        assertEq(voterCounts.length, 2);
        assertEq(targetAddresses[0], senderOwner);
        assertEq(supportWeights[0], 2);
        assertEq(opposeWeights[0], 4);
        assertEq(voterCounts[0], 2);

        (address[] memory voters, bool[] memory supportDenies, uint256[] memory settledWeights) =
            deny.addressDenyVoters(groupId, senderOwner, 0, 10);
        assertEq(voters.length, 2);
        assertEq(supportDenies.length, 2);
        assertEq(settledWeights.length, 2);
        assertEq(voters[0], senderOwner);
        assertTrue(supportDenies[0]);
        assertEq(settledWeights[0], 2);
        assertEq(voters[1], voter2);
        assertTrue(!supportDenies[1]);
        assertEq(settledWeights[1], 4);
    }

    function testT136_senderIdVoteResolvesOwnerAndUpdatesAddressAndNftTargetsTogether() public {
        _activateTokenGovManager();
        protocol.setGovVotes(token, senderOwner, 7);

        vm.prank(senderOwner);
        deny.voteDenySenderBySenderId(groupId, senderId);

        (uint256 addressSupport, uint256 addressOppose) = deny.addressDenyTallyOf(groupId, senderOwner);
        (uint256 groupSupport, uint256 groupOppose) = deny.senderIdDenyTallyOf(groupId, senderId);
        assertEq(addressSupport, 7);
        assertEq(addressOppose, 0);
        assertEq(groupSupport, 7);
        assertEq(groupOppose, 0);
        assertTrue(deny.isDenied(groupId, senderId, senderOwner));
        assertEq(deny.stateVersion(groupId), 1);

        protocol.setGovVotes(token, senderOwner, 4);
        deny.revalidateDenySenderVoteBySenderId(groupId, senderId, senderOwner);

        (addressSupport, addressOppose) = deny.addressDenyTallyOf(groupId, senderOwner);
        (groupSupport, groupOppose) = deny.senderIdDenyTallyOf(groupId, senderId);
        assertEq(addressSupport, 4);
        assertEq(addressOppose, 0);
        assertEq(groupSupport, 4);
        assertEq(groupOppose, 0);
        assertEq(deny.stateVersion(groupId), 2);

        vm.prank(senderOwner);
        deny.opposeDenySenderBySenderId(groupId, senderId);

        (addressSupport, addressOppose) = deny.addressDenyTallyOf(groupId, senderOwner);
        (groupSupport, groupOppose) = deny.senderIdDenyTallyOf(groupId, senderId);
        assertEq(addressSupport, 0);
        assertEq(addressOppose, 4);
        assertEq(groupSupport, 0);
        assertEq(groupOppose, 4);
        assertTrue(!deny.isDenied(groupId, senderId, senderOwner));
        assertEq(deny.stateVersion(groupId), 3);

        vm.prank(senderOwner);
        deny.clearDenySenderVoteBySenderId(groupId, senderId);

        assertEq(deny.addressDenyTargetsCount(groupId), 0);
        assertEq(deny.senderIdDenyTargetsCount(groupId), 0);
        assertEq(deny.stateVersion(groupId), 4);
    }

    function testT137_senderAddressVoteUsesDefaultGroupWhenPresentAndSkipsNftWhenMissing() public {
        _activateTokenGovManager();
        protocol.setGovVotes(token, senderOwner, 7);
        protocol.setGovVotes(token, voter2, 5);

        vm.prank(senderOwner);
        groupDefaults.setDefaultGroupId(senderId);

        vm.prank(senderOwner);
        deny.voteDenySenderBySenderAddress(groupId, senderOwner);

        (uint256 addressSupport, uint256 addressOppose) = deny.addressDenyTallyOf(groupId, senderOwner);
        (uint256 groupSupport, uint256 groupOppose) = deny.senderIdDenyTallyOf(groupId, senderId);
        assertEq(addressSupport, 7);
        assertEq(addressOppose, 0);
        assertEq(groupSupport, 7);
        assertEq(groupOppose, 0);

        vm.prank(voter2);
        deny.voteDenySenderBySenderAddress(groupId, voter2);

        (addressSupport, addressOppose) = deny.addressDenyTallyOf(groupId, voter2);
        assertEq(addressSupport, 5);
        assertEq(addressOppose, 0);
        assertEq(deny.senderIdDenyTargetsCount(groupId), 1);
        assertEq(deny.stateVersion(groupId), 2);
    }

    function testT138_batchListChecksReturnIndependentCacheSlices() public {
        _activateTokenGovManager();
        protocol.setGovVotes(token, senderOwner, 7);

        vm.prank(senderOwner);
        deny.voteDenyAddress(groupId, senderOwner);

        uint256[] memory senderIds = new uint256[](2);
        senderIds[0] = senderId;
        senderIds[1] = otherGroupId;
        address[] memory senderAddresses = new address[](2);
        senderAddresses[0] = senderOwner;
        senderAddresses[1] = other;

        bool[] memory addressDenied = deny.isAddressDeniedBatch(groupId, senderAddresses);
        assertEq(addressDenied.length, 2);
        assertTrue(addressDenied[0]);
        assertTrue(!addressDenied[1]);

        bool[] memory senderIdDenied = deny.isSenderIdDeniedBatch(groupId, senderIds);
        assertEq(senderIdDenied.length, 2);
        assertTrue(!senderIdDenied[0]);
        assertTrue(!senderIdDenied[1]);

        bool[] memory senderIdExempt = deny.isSenderIdExemptBatch(groupId, senderIds);
        assertEq(senderIdExempt.length, 2);
        assertTrue(!senderIdExempt[0]);
        assertTrue(!senderIdExempt[1]);

        protocol.setGovVotes(token, voter2, 8);
        vm.prank(voter2);
        deny.opposeDenyAddress(groupId, senderOwner);

        addressDenied = deny.isAddressDeniedBatch(groupId, senderAddresses);
        assertEq(addressDenied.length, 2);
        assertTrue(!addressDenied[0]);
        assertTrue(!addressDenied[1]);
    }

    function testT139_govBatchDetailsReturnSettledDeniedAndTallies() public {
        _activateTokenGovManager();
        address whale = address(0xABCD);
        protocol.setGovVotes(token, senderOwner, 20);
        protocol.setGovVotes(token, voter2, 5);
        protocol.setGovVotes(token, whale, 10000);

        vm.prank(senderOwner);
        deny.voteDenyAddress(groupId, senderOwner);
        vm.prank(voter2);
        deny.opposeDenyAddress(groupId, senderOwner);
        vm.prank(whale);
        deny.voteDenyAddress(groupId, other);

        vm.prank(senderOwner);
        deny.voteDenySenderId(groupId, senderId);
        vm.prank(whale);
        deny.voteDenySenderId(groupId, otherGroupId);

        address[] memory targetAddresses = new address[](3);
        targetAddresses[0] = senderOwner;
        targetAddresses[1] = other;
        targetAddresses[2] = address(0x9999);

        (bool[] memory denied, uint256[] memory supportWeights, uint256[] memory opposeWeights) =
            deny.addressDenyDetailsBatch(groupId, targetAddresses);
        assertEq(denied.length, 3);
        assertTrue(!denied[0]);
        assertTrue(denied[1]);
        assertTrue(!denied[2]);
        assertEq(supportWeights[0], 20);
        assertEq(supportWeights[1], 10000);
        assertEq(supportWeights[2], 0);
        assertEq(opposeWeights[0], 5);
        assertEq(opposeWeights[1], 0);
        assertEq(opposeWeights[2], 0);

        uint256[] memory targetSenderIds = new uint256[](3);
        targetSenderIds[0] = senderId;
        targetSenderIds[1] = otherGroupId;
        targetSenderIds[2] = 999999;

        (denied, supportWeights, opposeWeights) = deny.senderIdDenyDetailsBatch(groupId, targetSenderIds);
        assertEq(denied.length, 3);
        assertTrue(!denied[0]);
        assertTrue(denied[1]);
        assertTrue(!denied[2]);
        assertEq(supportWeights[0], 20);
        assertEq(supportWeights[1], 10000);
        assertEq(supportWeights[2], 0);
        assertEq(opposeWeights[0], 0);
        assertEq(opposeWeights[1], 0);
        assertEq(opposeWeights[2], 0);
    }

    function _activateTokenGovManager() internal {
        groupId = tokenGovManager.activate(token);
    }
}
