// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChatErrors} from "../src/interfaces/IGroupChat.sol";
import {TokenGovGroupChatManager} from "../src/managers/TokenGovGroupChatManager.sol";
import {TokenActionGovGroupChatManager} from "../src/managers/TokenActionGovGroupChatManager.sol";
import {GovVotedDenySource} from "../src/sources/deny/GovVotedDenySource.sol";
import {MockLOVE20Protocols} from "./mocks/MockLOVE20Protocols.sol";
import {GroupChatFixture} from "./utils/GroupChatFixture.sol";

contract GovVotedDenySourceTest is GroupChatFixture {
    MockLOVE20Protocols internal protocol;
    GovVotedDenySource internal deny;
    TokenGovGroupChatManager internal tokenGovManager;
    TokenActionGovGroupChatManager internal actionGovManager;
    address internal token;
    address internal voter2 = address(0xB0B2);
    uint256 internal voter2GroupId;

    function setUp() public override {
        super.setUp();
        protocol = new MockLOVE20Protocols();
        token = address(protocol);
        deny = new GovVotedDenySource(address(groupNft), address(groupDefaults));
        tokenGovManager =
            new TokenGovGroupChatManager(address(chat), address(deny), address(0), address(0), address(protocol));
        actionGovManager =
            new TokenActionGovGroupChatManager(address(chat), address(deny), address(0), address(0), address(protocol));
        voter2GroupId = groupNft.mint(voter2);
    }

    function testT130_tokenGovVoteAndOpposeAffectIsDeniedAndGroupChat() public {
        _activateTokenGovManager();
        protocol.setGovVotes(token, senderOwner, 7);
        protocol.setGovVotes(token, voter2, 5);

        vm.prank(senderOwner);
        deny.voteDenyAddress(chatGroupId, senderOwner);

        (uint256 supportWeight, uint256 opposeWeight) = deny.addressDenyTallyOf(chatGroupId, senderOwner);
        assertEq(supportWeight, 7);
        assertEq(opposeWeight, 0);
        assertTrue(deny.isDenied(chatGroupId, senderGroupId, senderOwner));

        (bool allowed, bytes4 reasonCode) = chat.canPostStatus(chatGroupId, senderGroupId, senderOwner);
        assertTrue(!allowed);
        assertEq(bytes32(reasonCode), bytes32(IGroupChatErrors.DenyRejected.selector));

        vm.prank(voter2);
        deny.opposeDenyAddress(chatGroupId, senderOwner);

        (supportWeight, opposeWeight) = deny.addressDenyTallyOf(chatGroupId, senderOwner);
        assertEq(supportWeight, 7);
        assertEq(opposeWeight, 5);
        assertTrue(deny.isDenied(chatGroupId, senderGroupId, senderOwner));

        protocol.setGovVotes(token, voter2, 8);
        vm.prank(voter2);
        deny.opposeDenyAddress(chatGroupId, senderOwner);

        (supportWeight, opposeWeight) = deny.addressDenyTallyOf(chatGroupId, senderOwner);
        assertEq(supportWeight, 7);
        assertEq(opposeWeight, 8);
        assertTrue(!deny.isDenied(chatGroupId, senderGroupId, senderOwner));
    }

    function testT131_clearAndRevalidateUpdateSettledWeightAndRemoveVoteAtZero() public {
        _activateTokenGovManager();
        protocol.setGovVotes(token, senderOwner, 9);

        vm.prank(senderOwner);
        deny.voteDenySenderGroupId(chatGroupId, senderGroupId);
        assertTrue(deny.isDenied(chatGroupId, senderGroupId, senderOwner));
        assertEq(deny.senderGroupIdDenyTargetsCount(chatGroupId), 1);
        assertEq(deny.stateVersion(chatGroupId), 1);

        protocol.setGovVotes(token, senderOwner, 4);
        deny.revalidateDenySenderGroupIdVote(chatGroupId, senderGroupId, senderOwner);
        (bool supportDeny, uint256 settledWeight) =
            deny.senderGroupIdDenyVoteOf(chatGroupId, senderGroupId, senderOwner);
        assertTrue(supportDeny);
        assertEq(settledWeight, 4);
        assertEq(deny.stateVersion(chatGroupId), 2);

        protocol.setGovVotes(token, senderOwner, 0);
        deny.revalidateDenySenderGroupIdVote(chatGroupId, senderGroupId, senderOwner);
        (supportDeny, settledWeight) = deny.senderGroupIdDenyVoteOf(chatGroupId, senderGroupId, senderOwner);
        assertTrue(!supportDeny);
        assertEq(settledWeight, 0);
        assertEq(deny.senderGroupIdDenyTargetsCount(chatGroupId), 0);
        assertEq(deny.stateVersion(chatGroupId), 3);

        protocol.setGovVotes(token, senderOwner, 6);
        vm.prank(senderOwner);
        deny.voteDenySenderGroupId(chatGroupId, senderGroupId);
        vm.prank(senderOwner);
        deny.clearDenySenderGroupIdVote(chatGroupId, senderGroupId);
        assertEq(deny.senderGroupIdDenyTargetsCount(chatGroupId), 0);
        assertEq(deny.stateVersion(chatGroupId), 5);
    }

    function testT132_zeroWeightUnchangedAndMissingVoteRevert() public {
        _activateTokenGovManager();

        vm.prank(senderOwner);
        vm.expectRevert(GovVotedDenySource.VoteWeightZero.selector);
        deny.voteDenyAddress(chatGroupId, senderOwner);

        protocol.setGovVotes(token, senderOwner, 3);
        vm.prank(senderOwner);
        deny.voteDenyAddress(chatGroupId, senderOwner);

        vm.prank(senderOwner);
        vm.expectRevert(GovVotedDenySource.VoteUnchanged.selector);
        deny.voteDenyAddress(chatGroupId, senderOwner);

        vm.expectRevert(GovVotedDenySource.VoteNotFound.selector);
        deny.revalidateDenyAddressVote(chatGroupId, other, senderOwner);

        vm.prank(voter2);
        vm.expectRevert(GovVotedDenySource.VoteNotFound.selector);
        deny.clearDenyAddressVote(chatGroupId, senderOwner);
    }

    function testT133_readerDegradesWhenSourceUnavailable() public {
        assertEq(deny.addressDenyTargetsCount(chatGroupId), 0);
        assertEq(deny.senderGroupIdDenyTargetsCount(chatGroupId), 0);
        assertTrue(!deny.isDenied(chatGroupId, senderGroupId, senderOwner));
        (uint256 supportWeight, uint256 opposeWeight) = deny.addressDenyTallyOf(chatGroupId, senderOwner);
        assertEq(supportWeight, 0);
        assertEq(opposeWeight, 0);
        (bool supportDeny, uint256 settledWeight) = deny.addressDenyVoteOf(chatGroupId, senderOwner, senderOwner);
        assertTrue(!supportDeny);
        assertEq(settledWeight, 0);
        address[] memory voters;
        bool[] memory supportDenies;
        uint256[] memory settledWeights;
        (voters, supportDenies, settledWeights) = deny.addressDenyVoters(chatGroupId, senderOwner, 0, 10);
        assertEq(voters.length, 0);
        assertEq(supportDenies.length, 0);
        assertEq(settledWeights.length, 0);

        vm.prank(senderOwner);
        vm.expectRevert(GovVotedDenySource.DenyVoteWeightSourceUnavailable.selector);
        deny.voteDenyAddress(chatGroupId, senderOwner);
    }

    function testT134_actionGovManagerActsAsWeightSource() public {
        groupNft.transferFrom(chatOwner, address(actionGovManager), chatGroupId);
        protocol.setCurrentRound(7);
        actionGovManager.activate(chatGroupId, token, 42, 3);

        protocol.setActionVotes(token, 7, senderOwner, 42, 11);
        vm.prank(senderOwner);
        deny.voteDenySenderGroupId(chatGroupId, senderGroupId);

        (uint256 supportWeight, uint256 opposeWeight) = deny.senderGroupIdDenyTallyOf(chatGroupId, senderGroupId);
        assertEq(supportWeight, 11);
        assertEq(opposeWeight, 0);
    }

    function testT135_targetAndVoterPagination() public {
        _activateTokenGovManager();
        protocol.setGovVotes(token, senderOwner, 2);
        protocol.setGovVotes(token, voter2, 4);

        vm.prank(senderOwner);
        deny.voteDenyAddress(chatGroupId, senderOwner);
        vm.prank(senderOwner);
        deny.voteDenyAddress(chatGroupId, other);
        vm.prank(voter2);
        deny.opposeDenyAddress(chatGroupId, senderOwner);

        (
            address[] memory targetAddresses,
            uint256[] memory supportWeights,
            uint256[] memory opposeWeights,
            uint256[] memory voterCounts
        ) = deny.addressDenyTargets(chatGroupId, 0, 10);
        assertEq(targetAddresses.length, 2);
        assertEq(supportWeights.length, 2);
        assertEq(opposeWeights.length, 2);
        assertEq(voterCounts.length, 2);
        assertEq(targetAddresses[0], senderOwner);
        assertEq(supportWeights[0], 2);
        assertEq(opposeWeights[0], 4);
        assertEq(voterCounts[0], 2);

        (address[] memory voters, bool[] memory supportDenies, uint256[] memory settledWeights) =
            deny.addressDenyVoters(chatGroupId, senderOwner, 0, 10);
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

    function testT136_senderGroupIdVoteResolvesOwnerAndUpdatesAddressAndNftTargetsTogether() public {
        _activateTokenGovManager();
        protocol.setGovVotes(token, senderOwner, 7);

        vm.prank(senderOwner);
        deny.voteDenySenderBySenderGroupId(chatGroupId, senderGroupId);

        (uint256 addressSupport, uint256 addressOppose) = deny.addressDenyTallyOf(chatGroupId, senderOwner);
        (uint256 groupSupport, uint256 groupOppose) = deny.senderGroupIdDenyTallyOf(chatGroupId, senderGroupId);
        assertEq(addressSupport, 7);
        assertEq(addressOppose, 0);
        assertEq(groupSupport, 7);
        assertEq(groupOppose, 0);
        assertTrue(deny.isDenied(chatGroupId, senderGroupId, senderOwner));
        assertEq(deny.stateVersion(chatGroupId), 1);

        protocol.setGovVotes(token, senderOwner, 4);
        deny.revalidateDenySenderVoteBySenderGroupId(chatGroupId, senderGroupId, senderOwner);

        (addressSupport, addressOppose) = deny.addressDenyTallyOf(chatGroupId, senderOwner);
        (groupSupport, groupOppose) = deny.senderGroupIdDenyTallyOf(chatGroupId, senderGroupId);
        assertEq(addressSupport, 4);
        assertEq(addressOppose, 0);
        assertEq(groupSupport, 4);
        assertEq(groupOppose, 0);
        assertEq(deny.stateVersion(chatGroupId), 2);

        vm.prank(senderOwner);
        deny.opposeDenySenderBySenderGroupId(chatGroupId, senderGroupId);

        (addressSupport, addressOppose) = deny.addressDenyTallyOf(chatGroupId, senderOwner);
        (groupSupport, groupOppose) = deny.senderGroupIdDenyTallyOf(chatGroupId, senderGroupId);
        assertEq(addressSupport, 0);
        assertEq(addressOppose, 4);
        assertEq(groupSupport, 0);
        assertEq(groupOppose, 4);
        assertTrue(!deny.isDenied(chatGroupId, senderGroupId, senderOwner));
        assertEq(deny.stateVersion(chatGroupId), 3);

        vm.prank(senderOwner);
        deny.clearDenySenderVoteBySenderGroupId(chatGroupId, senderGroupId);

        assertEq(deny.addressDenyTargetsCount(chatGroupId), 0);
        assertEq(deny.senderGroupIdDenyTargetsCount(chatGroupId), 0);
        assertEq(deny.stateVersion(chatGroupId), 4);
    }

    function testT137_senderAddressVoteUsesDefaultGroupWhenPresentAndSkipsNftWhenMissing() public {
        _activateTokenGovManager();
        protocol.setGovVotes(token, senderOwner, 7);
        protocol.setGovVotes(token, voter2, 5);

        vm.prank(senderOwner);
        groupDefaults.setDefaultGroupId(senderGroupId);

        vm.prank(senderOwner);
        deny.voteDenySenderBySenderAddress(chatGroupId, senderOwner);

        (uint256 addressSupport, uint256 addressOppose) = deny.addressDenyTallyOf(chatGroupId, senderOwner);
        (uint256 groupSupport, uint256 groupOppose) = deny.senderGroupIdDenyTallyOf(chatGroupId, senderGroupId);
        assertEq(addressSupport, 7);
        assertEq(addressOppose, 0);
        assertEq(groupSupport, 7);
        assertEq(groupOppose, 0);

        vm.prank(voter2);
        deny.voteDenySenderBySenderAddress(chatGroupId, voter2);

        (addressSupport, addressOppose) = deny.addressDenyTallyOf(chatGroupId, voter2);
        assertEq(addressSupport, 5);
        assertEq(addressOppose, 0);
        assertEq(deny.senderGroupIdDenyTargetsCount(chatGroupId), 1);
        assertEq(deny.stateVersion(chatGroupId), 2);
    }

    function _activateTokenGovManager() internal {
        groupNft.transferFrom(chatOwner, address(tokenGovManager), chatGroupId);
        tokenGovManager.activate(chatGroupId, token);
    }
}
