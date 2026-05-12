// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupDefaults} from "../../interfaces/external/IGroupDefaults.sol";
import {ILOVE20Group} from "../../interfaces/external/ILOVE20Group.sol";
import {IDenyVoteWeightSource} from "../../interfaces/sources/IDenyVoteWeightSource.sol";
import {IPostDenySource} from "../../interfaces/sources/IPostDenySource.sol";

contract GovVotedDenySource is IPostDenySource {
    error GovVotedDenySourceAddressHasNoCode();
    error DenyVoteWeightSourceUnavailable();
    error GroupNotExist();
    error TargetAddressZero();
    error TargetSenderIdZero();
    error VoteWeightZero();
    error VoteUnchanged();
    error VoteNotFound();
    error DenyThresholdTooHigh();

    event AddressDenyVoteSet(
        uint256 indexed groupId,
        address indexed targetAddress,
        address indexed voter,
        bool supportDeny,
        uint256 settledWeight,
        uint256 supportWeight,
        uint256 opposeWeight,
        uint256 stateVersion
    );

    event SenderIdDenyVoteSet(
        uint256 indexed groupId,
        uint256 indexed targetSenderId,
        address indexed voter,
        bool supportDeny,
        uint256 settledWeight,
        uint256 supportWeight,
        uint256 opposeWeight,
        uint256 stateVersion
    );

    event StateVersionChanged(uint256 indexed groupId, uint256 stateVersion);

    address public immutable GROUP_ADDRESS;
    address public immutable GROUP_DEFAULTS_ADDRESS;
    uint256 public immutable DENY_THRESHOLD_BPS;
    uint256 public constant PERCENT_DENOMINATOR = 10_000;

    struct VoteState {
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
        uint256[] senderIdTargets;
        mapping(uint256 => uint256) senderIdTargetIndexPlusOne;
        mapping(uint256 => TargetState) senderIdTargetStates;
    }

    mapping(uint256 => ChatState) internal _states;

    constructor(address groupAddress_, address groupDefaults_, uint256 denyThresholdBps_) {
        if (groupAddress_.code.length == 0) {
            revert GovVotedDenySourceAddressHasNoCode();
        }
        if (groupDefaults_.code.length == 0) {
            revert GovVotedDenySourceAddressHasNoCode();
        }
        if (denyThresholdBps_ > PERCENT_DENOMINATOR) {
            revert DenyThresholdTooHigh();
        }
        GROUP_ADDRESS = groupAddress_;
        GROUP_DEFAULTS_ADDRESS = groupDefaults_;
        DENY_THRESHOLD_BPS = denyThresholdBps_;
    }

    function voteDenyAddress(uint256 groupId, address targetAddress) external {
        _setAddressVote(groupId, targetAddress, msg.sender, true);
    }

    function opposeDenyAddress(uint256 groupId, address targetAddress) external {
        _setAddressVote(groupId, targetAddress, msg.sender, false);
    }

    function clearDenyAddressVote(uint256 groupId, address targetAddress) external {
        _clearAddressVote(groupId, targetAddress, msg.sender);
    }

    function revalidateDenyAddressVote(uint256 groupId, address targetAddress, address voter) external {
        _revalidateAddressVote(groupId, targetAddress, voter);
    }

    function voteDenySenderId(uint256 groupId, uint256 targetSenderId) external {
        _setSenderIdVote(groupId, targetSenderId, msg.sender, true);
    }

    function opposeDenySenderId(uint256 groupId, uint256 targetSenderId) external {
        _setSenderIdVote(groupId, targetSenderId, msg.sender, false);
    }

    function clearDenySenderIdVote(uint256 groupId, uint256 targetSenderId) external {
        _clearSenderIdVote(groupId, targetSenderId, msg.sender);
    }

    function revalidateDenySenderIdVote(uint256 groupId, uint256 targetSenderId, address voter) external {
        _revalidateSenderIdVote(groupId, targetSenderId, voter);
    }

    function voteDenySenderBySenderId(uint256 groupId, uint256 targetSenderId) external {
        address targetAddress = _ownerOfOrRevert(targetSenderId);
        _setSenderVote(groupId, targetSenderId, targetAddress, msg.sender, true);
    }

    function opposeDenySenderBySenderId(uint256 groupId, uint256 targetSenderId) external {
        address targetAddress = _ownerOfOrRevert(targetSenderId);
        _setSenderVote(groupId, targetSenderId, targetAddress, msg.sender, false);
    }

    function clearDenySenderVoteBySenderId(uint256 groupId, uint256 targetSenderId) external {
        address targetAddress = _ownerOfOrRevert(targetSenderId);
        _clearSenderVote(groupId, targetSenderId, targetAddress, msg.sender);
    }

    function revalidateDenySenderVoteBySenderId(uint256 groupId, uint256 targetSenderId, address voter) external {
        address targetAddress = _ownerOfOrRevert(targetSenderId);
        _revalidateSenderVote(groupId, targetSenderId, targetAddress, voter);
    }

    function voteDenySenderBySenderAddress(uint256 groupId, address targetAddress) external {
        _setSenderAddressVote(groupId, targetAddress, msg.sender, true);
    }

    function opposeDenySenderBySenderAddress(uint256 groupId, address targetAddress) external {
        _setSenderAddressVote(groupId, targetAddress, msg.sender, false);
    }

    function clearDenySenderVoteBySenderAddress(uint256 groupId, address targetAddress) external {
        _clearSenderAddressVote(groupId, targetAddress, msg.sender);
    }

    function revalidateDenySenderVoteBySenderAddress(uint256 groupId, address targetAddress, address voter) external {
        _revalidateSenderAddressVote(groupId, targetAddress, voter);
    }

    function addressDenyVoteOf(uint256 groupId, address targetAddress, address voter)
        external
        view
        returns (bool supportDeny, uint256 settledWeight)
    {
        if (!_sourceHasCode(groupId)) {
            return (false, 0);
        }
        VoteState storage vote = _states[groupId].addressTargetStates[targetAddress].votes[voter];
        return (vote.supportDeny, vote.settledWeight);
    }

    function senderIdDenyVoteOf(uint256 groupId, uint256 targetSenderId, address voter)
        external
        view
        returns (bool supportDeny, uint256 settledWeight)
    {
        if (!_sourceHasCode(groupId)) {
            return (false, 0);
        }
        VoteState storage vote = _states[groupId].senderIdTargetStates[targetSenderId].votes[voter];
        return (vote.supportDeny, vote.settledWeight);
    }

    function addressDenyTallyOf(uint256 groupId, address targetAddress)
        external
        view
        returns (uint256 supportWeight, uint256 opposeWeight)
    {
        if (!_sourceHasCode(groupId)) {
            return (0, 0);
        }
        TargetState storage target = _states[groupId].addressTargetStates[targetAddress];
        return (target.supportWeight, target.opposeWeight);
    }

    function senderIdDenyTallyOf(uint256 groupId, uint256 targetSenderId)
        external
        view
        returns (uint256 supportWeight, uint256 opposeWeight)
    {
        if (!_sourceHasCode(groupId)) {
            return (0, 0);
        }
        TargetState storage target = _states[groupId].senderIdTargetStates[targetSenderId];
        return (target.supportWeight, target.opposeWeight);
    }

    function addressDenyTargetsCount(uint256 groupId) external view returns (uint256) {
        if (!_sourceHasCode(groupId)) {
            return 0;
        }
        return _states[groupId].addressTargets.length;
    }

    function addressDenyTargets(uint256 groupId, uint256 offset, uint256 limit)
        external
        view
        returns (
            address[] memory targetAddresses,
            uint256[] memory supportWeights,
            uint256[] memory opposeWeights,
            uint256[] memory voterCounts
        )
    {
        if (!_sourceHasCode(groupId)) {
            return (new address[](0), new uint256[](0), new uint256[](0), new uint256[](0));
        }

        ChatState storage state = _states[groupId];
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

    function senderIdDenyTargetsCount(uint256 groupId) external view returns (uint256) {
        if (!_sourceHasCode(groupId)) {
            return 0;
        }
        return _states[groupId].senderIdTargets.length;
    }

    function senderIdDenyTargets(uint256 groupId, uint256 offset, uint256 limit)
        external
        view
        returns (
            uint256[] memory targetSenderIds,
            uint256[] memory supportWeights,
            uint256[] memory opposeWeights,
            uint256[] memory voterCounts
        )
    {
        if (!_sourceHasCode(groupId)) {
            return (new uint256[](0), new uint256[](0), new uint256[](0), new uint256[](0));
        }

        ChatState storage state = _states[groupId];
        uint256 count = _pageCount(state.senderIdTargets.length, offset, limit);
        targetSenderIds = new uint256[](count);
        supportWeights = new uint256[](count);
        opposeWeights = new uint256[](count);
        voterCounts = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 targetSenderId = state.senderIdTargets[offset + i];
            TargetState storage target = state.senderIdTargetStates[targetSenderId];
            targetSenderIds[i] = targetSenderId;
            supportWeights[i] = target.supportWeight;
            opposeWeights[i] = target.opposeWeight;
            voterCounts[i] = target.voters.length;
        }
    }

    function addressDenyVotersCount(uint256 groupId, address targetAddress) external view returns (uint256) {
        if (!_sourceHasCode(groupId)) {
            return 0;
        }
        return _states[groupId].addressTargetStates[targetAddress].voters.length;
    }

    function addressDenyVoters(uint256 groupId, address targetAddress, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory voters, bool[] memory supportDenies, uint256[] memory settledWeights)
    {
        if (!_sourceHasCode(groupId)) {
            return (new address[](0), new bool[](0), new uint256[](0));
        }
        return _votersPage(_states[groupId].addressTargetStates[targetAddress], offset, limit);
    }

    function senderIdDenyVotersCount(uint256 groupId, uint256 targetSenderId) external view returns (uint256) {
        if (!_sourceHasCode(groupId)) {
            return 0;
        }
        return _states[groupId].senderIdTargetStates[targetSenderId].voters.length;
    }

    function senderIdDenyVoters(uint256 groupId, uint256 targetSenderId, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory voters, bool[] memory supportDenies, uint256[] memory settledWeights)
    {
        if (!_sourceHasCode(groupId)) {
            return (new address[](0), new bool[](0), new uint256[](0));
        }
        return _votersPage(_states[groupId].senderIdTargetStates[targetSenderId], offset, limit);
    }

    function isDenied(uint256 groupId, uint256 senderId, address senderAddress) external view returns (bool) {
        address source = _sourceOrZero(groupId);
        if (source == address(0)) {
            return false;
        }

        ChatState storage state = _states[groupId];
        TargetState storage addressTarget = state.addressTargetStates[senderAddress];
        TargetState storage senderIdTarget = state.senderIdTargetStates[senderId];
        if (!_supportOutweighsOppose(addressTarget) && !_supportOutweighsOppose(senderIdTarget)) {
            return false;
        }

        uint256 totalWeight = _totalVoteWeightOrRevert(source, groupId);
        if (totalWeight == 0) {
            return false;
        }

        if (_isTargetDenied(addressTarget, totalWeight)) {
            return true;
        }

        return _isTargetDenied(senderIdTarget, totalWeight);
    }

    function stateVersion(uint256 groupId) external view returns (uint256) {
        return _states[groupId].stateVersion;
    }

    function _setAddressVote(uint256 groupId, address targetAddress, address voter, bool supportDeny) internal {
        uint256 newVersion = _setAddressVoteIfChanged(groupId, targetAddress, voter, supportDeny, 0);
        if (newVersion == 0) {
            revert VoteUnchanged();
        }
        _emitStateVersionChanged(groupId, newVersion);
    }

    function _setAddressVoteIfChanged(
        uint256 groupId,
        address targetAddress,
        address voter,
        bool supportDeny,
        uint256 newVersion
    ) internal returns (uint256) {
        if (targetAddress == address(0)) {
            revert TargetAddressZero();
        }
        address source = _sourceOrRevert(groupId);
        uint256 weight = _voteWeightOrRevert(source, groupId, voter);
        if (weight == 0) {
            revert VoteWeightZero();
        }

        ChatState storage state = _states[groupId];
        TargetState storage target = state.addressTargetStates[targetAddress];
        VoteState storage vote = target.votes[voter];
        bool voteExists = vote.settledWeight != 0;
        if (voteExists && vote.supportDeny == supportDeny && vote.settledWeight == weight) {
            return newVersion;
        }

        if (!voteExists) {
            _addAddressTarget(state, targetAddress);
            _addVoter(target, voter);
        } else {
            _removeWeight(target, vote.supportDeny, vote.settledWeight);
        }

        _addWeight(target, supportDeny, weight);
        vote.supportDeny = supportDeny;
        vote.settledWeight = weight;
        newVersion = _ensureStateVersion(state, newVersion);
        _emitAddressVoteSet(state, groupId, targetAddress, voter, supportDeny, weight, newVersion);
        return newVersion;
    }

    function _clearAddressVote(uint256 groupId, address targetAddress, address voter) internal {
        uint256 newVersion = _clearAddressVoteIfFound(groupId, targetAddress, voter, 0);
        if (newVersion == 0) {
            revert VoteNotFound();
        }
        _emitStateVersionChanged(groupId, newVersion);
    }

    function _clearAddressVoteIfFound(uint256 groupId, address targetAddress, address voter, uint256 newVersion)
        internal
        returns (uint256)
    {
        if (targetAddress == address(0)) {
            revert TargetAddressZero();
        }
        _sourceOrRevert(groupId);

        ChatState storage state = _states[groupId];
        TargetState storage target = state.addressTargetStates[targetAddress];
        VoteState storage vote = target.votes[voter];
        if (vote.settledWeight == 0) {
            return newVersion;
        }

        _removeWeight(target, vote.supportDeny, vote.settledWeight);
        delete target.votes[voter];
        _removeVoter(target, voter);
        if (target.voters.length == 0) {
            _removeAddressTarget(state, targetAddress);
        }
        newVersion = _ensureStateVersion(state, newVersion);
        _emitAddressVoteSet(state, groupId, targetAddress, voter, false, 0, newVersion);
        return newVersion;
    }

    function _revalidateAddressVote(uint256 groupId, address targetAddress, address voter) internal {
        (bool found, uint256 newVersion) = _revalidateAddressVoteIfFound(groupId, targetAddress, voter, 0);
        if (!found) {
            revert VoteNotFound();
        }
        _emitStateVersionChangedIfChanged(groupId, newVersion);
    }

    function _revalidateAddressVoteIfFound(uint256 groupId, address targetAddress, address voter, uint256 newVersion)
        internal
        returns (bool found, uint256)
    {
        if (targetAddress == address(0)) {
            revert TargetAddressZero();
        }
        address source = _sourceOrRevert(groupId);

        ChatState storage state = _states[groupId];
        TargetState storage target = state.addressTargetStates[targetAddress];
        VoteState storage vote = target.votes[voter];
        if (vote.settledWeight == 0) {
            return (false, newVersion);
        }

        uint256 weight = _voteWeightOrRevert(source, groupId, voter);
        if (weight == vote.settledWeight) {
            return (true, newVersion);
        }

        _removeWeight(target, vote.supportDeny, vote.settledWeight);
        if (weight == 0) {
            delete target.votes[voter];
            _removeVoter(target, voter);
            if (target.voters.length == 0) {
                _removeAddressTarget(state, targetAddress);
            }
            newVersion = _ensureStateVersion(state, newVersion);
            _emitAddressVoteSet(state, groupId, targetAddress, voter, false, 0, newVersion);
            return (true, newVersion);
        }

        _addWeight(target, vote.supportDeny, weight);
        vote.settledWeight = weight;
        newVersion = _ensureStateVersion(state, newVersion);
        _emitAddressVoteSet(state, groupId, targetAddress, voter, vote.supportDeny, weight, newVersion);
        return (true, newVersion);
    }

    function _setSenderIdVote(uint256 groupId, uint256 targetSenderId, address voter, bool supportDeny) internal {
        uint256 newVersion = _setSenderIdVoteIfChanged(groupId, targetSenderId, voter, supportDeny, 0);
        if (newVersion == 0) {
            revert VoteUnchanged();
        }
        _emitStateVersionChanged(groupId, newVersion);
    }

    function _setSenderIdVoteIfChanged(
        uint256 groupId,
        uint256 targetSenderId,
        address voter,
        bool supportDeny,
        uint256 newVersion
    ) internal returns (uint256) {
        if (targetSenderId == 0) {
            revert TargetSenderIdZero();
        }
        address source = _sourceOrRevert(groupId);
        uint256 weight = _voteWeightOrRevert(source, groupId, voter);
        if (weight == 0) {
            revert VoteWeightZero();
        }

        ChatState storage state = _states[groupId];
        TargetState storage target = state.senderIdTargetStates[targetSenderId];
        VoteState storage vote = target.votes[voter];
        bool voteExists = vote.settledWeight != 0;
        if (voteExists && vote.supportDeny == supportDeny && vote.settledWeight == weight) {
            return newVersion;
        }

        if (!voteExists) {
            _addSenderIdTarget(state, targetSenderId);
            _addVoter(target, voter);
        } else {
            _removeWeight(target, vote.supportDeny, vote.settledWeight);
        }

        _addWeight(target, supportDeny, weight);
        vote.supportDeny = supportDeny;
        vote.settledWeight = weight;
        newVersion = _ensureStateVersion(state, newVersion);
        _emitSenderIdVoteSet(state, groupId, targetSenderId, voter, supportDeny, weight, newVersion);
        return newVersion;
    }

    function _clearSenderIdVote(uint256 groupId, uint256 targetSenderId, address voter) internal {
        uint256 newVersion = _clearSenderIdVoteIfFound(groupId, targetSenderId, voter, 0);
        if (newVersion == 0) {
            revert VoteNotFound();
        }
        _emitStateVersionChanged(groupId, newVersion);
    }

    function _clearSenderIdVoteIfFound(uint256 groupId, uint256 targetSenderId, address voter, uint256 newVersion)
        internal
        returns (uint256)
    {
        if (targetSenderId == 0) {
            revert TargetSenderIdZero();
        }
        _sourceOrRevert(groupId);

        ChatState storage state = _states[groupId];
        TargetState storage target = state.senderIdTargetStates[targetSenderId];
        VoteState storage vote = target.votes[voter];
        if (vote.settledWeight == 0) {
            return newVersion;
        }

        _removeWeight(target, vote.supportDeny, vote.settledWeight);
        delete target.votes[voter];
        _removeVoter(target, voter);
        if (target.voters.length == 0) {
            _removeSenderIdTarget(state, targetSenderId);
        }
        newVersion = _ensureStateVersion(state, newVersion);
        _emitSenderIdVoteSet(state, groupId, targetSenderId, voter, false, 0, newVersion);
        return newVersion;
    }

    function _revalidateSenderIdVote(uint256 groupId, uint256 targetSenderId, address voter) internal {
        (bool found, uint256 newVersion) = _revalidateSenderIdVoteIfFound(groupId, targetSenderId, voter, 0);
        if (!found) {
            revert VoteNotFound();
        }
        _emitStateVersionChangedIfChanged(groupId, newVersion);
    }

    function _revalidateSenderIdVoteIfFound(uint256 groupId, uint256 targetSenderId, address voter, uint256 newVersion)
        internal
        returns (bool found, uint256)
    {
        if (targetSenderId == 0) {
            revert TargetSenderIdZero();
        }
        address source = _sourceOrRevert(groupId);

        ChatState storage state = _states[groupId];
        TargetState storage target = state.senderIdTargetStates[targetSenderId];
        VoteState storage vote = target.votes[voter];
        if (vote.settledWeight == 0) {
            return (false, newVersion);
        }

        uint256 weight = _voteWeightOrRevert(source, groupId, voter);
        if (weight == vote.settledWeight) {
            return (true, newVersion);
        }

        _removeWeight(target, vote.supportDeny, vote.settledWeight);
        if (weight == 0) {
            delete target.votes[voter];
            _removeVoter(target, voter);
            if (target.voters.length == 0) {
                _removeSenderIdTarget(state, targetSenderId);
            }
            newVersion = _ensureStateVersion(state, newVersion);
            _emitSenderIdVoteSet(state, groupId, targetSenderId, voter, false, 0, newVersion);
            return (true, newVersion);
        }

        _addWeight(target, vote.supportDeny, weight);
        vote.settledWeight = weight;
        newVersion = _ensureStateVersion(state, newVersion);
        _emitSenderIdVoteSet(state, groupId, targetSenderId, voter, vote.supportDeny, weight, newVersion);
        return (true, newVersion);
    }

    function _setSenderVote(
        uint256 groupId,
        uint256 targetSenderId,
        address targetAddress,
        address voter,
        bool supportDeny
    ) internal {
        uint256 newVersion = _setAddressVoteIfChanged(groupId, targetAddress, voter, supportDeny, 0);
        newVersion = _setSenderIdVoteIfChanged(groupId, targetSenderId, voter, supportDeny, newVersion);
        if (newVersion == 0) {
            revert VoteUnchanged();
        }
        _emitStateVersionChanged(groupId, newVersion);
    }

    function _clearSenderVote(uint256 groupId, uint256 targetSenderId, address targetAddress, address voter) internal {
        uint256 newVersion = _clearAddressVoteIfFound(groupId, targetAddress, voter, 0);
        newVersion = _clearSenderIdVoteIfFound(groupId, targetSenderId, voter, newVersion);
        if (newVersion == 0) {
            revert VoteNotFound();
        }
        _emitStateVersionChanged(groupId, newVersion);
    }

    function _revalidateSenderVote(uint256 groupId, uint256 targetSenderId, address targetAddress, address voter)
        internal
    {
        (bool addressFound, uint256 newVersion) = _revalidateAddressVoteIfFound(groupId, targetAddress, voter, 0);
        (bool senderIdFound, uint256 newVersion2) =
            _revalidateSenderIdVoteIfFound(groupId, targetSenderId, voter, newVersion);
        if (!addressFound && !senderIdFound) {
            revert VoteNotFound();
        }
        _emitStateVersionChangedIfChanged(groupId, newVersion2);
    }

    function _setSenderAddressVote(uint256 groupId, address targetAddress, address voter, bool supportDeny) internal {
        uint256 targetSenderId = _validDefaultGroupIdOf(targetAddress);
        if (targetSenderId == 0) {
            _setAddressVote(groupId, targetAddress, voter, supportDeny);
            return;
        }
        _setSenderVote(groupId, targetSenderId, targetAddress, voter, supportDeny);
    }

    function _clearSenderAddressVote(uint256 groupId, address targetAddress, address voter) internal {
        uint256 targetSenderId = _validDefaultGroupIdOf(targetAddress);
        if (targetSenderId == 0) {
            _clearAddressVote(groupId, targetAddress, voter);
            return;
        }
        _clearSenderVote(groupId, targetSenderId, targetAddress, voter);
    }

    function _revalidateSenderAddressVote(uint256 groupId, address targetAddress, address voter) internal {
        uint256 targetSenderId = _validDefaultGroupIdOf(targetAddress);
        if (targetSenderId == 0) {
            _revalidateAddressVote(groupId, targetAddress, voter);
            return;
        }
        _revalidateSenderVote(groupId, targetSenderId, targetAddress, voter);
    }

    function _ensureStateVersion(ChatState storage state, uint256 newVersion) internal returns (uint256) {
        if (newVersion == 0) {
            newVersion = ++state.stateVersion;
        }
        return newVersion;
    }

    function _emitStateVersionChanged(uint256 groupId, uint256 newVersion) internal {
        emit StateVersionChanged(groupId, newVersion);
    }

    function _emitStateVersionChangedIfChanged(uint256 groupId, uint256 newVersion) internal {
        if (newVersion != 0) {
            emit StateVersionChanged(groupId, newVersion);
        }
    }

    function _emitAddressVoteSet(
        ChatState storage state,
        uint256 groupId,
        address targetAddress,
        address voter,
        bool supportDeny,
        uint256 settledWeight,
        uint256 newVersion
    ) internal {
        TargetState storage target = state.addressTargetStates[targetAddress];
        emit AddressDenyVoteSet(
            groupId,
            targetAddress,
            voter,
            supportDeny,
            settledWeight,
            target.supportWeight,
            target.opposeWeight,
            newVersion
        );
    }

    function _emitSenderIdVoteSet(
        ChatState storage state,
        uint256 groupId,
        uint256 targetSenderId,
        address voter,
        bool supportDeny,
        uint256 settledWeight,
        uint256 newVersion
    ) internal {
        TargetState storage target = state.senderIdTargetStates[targetSenderId];
        emit SenderIdDenyVoteSet(
            groupId,
            targetSenderId,
            voter,
            supportDeny,
            settledWeight,
            target.supportWeight,
            target.opposeWeight,
            newVersion
        );
    }

    function _sourceOrRevert(uint256 groupId) internal view returns (address source) {
        try ILOVE20Group(GROUP_ADDRESS).ownerOf(groupId) returns (address resolved) {
            source = resolved;
        } catch {
            revert DenyVoteWeightSourceUnavailable();
        }
        if (source.code.length == 0) {
            revert DenyVoteWeightSourceUnavailable();
        }
    }

    function _sourceOrZero(uint256 groupId) internal view returns (address source) {
        try ILOVE20Group(GROUP_ADDRESS).ownerOf(groupId) returns (address resolved) {
            if (resolved.code.length != 0) {
                return resolved;
            }
        } catch {}
        return address(0);
    }

    function _sourceHasCode(uint256 groupId) internal view returns (bool) {
        try ILOVE20Group(GROUP_ADDRESS).ownerOf(groupId) returns (address source) {
            return source.code.length != 0;
        } catch {
            return false;
        }
    }

    function _ownerOfOrRevert(uint256 groupId) internal view returns (address owner) {
        if (groupId == 0) {
            revert TargetSenderIdZero();
        }
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
        if (account == address(0)) {
            revert TargetAddressZero();
        }
        groupId = IGroupDefaults(GROUP_DEFAULTS_ADDRESS).defaultGroupIdOf(account);
        if (groupId == 0 || _tryOwnerOf(groupId) != account) {
            return 0;
        }
    }

    function _voteWeightOrRevert(address source, uint256 groupId, address voter)
        internal
        view
        returns (uint256 weight)
    {
        try IDenyVoteWeightSource(source).denyVoteWeightOf(groupId, voter) returns (uint256 resolved) {
            return resolved;
        } catch {
            revert DenyVoteWeightSourceUnavailable();
        }
    }

    function _totalVoteWeightOrRevert(address source, uint256 groupId) internal view returns (uint256) {
        try IDenyVoteWeightSource(source).denyVoteTotalWeightOf(groupId) returns (uint256 resolved) {
            return resolved;
        } catch {
            revert DenyVoteWeightSourceUnavailable();
        }
    }

    function _supportOutweighsOppose(TargetState storage target) internal view returns (bool) {
        return target.supportWeight > target.opposeWeight;
    }

    function _isTargetDenied(TargetState storage target, uint256 totalWeight) internal view returns (bool) {
        if (!_supportOutweighsOppose(target)) {
            return false;
        }
        return target.supportWeight * PERCENT_DENOMINATOR >= totalWeight * DENY_THRESHOLD_BPS;
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

    function _addSenderIdTarget(ChatState storage state, uint256 targetSenderId) internal {
        if (state.senderIdTargetIndexPlusOne[targetSenderId] != 0) {
            return;
        }
        state.senderIdTargets.push(targetSenderId);
        state.senderIdTargetIndexPlusOne[targetSenderId] = state.senderIdTargets.length;
    }

    function _removeSenderIdTarget(ChatState storage state, uint256 targetSenderId) internal {
        uint256 indexPlusOne = state.senderIdTargetIndexPlusOne[targetSenderId];
        if (indexPlusOne == 0) {
            return;
        }

        uint256 index = indexPlusOne - 1;
        uint256 lastIndex = state.senderIdTargets.length - 1;
        if (index != lastIndex) {
            uint256 last = state.senderIdTargets[lastIndex];
            state.senderIdTargets[index] = last;
            state.senderIdTargetIndexPlusOne[last] = indexPlusOne;
        }
        state.senderIdTargets.pop();
        delete state.senderIdTargetIndexPlusOne[targetSenderId];
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
