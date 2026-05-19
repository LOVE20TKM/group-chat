// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChatErrors} from "../src/interfaces/IGroupChat.sol";
import {IGovVotedDenySource} from "../src/interfaces/sources/deny/IGovVotedDenySource.sol";

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

    function voteWeightOf(uint256, address) external view returns (uint256) {
        return _voteWeight;
    }
}

contract GovVotedDenySourceTest is GroupChatFixture {
    uint256 internal constant DENY_THRESHOLD_RATIO = 3e15;

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
        deny = new GovVotedDenySource(address(groupNft), DENY_THRESHOLD_RATIO);
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
        deny.voteBySenderAddress(groupId, senderOwner, true);

        (bool denied, uint256 supportWeight, uint256 opposeWeight) =
            deny.voteStatusBySenderAddress(groupId, senderOwner);
        assertTrue(denied);
        assertEq(supportWeight, 7);
        assertEq(opposeWeight, 0);
        assertTrue(deny.isDenied(groupId, senderId, senderOwner));

        (bool allowed, bytes4 reasonCode) = _canPost(groupId, senderId, senderOwner);
        assertTrue(!allowed);
        assertEq(bytes32(reasonCode), bytes32(IGroupChatErrors.DenyRejected.selector));

        vm.prank(voter2);
        deny.voteBySenderAddress(groupId, senderOwner, false);

        (denied, supportWeight, opposeWeight) = deny.voteStatusBySenderAddress(groupId, senderOwner);
        assertTrue(denied);
        assertEq(supportWeight, 7);
        assertEq(opposeWeight, 5);
        assertTrue(deny.isDenied(groupId, senderId, senderOwner));

        protocol.setGovVotes(token, voter2, 8);
        vm.prank(voter2);
        deny.voteBySenderAddress(groupId, senderOwner, false);

        (denied, supportWeight, opposeWeight) = deny.voteStatusBySenderAddress(groupId, senderOwner);
        assertTrue(!denied);
        assertEq(supportWeight, 7);
        assertEq(opposeWeight, 8);
        assertTrue(!deny.isDenied(groupId, senderId, senderOwner));
    }

    function testT131_clearAndRefreshUpdateVoterWeightsAndRemoveVoteAtZero() public {
        _activateTokenGovManager();
        protocol.setGovVotes(token, senderOwner, 9);

        vm.prank(senderOwner);
        deny.voteBySenderId(groupId, senderId, true);
        assertTrue(deny.isDenied(groupId, senderId, senderOwner));
        assertEq(deny.votedSenderIdsCount(groupId), 1);
        assertEq(deny.stateVersion(groupId), 1);

        protocol.setGovVotes(token, senderOwner, 4);
        deny.refreshVoteBySenderId(groupId, senderId, senderOwner);
        uint256[] memory senderIds = new uint256[](1);
        senderIds[0] = senderId;
        (uint256[] memory supportWeights, uint256[] memory opposeWeights) =
            deny.voteWeightsBySenderIdsByVoter(groupId, senderIds, senderOwner);
        assertEq(supportWeights.length, 1);
        assertEq(opposeWeights.length, 1);
        assertEq(supportWeights[0], 4);
        assertEq(opposeWeights[0], 0);
        assertEq(deny.stateVersion(groupId), 2);

        protocol.setGovVotes(token, senderOwner, 0);
        deny.refreshVoteBySenderId(groupId, senderId, senderOwner);
        (supportWeights, opposeWeights) = deny.voteWeightsBySenderIdsByVoter(groupId, senderIds, senderOwner);
        assertEq(supportWeights[0], 0);
        assertEq(opposeWeights[0], 0);
        assertEq(deny.votedSenderIdsCount(groupId), 0);
        assertEq(deny.stateVersion(groupId), 3);

        protocol.setGovVotes(token, senderOwner, 6);
        vm.prank(senderOwner);
        deny.voteBySenderId(groupId, senderId, true);
        vm.prank(senderOwner);
        deny.clearVoteBySenderId(groupId, senderId);
        assertEq(deny.votedSenderIdsCount(groupId), 0);
        assertEq(deny.stateVersion(groupId), 5);
    }

    function testT132_zeroWeightUnchangedAndMissingVoteRevert() public {
        _activateTokenGovManager();

        vm.prank(senderOwner);
        vm.expectRevert(IGovVotedDenySource.VoteWeightZero.selector);
        deny.voteBySenderAddress(groupId, senderOwner, true);

        protocol.setGovVotes(token, senderOwner, 3);
        vm.prank(senderOwner);
        deny.voteBySenderAddress(groupId, senderOwner, true);

        vm.prank(senderOwner);
        vm.expectRevert(IGovVotedDenySource.VoteUnchanged.selector);
        deny.voteBySenderAddress(groupId, senderOwner, true);

        vm.expectRevert(IGovVotedDenySource.VoteNotFound.selector);
        deny.refreshVoteBySenderAddress(groupId, other, senderOwner);

        vm.prank(voter2);
        vm.expectRevert(IGovVotedDenySource.VoteNotFound.selector);
        deny.clearVoteBySenderAddress(groupId, senderOwner);

        vm.prank(senderOwner);
        vm.expectRevert(IGovVotedDenySource.TargetSenderIdZero.selector);
        deny.voteBySender(groupId, 0, senderOwner, true);

        vm.prank(senderOwner);
        vm.expectRevert(IGovVotedDenySource.TargetAddressZero.selector);
        deny.voteBySender(groupId, senderId, address(0), true);
    }

    function testT133_readerDegradesWhenSourceUnavailable() public {
        assertEq(deny.votedSenderAddressesCount(groupId), 0);
        assertEq(deny.votedSenderIdsCount(groupId), 0);
        assertTrue(!deny.isDenied(groupId, senderId, senderOwner));
        (bool denied, uint256 supportWeight, uint256 opposeWeight) =
            deny.voteStatusBySenderAddress(groupId, senderOwner);
        assertTrue(!denied);
        assertEq(supportWeight, 0);
        assertEq(opposeWeight, 0);
        address[] memory senderAddresses = new address[](1);
        senderAddresses[0] = senderOwner;
        (uint256[] memory voterSupportWeights, uint256[] memory voterOpposeWeights) =
            deny.voteWeightsBySenderAddressesByVoter(groupId, senderAddresses, senderOwner);
        assertEq(voterSupportWeights.length, 1);
        assertEq(voterOpposeWeights.length, 1);
        assertEq(voterSupportWeights[0], 0);
        assertEq(voterOpposeWeights[0], 0);
        address[] memory voters;
        (voters, voterSupportWeights, voterOpposeWeights) = deny.votersBySenderAddress(groupId, senderOwner, 0, 10);
        assertEq(voters.length, 0);
        assertEq(voterSupportWeights.length, 0);
        assertEq(voterOpposeWeights.length, 0);

        vm.prank(senderOwner);
        vm.expectRevert(IGovVotedDenySource.DenyVoteWeightSourceUnavailable.selector);
        deny.voteBySenderAddress(groupId, senderOwner, true);
    }

    function testT134_actionGovManagerActsAsWeightSource() public {
        protocol.setCurrentRound(7);
        protocol.setActionsCount(token, 43);
        groupId = actionGovManager.activate(token, 42);

        protocol.setActionVotes(token, 7, senderOwner, 42, 11);
        vm.prank(senderOwner);
        deny.voteBySenderId(groupId, senderId, true);

        (bool denied, uint256 supportWeight, uint256 opposeWeight) = deny.voteStatusBySenderId(groupId, senderId);
        assertTrue(!denied);
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
        deny.voteBySenderAddress(groupId, senderOwner, true);
        assertTrue(!deny.isDenied(groupId, senderId, senderOwner));

        vm.prank(voter2);
        deny.voteBySenderAddress(groupId, senderOwner, true);
        assertTrue(deny.isDenied(groupId, senderId, senderOwner));
    }

    function testT134C_totalWeightFailureDoesNotSilentlyAllow() public {
        MissingTotalDenyVoteWeightSource source = new MissingTotalDenyVoteWeightSource(1);
        uint256 managedGroupId = groupNft.mint(address(source));
        assertTrue(!deny.isDenied(managedGroupId, senderId, senderOwner));

        vm.prank(senderOwner);
        vm.expectRevert(IGovVotedDenySource.DenyVoteWeightSourceUnavailable.selector);
        deny.voteBySenderAddress(managedGroupId, senderOwner, true);
    }

    function testT134D_thresholdIsSettledOnWriteAndRefreshNotEveryRead() public {
        _activateTokenGovManager();
        address whale = address(0xABCD);
        protocol.setGovVotes(token, senderOwner, 30);

        vm.prank(senderOwner);
        deny.voteBySenderAddress(groupId, senderOwner, true);
        assertTrue(deny.isDenied(groupId, senderId, senderOwner));

        protocol.setGovVotes(token, whale, 10000);
        assertTrue(deny.isDenied(groupId, senderId, senderOwner));

        deny.refreshVoteBySenderAddress(groupId, senderOwner, senderOwner);
        assertTrue(!deny.isDenied(groupId, senderId, senderOwner));
    }

    function testT135_targetAndVoterPagination() public {
        _activateTokenGovManager();
        protocol.setGovVotes(token, senderOwner, 2);
        protocol.setGovVotes(token, voter2, 4);

        vm.prank(senderOwner);
        deny.voteBySenderAddress(groupId, senderOwner, true);
        vm.prank(senderOwner);
        deny.voteBySenderAddress(groupId, other, true);
        vm.prank(voter2);
        deny.voteBySenderAddress(groupId, senderOwner, false);

        (
            address[] memory senderAddresses,
            uint256[] memory supportWeights,
            uint256[] memory opposeWeights,
            uint256[] memory voterCounts
        ) = deny.votedSenderAddresses(groupId, 0, 10);
        assertEq(senderAddresses.length, 2);
        assertEq(supportWeights.length, 2);
        assertEq(opposeWeights.length, 2);
        assertEq(voterCounts.length, 2);
        assertEq(senderAddresses[0], senderOwner);
        assertEq(supportWeights[0], 2);
        assertEq(opposeWeights[0], 4);
        assertEq(voterCounts[0], 2);

        (address[] memory voters, uint256[] memory voterSupportWeights, uint256[] memory voterOpposeWeights) =
            deny.votersBySenderAddress(groupId, senderOwner, 0, 10);
        assertEq(voters.length, 2);
        assertEq(voterSupportWeights.length, 2);
        assertEq(voterOpposeWeights.length, 2);
        assertEq(voters[0], senderOwner);
        assertEq(voterSupportWeights[0], 2);
        assertEq(voterOpposeWeights[0], 0);
        assertEq(voters[1], voter2);
        assertEq(voterSupportWeights[1], 0);
        assertEq(voterOpposeWeights[1], 4);

        address[] memory queriedSenderAddresses = new address[](3);
        queriedSenderAddresses[0] = senderOwner;
        queriedSenderAddresses[1] = other;
        queriedSenderAddresses[2] = address(0x9999);
        (voterSupportWeights, voterOpposeWeights) =
            deny.voteWeightsBySenderAddressesByVoter(groupId, queriedSenderAddresses, senderOwner);
        assertEq(voterSupportWeights.length, 3);
        assertEq(voterOpposeWeights.length, 3);
        assertEq(voterSupportWeights[0], 2);
        assertEq(voterOpposeWeights[0], 0);
        assertEq(voterSupportWeights[1], 2);
        assertEq(voterOpposeWeights[1], 0);
        assertEq(voterSupportWeights[2], 0);
        assertEq(voterOpposeWeights[2], 0);
    }

    function testT136_senderVoteUsesExplicitSnapshotAndSurvivesNftTransfer() public {
        _activateTokenGovManager();
        protocol.setGovVotes(token, senderOwner, 7);
        groupNft.transferFrom(senderOwner, other, senderId);

        vm.prank(senderOwner);
        deny.voteBySender(groupId, senderId, senderOwner, true);

        (bool addressDenied, uint256 addressSupport, uint256 addressOppose) =
            deny.voteStatusBySenderAddress(groupId, senderOwner);
        (bool senderIdDenied, uint256 groupSupport, uint256 groupOppose) = deny.voteStatusBySenderId(groupId, senderId);
        assertTrue(addressDenied);
        assertTrue(senderIdDenied);
        assertEq(addressSupport, 7);
        assertEq(addressOppose, 0);
        assertEq(groupSupport, 7);
        assertEq(groupOppose, 0);
        assertEq(groupNft.ownerOf(senderId), other);
        assertTrue(deny.isDenied(groupId, senderId, senderOwner));
        assertEq(deny.stateVersion(groupId), 1);

        protocol.setGovVotes(token, senderOwner, 4);
        deny.refreshVoteBySender(groupId, senderId, senderOwner, senderOwner);

        (addressDenied, addressSupport, addressOppose) = deny.voteStatusBySenderAddress(groupId, senderOwner);
        (senderIdDenied, groupSupport, groupOppose) = deny.voteStatusBySenderId(groupId, senderId);
        assertTrue(addressDenied);
        assertTrue(senderIdDenied);
        assertEq(addressSupport, 4);
        assertEq(addressOppose, 0);
        assertEq(groupSupport, 4);
        assertEq(groupOppose, 0);
        assertEq(deny.stateVersion(groupId), 2);

        vm.prank(senderOwner);
        deny.voteBySender(groupId, senderId, senderOwner, false);

        (addressDenied, addressSupport, addressOppose) = deny.voteStatusBySenderAddress(groupId, senderOwner);
        (senderIdDenied, groupSupport, groupOppose) = deny.voteStatusBySenderId(groupId, senderId);
        assertTrue(!addressDenied);
        assertTrue(!senderIdDenied);
        assertEq(addressSupport, 0);
        assertEq(addressOppose, 4);
        assertEq(groupSupport, 0);
        assertEq(groupOppose, 4);
        assertTrue(!deny.isDenied(groupId, senderId, senderOwner));
        assertEq(deny.stateVersion(groupId), 3);

        vm.prank(senderOwner);
        deny.clearVoteBySender(groupId, senderId, senderOwner);

        assertEq(deny.votedSenderAddressesCount(groupId), 0);
        assertEq(deny.votedSenderIdsCount(groupId), 0);
        assertEq(deny.stateVersion(groupId), 4);
    }

    function testT137_senderAddressVoteOnlyTouchesAddressTarget() public {
        _activateTokenGovManager();
        protocol.setGovVotes(token, senderOwner, 7);
        protocol.setGovVotes(token, voter2, 5);
        groupNft.transferFrom(senderOwner, other, senderId);

        vm.prank(senderOwner);
        deny.voteBySenderAddress(groupId, senderOwner, true);

        (bool addressDenied, uint256 addressSupport, uint256 addressOppose) =
            deny.voteStatusBySenderAddress(groupId, senderOwner);
        (bool senderIdDenied, uint256 groupSupport, uint256 groupOppose) = deny.voteStatusBySenderId(groupId, senderId);
        assertTrue(addressDenied);
        assertTrue(!senderIdDenied);
        assertEq(addressSupport, 7);
        assertEq(addressOppose, 0);
        assertEq(groupSupport, 0);
        assertEq(groupOppose, 0);
        assertEq(deny.votedSenderIdsCount(groupId), 0);

        vm.prank(voter2);
        deny.voteBySenderAddress(groupId, voter2, true);

        (addressDenied, addressSupport, addressOppose) = deny.voteStatusBySenderAddress(groupId, voter2);
        assertTrue(addressDenied);
        assertEq(addressSupport, 5);
        assertEq(addressOppose, 0);
        assertEq(deny.votedSenderIdsCount(groupId), 0);
        assertEq(deny.stateVersion(groupId), 2);
    }

    function testT138_batchListChecksReturnIndependentCacheSlices() public {
        _activateTokenGovManager();
        protocol.setGovVotes(token, senderOwner, 7);

        vm.prank(senderOwner);
        deny.voteBySenderAddress(groupId, senderOwner, true);

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

        protocol.setGovVotes(token, voter2, 8);
        vm.prank(voter2);
        deny.voteBySenderAddress(groupId, senderOwner, false);

        addressDenied = deny.isAddressDeniedBatch(groupId, senderAddresses);
        assertEq(addressDenied.length, 2);
        assertTrue(!addressDenied[0]);
        assertTrue(!addressDenied[1]);
    }

    function testT139_govVoteStatusReturnsSettledDeniedAndTallies() public {
        _activateTokenGovManager();
        address whale = address(0xABCD);
        protocol.setGovVotes(token, senderOwner, 20);
        protocol.setGovVotes(token, voter2, 5);
        protocol.setGovVotes(token, whale, 10000);

        vm.prank(senderOwner);
        deny.voteBySenderAddress(groupId, senderOwner, true);
        vm.prank(voter2);
        deny.voteBySenderAddress(groupId, senderOwner, false);
        vm.prank(whale);
        deny.voteBySenderAddress(groupId, other, true);

        vm.prank(senderOwner);
        deny.voteBySenderId(groupId, senderId, true);
        vm.prank(whale);
        deny.voteBySenderId(groupId, otherGroupId, true);

        address[] memory senderAddresses = new address[](3);
        senderAddresses[0] = senderOwner;
        senderAddresses[1] = other;
        senderAddresses[2] = address(0x9999);

        (bool[] memory denied, uint256[] memory supportWeights, uint256[] memory opposeWeights) =
            deny.voteStatusBySenderAddresses(groupId, senderAddresses);
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

        uint256[] memory senderIds = new uint256[](3);
        senderIds[0] = senderId;
        senderIds[1] = otherGroupId;
        senderIds[2] = 999999;

        (denied, supportWeights, opposeWeights) = deny.voteStatusBySenderIds(groupId, senderIds);
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
