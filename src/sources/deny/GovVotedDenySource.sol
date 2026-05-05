// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IDenyVoteWeightSource} from "../../interfaces/IDenyVoteWeightSource.sol";
import {IGroupDefaults} from "../../interfaces/IGroupDefaults.sol";
import {ILOVE20Group} from "../../interfaces/ILOVE20Group.sol";
import {IPostDenySource} from "../../interfaces/IPostDenySource.sol";

contract GovVotedDenySource is IPostDenySource {
    error GovVotedDenySourceAddressHasNoCode();
    error DenyVoteWeightSourceUnavailable();
    error GroupNotExist();
    error TargetAddressZero();
    error TargetSenderGroupIdZero();
    error VoteWeightZero();
    error VoteUnchanged();
    error VoteNotFound();

    event AddressDenyVoteSet(
        uint256 indexed chatGroupId,
        address indexed targetAddress,
        address indexed voter,
        bool hasVote,
        bool supportDeny,
        uint256 settledWeight,
        uint256 supportWeight,
        uint256 opposeWeight,
        uint256 stateVersion
    );

    event SenderGroupIdDenyVoteSet(
        uint256 indexed chatGroupId,
        uint256 indexed targetSenderGroupId,
        address indexed voter,
        bool hasVote,
        bool supportDeny,
        uint256 settledWeight,
        uint256 supportWeight,
        uint256 opposeWeight,
        uint256 stateVersion
    );

    event StateVersionChanged(uint256 indexed chatGroupId, uint256 stateVersion);

    address public immutable GROUP_ADDRESS;
    address public immutable GROUP_DEFAULTS;

    struct VoteState {
        bool hasVote;
        bool supportDeny;
        uint256 settledWeight;
    }

    struct TargetState {
        uint256 supportWeight;
        uint256 opposeWeight;
        address[] voters;
        mapping(address => uint256) voterIndexPlusOne;
        mapping(address => VoteState) votes;
    }

    struct ChatState {
        uint256 stateVersion;
        address[] addressTargets;
        mapping(address => uint256) addressTargetIndexPlusOne;
        mapping(address => TargetState) addressTargetStates;
        uint256[] senderGroupIdTargets;
        mapping(uint256 => uint256) senderGroupIdTargetIndexPlusOne;
        mapping(uint256 => TargetState) senderGroupIdTargetStates;
    }

    mapping(uint256 => ChatState) internal _states;

    constructor(address groupAddress_, address groupDefaults_) {
        if (groupAddress_.code.length == 0) revert GovVotedDenySourceAddressHasNoCode();
        if (groupDefaults_.code.length == 0) revert GovVotedDenySourceAddressHasNoCode();
        GROUP_ADDRESS = groupAddress_;
        GROUP_DEFAULTS = groupDefaults_;
    }

    function voteDenyAddress(uint256 chatGroupId, address targetAddress) external {
        _setAddressVote(chatGroupId, targetAddress, msg.sender, true);
    }

    function opposeDenyAddress(uint256 chatGroupId, address targetAddress) external {
        _setAddressVote(chatGroupId, targetAddress, msg.sender, false);
    }

    function clearDenyAddressVote(uint256 chatGroupId, address targetAddress) external {
        _clearAddressVote(chatGroupId, targetAddress, msg.sender);
    }

    function revalidateDenyAddressVote(uint256 chatGroupId, address targetAddress, address voter) external {
        _revalidateAddressVote(chatGroupId, targetAddress, voter);
    }

    function voteDenySenderGroupId(uint256 chatGroupId, uint256 targetSenderGroupId) external {
        _setSenderGroupIdVote(chatGroupId, targetSenderGroupId, msg.sender, true);
    }

    function opposeDenySenderGroupId(uint256 chatGroupId, uint256 targetSenderGroupId) external {
        _setSenderGroupIdVote(chatGroupId, targetSenderGroupId, msg.sender, false);
    }

    function clearDenySenderGroupIdVote(uint256 chatGroupId, uint256 targetSenderGroupId) external {
        _clearSenderGroupIdVote(chatGroupId, targetSenderGroupId, msg.sender);
    }

    function revalidateDenySenderGroupIdVote(uint256 chatGroupId, uint256 targetSenderGroupId, address voter)
        external
    {
        _revalidateSenderGroupIdVote(chatGroupId, targetSenderGroupId, voter);
    }

    function voteDenySenderBySenderGroupId(uint256 chatGroupId, uint256 targetSenderGroupId) external {
        address targetAddress = _ownerOfOrRevert(targetSenderGroupId);
        _setSenderVote(chatGroupId, targetSenderGroupId, targetAddress, msg.sender, true);
    }

    function opposeDenySenderBySenderGroupId(uint256 chatGroupId, uint256 targetSenderGroupId) external {
        address targetAddress = _ownerOfOrRevert(targetSenderGroupId);
        _setSenderVote(chatGroupId, targetSenderGroupId, targetAddress, msg.sender, false);
    }

    function clearDenySenderVoteBySenderGroupId(uint256 chatGroupId, uint256 targetSenderGroupId) external {
        address targetAddress = _ownerOfOrRevert(targetSenderGroupId);
        _clearSenderVote(chatGroupId, targetSenderGroupId, targetAddress, msg.sender);
    }

    function revalidateDenySenderVoteBySenderGroupId(uint256 chatGroupId, uint256 targetSenderGroupId, address voter)
        external
    {
        address targetAddress = _ownerOfOrRevert(targetSenderGroupId);
        _revalidateSenderVote(chatGroupId, targetSenderGroupId, targetAddress, voter);
    }

    function voteDenySenderBySenderAddress(uint256 chatGroupId, address targetAddress) external {
        _setSenderAddressVote(chatGroupId, targetAddress, msg.sender, true);
    }

    function opposeDenySenderBySenderAddress(uint256 chatGroupId, address targetAddress) external {
        _setSenderAddressVote(chatGroupId, targetAddress, msg.sender, false);
    }

    function clearDenySenderVoteBySenderAddress(uint256 chatGroupId, address targetAddress) external {
        _clearSenderAddressVote(chatGroupId, targetAddress, msg.sender);
    }

    function revalidateDenySenderVoteBySenderAddress(uint256 chatGroupId, address targetAddress, address voter)
        external
    {
        _revalidateSenderAddressVote(chatGroupId, targetAddress, voter);
    }

    function addressDenyVoteOf(uint256 chatGroupId, address targetAddress, address voter)
        external
        view
        returns (bool hasVote, bool supportDeny, uint256 settledWeight)
    {
        if (!_sourceHasCode(chatGroupId)) {
            return (false, false, 0);
        }
        VoteState storage vote = _states[chatGroupId].addressTargetStates[targetAddress].votes[voter];
        return (vote.hasVote, vote.supportDeny, vote.settledWeight);
    }

    function senderGroupIdDenyVoteOf(uint256 chatGroupId, uint256 targetSenderGroupId, address voter)
        external
        view
        returns (bool hasVote, bool supportDeny, uint256 settledWeight)
    {
        if (!_sourceHasCode(chatGroupId)) {
            return (false, false, 0);
        }
        VoteState storage vote = _states[chatGroupId].senderGroupIdTargetStates[targetSenderGroupId].votes[voter];
        return (vote.hasVote, vote.supportDeny, vote.settledWeight);
    }

    function addressDenyTallyOf(uint256 chatGroupId, address targetAddress)
        external
        view
        returns (uint256 supportWeight, uint256 opposeWeight)
    {
        if (!_sourceHasCode(chatGroupId)) {
            return (0, 0);
        }
        TargetState storage target = _states[chatGroupId].addressTargetStates[targetAddress];
        return (target.supportWeight, target.opposeWeight);
    }

    function senderGroupIdDenyTallyOf(uint256 chatGroupId, uint256 targetSenderGroupId)
        external
        view
        returns (uint256 supportWeight, uint256 opposeWeight)
    {
        if (!_sourceHasCode(chatGroupId)) {
            return (0, 0);
        }
        TargetState storage target = _states[chatGroupId].senderGroupIdTargetStates[targetSenderGroupId];
        return (target.supportWeight, target.opposeWeight);
    }

    function addressDenyTargetsCount(uint256 chatGroupId) external view returns (uint256) {
        if (!_sourceHasCode(chatGroupId)) {
            return 0;
        }
        return _states[chatGroupId].addressTargets.length;
    }

    function addressDenyTargets(uint256 chatGroupId, uint256 offset, uint256 limit)
        external
        view
        returns (
            address[] memory targetAddresses,
            uint256[] memory supportWeights,
            uint256[] memory opposeWeights,
            uint256[] memory voterCounts
        )
    {
        if (!_sourceHasCode(chatGroupId)) {
            return (new address[](0), new uint256[](0), new uint256[](0), new uint256[](0));
        }

        ChatState storage state = _states[chatGroupId];
        uint256 count = _pageCount(state.addressTargets.length, offset, limit);
        targetAddresses = new address[](count);
        supportWeights = new uint256[](count);
        opposeWeights = new uint256[](count);
        voterCounts = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            address targetAddress = state.addressTargets[offset + i];
            TargetState storage target = state.addressTargetStates[targetAddress];
            targetAddresses[i] = targetAddress;
            supportWeights[i] = target.supportWeight;
            opposeWeights[i] = target.opposeWeight;
            voterCounts[i] = target.voters.length;
        }
    }

    function senderGroupIdDenyTargetsCount(uint256 chatGroupId) external view returns (uint256) {
        if (!_sourceHasCode(chatGroupId)) {
            return 0;
        }
        return _states[chatGroupId].senderGroupIdTargets.length;
    }

    function senderGroupIdDenyTargets(uint256 chatGroupId, uint256 offset, uint256 limit)
        external
        view
        returns (
            uint256[] memory targetSenderGroupIds,
            uint256[] memory supportWeights,
            uint256[] memory opposeWeights,
            uint256[] memory voterCounts
        )
    {
        if (!_sourceHasCode(chatGroupId)) {
            return (new uint256[](0), new uint256[](0), new uint256[](0), new uint256[](0));
        }

        ChatState storage state = _states[chatGroupId];
        uint256 count = _pageCount(state.senderGroupIdTargets.length, offset, limit);
        targetSenderGroupIds = new uint256[](count);
        supportWeights = new uint256[](count);
        opposeWeights = new uint256[](count);
        voterCounts = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 targetSenderGroupId = state.senderGroupIdTargets[offset + i];
            TargetState storage target = state.senderGroupIdTargetStates[targetSenderGroupId];
            targetSenderGroupIds[i] = targetSenderGroupId;
            supportWeights[i] = target.supportWeight;
            opposeWeights[i] = target.opposeWeight;
            voterCounts[i] = target.voters.length;
        }
    }

    function addressDenyVotersCount(uint256 chatGroupId, address targetAddress) external view returns (uint256) {
        if (!_sourceHasCode(chatGroupId)) {
            return 0;
        }
        return _states[chatGroupId].addressTargetStates[targetAddress].voters.length;
    }

    function addressDenyVoters(uint256 chatGroupId, address targetAddress, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory voters, bool[] memory supportDenies, uint256[] memory settledWeights)
    {
        if (!_sourceHasCode(chatGroupId)) {
            return (new address[](0), new bool[](0), new uint256[](0));
        }
        return _votersPage(_states[chatGroupId].addressTargetStates[targetAddress], offset, limit);
    }

    function senderGroupIdDenyVotersCount(uint256 chatGroupId, uint256 targetSenderGroupId)
        external
        view
        returns (uint256)
    {
        if (!_sourceHasCode(chatGroupId)) {
            return 0;
        }
        return _states[chatGroupId].senderGroupIdTargetStates[targetSenderGroupId].voters.length;
    }

    function senderGroupIdDenyVoters(uint256 chatGroupId, uint256 targetSenderGroupId, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory voters, bool[] memory supportDenies, uint256[] memory settledWeights)
    {
        if (!_sourceHasCode(chatGroupId)) {
            return (new address[](0), new bool[](0), new uint256[](0));
        }
        return _votersPage(_states[chatGroupId].senderGroupIdTargetStates[targetSenderGroupId], offset, limit);
    }

    function isDenied(uint256 chatGroupId, uint256 senderGroupId, address senderAddress) external view returns (bool) {
        if (!_sourceHasCode(chatGroupId)) {
            return false;
        }

        ChatState storage state = _states[chatGroupId];
        TargetState storage addressTarget = state.addressTargetStates[senderAddress];
        if (addressTarget.supportWeight > addressTarget.opposeWeight) {
            return true;
        }

        TargetState storage senderGroupIdTarget = state.senderGroupIdTargetStates[senderGroupId];
        return senderGroupIdTarget.supportWeight > senderGroupIdTarget.opposeWeight;
    }

    function stateVersion(uint256 chatGroupId) external view returns (uint256) {
        return _states[chatGroupId].stateVersion;
    }

    function _setAddressVote(uint256 chatGroupId, address targetAddress, address voter, bool supportDeny) internal {
        if (!_setAddressVoteIfChanged(chatGroupId, targetAddress, voter, supportDeny)) revert VoteUnchanged();
    }

    function _setAddressVoteIfChanged(uint256 chatGroupId, address targetAddress, address voter, bool supportDeny)
        internal
        returns (bool)
    {
        if (targetAddress == address(0)) revert TargetAddressZero();
        address source = _sourceOrRevert(chatGroupId);
        uint256 weight = _voteWeightOrRevert(source, chatGroupId, voter, targetAddress, 0);
        if (weight == 0) revert VoteWeightZero();

        ChatState storage state = _states[chatGroupId];
        TargetState storage target = state.addressTargetStates[targetAddress];
        VoteState storage vote = target.votes[voter];
        if (vote.hasVote && vote.supportDeny == supportDeny && vote.settledWeight == weight) {
            return false;
        }

        if (!vote.hasVote) {
            _addAddressTarget(state, targetAddress);
            _addVoter(target, voter);
        } else {
            _removeWeight(target, vote.supportDeny, vote.settledWeight);
        }

        _addWeight(target, supportDeny, weight);
        vote.hasVote = true;
        vote.supportDeny = supportDeny;
        vote.settledWeight = weight;
        _emitAddressVoteSet(state, chatGroupId, targetAddress, voter, true, supportDeny, weight);
        return true;
    }

    function _clearAddressVote(uint256 chatGroupId, address targetAddress, address voter) internal {
        if (!_clearAddressVoteIfFound(chatGroupId, targetAddress, voter)) revert VoteNotFound();
    }

    function _clearAddressVoteIfFound(uint256 chatGroupId, address targetAddress, address voter)
        internal
        returns (bool)
    {
        if (targetAddress == address(0)) revert TargetAddressZero();
        _sourceOrRevert(chatGroupId);

        ChatState storage state = _states[chatGroupId];
        TargetState storage target = state.addressTargetStates[targetAddress];
        VoteState storage vote = target.votes[voter];
        if (!vote.hasVote) return false;

        _removeWeight(target, vote.supportDeny, vote.settledWeight);
        delete target.votes[voter];
        _removeVoter(target, voter);
        if (target.voters.length == 0) {
            _removeAddressTarget(state, targetAddress);
        }
        _emitAddressVoteSet(state, chatGroupId, targetAddress, voter, false, false, 0);
        return true;
    }

    function _revalidateAddressVote(uint256 chatGroupId, address targetAddress, address voter) internal {
        if (!_revalidateAddressVoteIfFound(chatGroupId, targetAddress, voter)) revert VoteNotFound();
    }

    function _revalidateAddressVoteIfFound(uint256 chatGroupId, address targetAddress, address voter)
        internal
        returns (bool)
    {
        if (targetAddress == address(0)) revert TargetAddressZero();
        address source = _sourceOrRevert(chatGroupId);

        ChatState storage state = _states[chatGroupId];
        TargetState storage target = state.addressTargetStates[targetAddress];
        VoteState storage vote = target.votes[voter];
        if (!vote.hasVote) return false;

        uint256 weight = _voteWeightOrRevert(source, chatGroupId, voter, targetAddress, 0);
        if (weight == vote.settledWeight) {
            return true;
        }

        _removeWeight(target, vote.supportDeny, vote.settledWeight);
        if (weight == 0) {
            delete target.votes[voter];
            _removeVoter(target, voter);
            if (target.voters.length == 0) {
                _removeAddressTarget(state, targetAddress);
            }
            _emitAddressVoteSet(state, chatGroupId, targetAddress, voter, false, false, 0);
            return true;
        }

        _addWeight(target, vote.supportDeny, weight);
        vote.settledWeight = weight;
        _emitAddressVoteSet(state, chatGroupId, targetAddress, voter, true, vote.supportDeny, weight);
        return true;
    }

    function _setSenderGroupIdVote(uint256 chatGroupId, uint256 targetSenderGroupId, address voter, bool supportDeny)
        internal
    {
        if (!_setSenderGroupIdVoteIfChanged(chatGroupId, targetSenderGroupId, voter, supportDeny)) {
            revert VoteUnchanged();
        }
    }

    function _setSenderGroupIdVoteIfChanged(
        uint256 chatGroupId,
        uint256 targetSenderGroupId,
        address voter,
        bool supportDeny
    ) internal returns (bool) {
        if (targetSenderGroupId == 0) revert TargetSenderGroupIdZero();
        address source = _sourceOrRevert(chatGroupId);
        uint256 weight = _voteWeightOrRevert(source, chatGroupId, voter, address(0), targetSenderGroupId);
        if (weight == 0) revert VoteWeightZero();

        ChatState storage state = _states[chatGroupId];
        TargetState storage target = state.senderGroupIdTargetStates[targetSenderGroupId];
        VoteState storage vote = target.votes[voter];
        if (vote.hasVote && vote.supportDeny == supportDeny && vote.settledWeight == weight) {
            return false;
        }

        if (!vote.hasVote) {
            _addSenderGroupIdTarget(state, targetSenderGroupId);
            _addVoter(target, voter);
        } else {
            _removeWeight(target, vote.supportDeny, vote.settledWeight);
        }

        _addWeight(target, supportDeny, weight);
        vote.hasVote = true;
        vote.supportDeny = supportDeny;
        vote.settledWeight = weight;
        _emitSenderGroupIdVoteSet(state, chatGroupId, targetSenderGroupId, voter, true, supportDeny, weight);
        return true;
    }

    function _clearSenderGroupIdVote(uint256 chatGroupId, uint256 targetSenderGroupId, address voter) internal {
        if (!_clearSenderGroupIdVoteIfFound(chatGroupId, targetSenderGroupId, voter)) revert VoteNotFound();
    }

    function _clearSenderGroupIdVoteIfFound(uint256 chatGroupId, uint256 targetSenderGroupId, address voter)
        internal
        returns (bool)
    {
        if (targetSenderGroupId == 0) revert TargetSenderGroupIdZero();
        _sourceOrRevert(chatGroupId);

        ChatState storage state = _states[chatGroupId];
        TargetState storage target = state.senderGroupIdTargetStates[targetSenderGroupId];
        VoteState storage vote = target.votes[voter];
        if (!vote.hasVote) return false;

        _removeWeight(target, vote.supportDeny, vote.settledWeight);
        delete target.votes[voter];
        _removeVoter(target, voter);
        if (target.voters.length == 0) {
            _removeSenderGroupIdTarget(state, targetSenderGroupId);
        }
        _emitSenderGroupIdVoteSet(state, chatGroupId, targetSenderGroupId, voter, false, false, 0);
        return true;
    }

    function _revalidateSenderGroupIdVote(uint256 chatGroupId, uint256 targetSenderGroupId, address voter) internal {
        if (!_revalidateSenderGroupIdVoteIfFound(chatGroupId, targetSenderGroupId, voter)) revert VoteNotFound();
    }

    function _revalidateSenderGroupIdVoteIfFound(uint256 chatGroupId, uint256 targetSenderGroupId, address voter)
        internal
        returns (bool)
    {
        if (targetSenderGroupId == 0) revert TargetSenderGroupIdZero();
        address source = _sourceOrRevert(chatGroupId);

        ChatState storage state = _states[chatGroupId];
        TargetState storage target = state.senderGroupIdTargetStates[targetSenderGroupId];
        VoteState storage vote = target.votes[voter];
        if (!vote.hasVote) return false;

        uint256 weight = _voteWeightOrRevert(source, chatGroupId, voter, address(0), targetSenderGroupId);
        if (weight == vote.settledWeight) {
            return true;
        }

        _removeWeight(target, vote.supportDeny, vote.settledWeight);
        if (weight == 0) {
            delete target.votes[voter];
            _removeVoter(target, voter);
            if (target.voters.length == 0) {
                _removeSenderGroupIdTarget(state, targetSenderGroupId);
            }
            _emitSenderGroupIdVoteSet(state, chatGroupId, targetSenderGroupId, voter, false, false, 0);
            return true;
        }

        _addWeight(target, vote.supportDeny, weight);
        vote.settledWeight = weight;
        _emitSenderGroupIdVoteSet(state, chatGroupId, targetSenderGroupId, voter, true, vote.supportDeny, weight);
        return true;
    }

    function _setSenderVote(
        uint256 chatGroupId,
        uint256 targetSenderGroupId,
        address targetAddress,
        address voter,
        bool supportDeny
    ) internal {
        bool addressChanged = _setAddressVoteIfChanged(chatGroupId, targetAddress, voter, supportDeny);
        bool senderGroupIdChanged = _setSenderGroupIdVoteIfChanged(chatGroupId, targetSenderGroupId, voter, supportDeny);
        if (!addressChanged && !senderGroupIdChanged) revert VoteUnchanged();
    }

    function _clearSenderVote(uint256 chatGroupId, uint256 targetSenderGroupId, address targetAddress, address voter)
        internal
    {
        bool addressCleared = _clearAddressVoteIfFound(chatGroupId, targetAddress, voter);
        bool senderGroupIdCleared = _clearSenderGroupIdVoteIfFound(chatGroupId, targetSenderGroupId, voter);
        if (!addressCleared && !senderGroupIdCleared) revert VoteNotFound();
    }

    function _revalidateSenderVote(
        uint256 chatGroupId,
        uint256 targetSenderGroupId,
        address targetAddress,
        address voter
    ) internal {
        bool addressFound = _revalidateAddressVoteIfFound(chatGroupId, targetAddress, voter);
        bool senderGroupIdFound = _revalidateSenderGroupIdVoteIfFound(chatGroupId, targetSenderGroupId, voter);
        if (!addressFound && !senderGroupIdFound) revert VoteNotFound();
    }

    function _setSenderAddressVote(uint256 chatGroupId, address targetAddress, address voter, bool supportDeny)
        internal
    {
        uint256 targetSenderGroupId = _validDefaultGroupIdOf(targetAddress);
        if (targetSenderGroupId == 0) {
            _setAddressVote(chatGroupId, targetAddress, voter, supportDeny);
            return;
        }
        _setSenderVote(chatGroupId, targetSenderGroupId, targetAddress, voter, supportDeny);
    }

    function _clearSenderAddressVote(uint256 chatGroupId, address targetAddress, address voter) internal {
        uint256 targetSenderGroupId = _validDefaultGroupIdOf(targetAddress);
        if (targetSenderGroupId == 0) {
            _clearAddressVote(chatGroupId, targetAddress, voter);
            return;
        }
        _clearSenderVote(chatGroupId, targetSenderGroupId, targetAddress, voter);
    }

    function _revalidateSenderAddressVote(uint256 chatGroupId, address targetAddress, address voter) internal {
        uint256 targetSenderGroupId = _validDefaultGroupIdOf(targetAddress);
        if (targetSenderGroupId == 0) {
            _revalidateAddressVote(chatGroupId, targetAddress, voter);
            return;
        }
        _revalidateSenderVote(chatGroupId, targetSenderGroupId, targetAddress, voter);
    }

    function _emitAddressVoteSet(
        ChatState storage state,
        uint256 chatGroupId,
        address targetAddress,
        address voter,
        bool hasVote,
        bool supportDeny,
        uint256 settledWeight
    ) internal {
        TargetState storage target = state.addressTargetStates[targetAddress];
        uint256 newVersion = ++state.stateVersion;
        emit AddressDenyVoteSet(
            chatGroupId,
            targetAddress,
            voter,
            hasVote,
            supportDeny,
            settledWeight,
            target.supportWeight,
            target.opposeWeight,
            newVersion
        );
        emit StateVersionChanged(chatGroupId, newVersion);
    }

    function _emitSenderGroupIdVoteSet(
        ChatState storage state,
        uint256 chatGroupId,
        uint256 targetSenderGroupId,
        address voter,
        bool hasVote,
        bool supportDeny,
        uint256 settledWeight
    ) internal {
        TargetState storage target = state.senderGroupIdTargetStates[targetSenderGroupId];
        uint256 newVersion = ++state.stateVersion;
        emit SenderGroupIdDenyVoteSet(
            chatGroupId,
            targetSenderGroupId,
            voter,
            hasVote,
            supportDeny,
            settledWeight,
            target.supportWeight,
            target.opposeWeight,
            newVersion
        );
        emit StateVersionChanged(chatGroupId, newVersion);
    }

    function _sourceOrRevert(uint256 chatGroupId) internal view returns (address source) {
        try ILOVE20Group(GROUP_ADDRESS).ownerOf(chatGroupId) returns (address resolved) {
            source = resolved;
        } catch {
            revert DenyVoteWeightSourceUnavailable();
        }
        if (source.code.length == 0) revert DenyVoteWeightSourceUnavailable();
    }

    function _sourceHasCode(uint256 chatGroupId) internal view returns (bool) {
        try ILOVE20Group(GROUP_ADDRESS).ownerOf(chatGroupId) returns (address source) {
            return source.code.length != 0;
        } catch {
            return false;
        }
    }

    function _ownerOfOrRevert(uint256 groupId) internal view returns (address owner) {
        if (groupId == 0) revert TargetSenderGroupIdZero();
        try ILOVE20Group(GROUP_ADDRESS).ownerOf(groupId) returns (address resolved) {
            return resolved;
        } catch {
            revert GroupNotExist();
        }
    }

    function _tryOwnerOf(uint256 groupId) internal view returns (address owner) {
        try ILOVE20Group(GROUP_ADDRESS).ownerOf(groupId) returns (address resolved) {
            return resolved;
        } catch {
            return address(0);
        }
    }

    function _validDefaultGroupIdOf(address account) internal view returns (uint256 groupId) {
        if (account == address(0)) revert TargetAddressZero();
        groupId = IGroupDefaults(GROUP_DEFAULTS).defaultGroupIdOf(account);
        if (groupId == 0 || _tryOwnerOf(groupId) != account) {
            return 0;
        }
    }

    function _voteWeightOrRevert(
        address source,
        uint256 chatGroupId,
        address voter,
        address targetAddress,
        uint256 targetSenderGroupId
    ) internal view returns (uint256 weight) {
        try IDenyVoteWeightSource(source).denyVoteWeightOf(chatGroupId, voter, targetAddress, targetSenderGroupId)
        returns (uint256 resolved) {
            return resolved;
        } catch {
            revert DenyVoteWeightSourceUnavailable();
        }
    }

    function _addAddressTarget(ChatState storage state, address targetAddress) internal {
        if (state.addressTargetIndexPlusOne[targetAddress] != 0) {
            return;
        }
        state.addressTargets.push(targetAddress);
        state.addressTargetIndexPlusOne[targetAddress] = state.addressTargets.length;
    }

    function _removeAddressTarget(ChatState storage state, address targetAddress) internal {
        uint256 indexPlusOne = state.addressTargetIndexPlusOne[targetAddress];
        if (indexPlusOne == 0) {
            return;
        }

        uint256 index = indexPlusOne - 1;
        uint256 lastIndex = state.addressTargets.length - 1;
        if (index != lastIndex) {
            address last = state.addressTargets[lastIndex];
            state.addressTargets[index] = last;
            state.addressTargetIndexPlusOne[last] = indexPlusOne;
        }
        state.addressTargets.pop();
        delete state.addressTargetIndexPlusOne[targetAddress];
    }

    function _addSenderGroupIdTarget(ChatState storage state, uint256 targetSenderGroupId) internal {
        if (state.senderGroupIdTargetIndexPlusOne[targetSenderGroupId] != 0) {
            return;
        }
        state.senderGroupIdTargets.push(targetSenderGroupId);
        state.senderGroupIdTargetIndexPlusOne[targetSenderGroupId] = state.senderGroupIdTargets.length;
    }

    function _removeSenderGroupIdTarget(ChatState storage state, uint256 targetSenderGroupId) internal {
        uint256 indexPlusOne = state.senderGroupIdTargetIndexPlusOne[targetSenderGroupId];
        if (indexPlusOne == 0) {
            return;
        }

        uint256 index = indexPlusOne - 1;
        uint256 lastIndex = state.senderGroupIdTargets.length - 1;
        if (index != lastIndex) {
            uint256 last = state.senderGroupIdTargets[lastIndex];
            state.senderGroupIdTargets[index] = last;
            state.senderGroupIdTargetIndexPlusOne[last] = indexPlusOne;
        }
        state.senderGroupIdTargets.pop();
        delete state.senderGroupIdTargetIndexPlusOne[targetSenderGroupId];
    }

    function _addVoter(TargetState storage target, address voter) internal {
        if (target.voterIndexPlusOne[voter] != 0) {
            return;
        }
        target.voters.push(voter);
        target.voterIndexPlusOne[voter] = target.voters.length;
    }

    function _removeVoter(TargetState storage target, address voter) internal {
        uint256 indexPlusOne = target.voterIndexPlusOne[voter];
        if (indexPlusOne == 0) {
            return;
        }

        uint256 index = indexPlusOne - 1;
        uint256 lastIndex = target.voters.length - 1;
        if (index != lastIndex) {
            address last = target.voters[lastIndex];
            target.voters[index] = last;
            target.voterIndexPlusOne[last] = indexPlusOne;
        }
        target.voters.pop();
        delete target.voterIndexPlusOne[voter];
    }

    function _addWeight(TargetState storage target, bool supportDeny, uint256 weight) internal {
        if (supportDeny) {
            target.supportWeight += weight;
        } else {
            target.opposeWeight += weight;
        }
    }

    function _removeWeight(TargetState storage target, bool supportDeny, uint256 weight) internal {
        if (supportDeny) {
            target.supportWeight -= weight;
        } else {
            target.opposeWeight -= weight;
        }
    }

    function _votersPage(TargetState storage target, uint256 offset, uint256 limit)
        internal
        view
        returns (address[] memory voters, bool[] memory supportDenies, uint256[] memory settledWeights)
    {
        uint256 count = _pageCount(target.voters.length, offset, limit);
        voters = new address[](count);
        supportDenies = new bool[](count);
        settledWeights = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            address voter = target.voters[offset + i];
            VoteState storage vote = target.votes[voter];
            voters[i] = voter;
            supportDenies[i] = vote.supportDeny;
            settledWeights[i] = vote.settledWeight;
        }
    }

    function _pageCount(uint256 total, uint256 offset, uint256 limit) internal pure returns (uint256) {
        if (limit == 0 || offset >= total) {
            return 0;
        }

        uint256 remaining = total - offset;
        return remaining < limit ? remaining : limit;
    }
}
