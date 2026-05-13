// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20Group} from "../../interfaces/external/ILOVE20Group.sol";

import {IPostDenySource} from "../../interfaces/sources/IPostDenySource.sol";
import {IDenyVoteWeightSource} from "../../interfaces/sources/deny/IDenyVoteWeightSource.sol";

contract GovVotedDenySource is IPostDenySource {
    error GovVotedDenySourceAddressHasNoCode();
    error DenyVoteWeightSourceUnavailable();
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

    event AddressDenySet(uint256 indexed groupId, address indexed targetAddress, bool listed, uint256 stateVersion);

    event SenderIdDenySet(uint256 indexed groupId, uint256 indexed targetSenderId, bool listed, uint256 stateVersion);

    event StateVersionChanged(uint256 indexed groupId, uint256 stateVersion);

    address public immutable GROUP_ADDRESS;
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

    struct AddressSet {
        address[] values;
        mapping(address => uint256) indexPlusOne;
    }

    struct UintSet {
        uint256[] values;
        mapping(uint256 => uint256) indexPlusOne;
    }

    struct ChatState {
        uint256 stateVersion;
        address[] addressTargets;
        mapping(address => uint256) addressTargetIndexPlusOne;
        mapping(address => TargetState) addressTargetStates;
        uint256[] senderIdTargets;
        mapping(uint256 => uint256) senderIdTargetIndexPlusOne;
        mapping(uint256 => TargetState) senderIdTargetStates;
        AddressSet addressDenyList;
        UintSet senderIdDenyList;
    }

    mapping(uint256 => ChatState) internal _states;

    constructor(address groupAddress_, uint256 denyThresholdBps_) {
        if (groupAddress_.code.length == 0) {
            revert GovVotedDenySourceAddressHasNoCode();
        }
        if (denyThresholdBps_ > PERCENT_DENOMINATOR) {
            revert DenyThresholdTooHigh();
        }
        GROUP_ADDRESS = groupAddress_;
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

    function voteDenySender(uint256 groupId, uint256 targetSenderId, address targetAddress) external {
        _setSenderVote(groupId, targetSenderId, targetAddress, msg.sender, true);
    }

    function opposeDenySender(uint256 groupId, uint256 targetSenderId, address targetAddress) external {
        _setSenderVote(groupId, targetSenderId, targetAddress, msg.sender, false);
    }

    function clearDenySenderVote(uint256 groupId, uint256 targetSenderId, address targetAddress) external {
        _clearSenderVote(groupId, targetSenderId, targetAddress, msg.sender);
    }

    function revalidateDenySenderVote(uint256 groupId, uint256 targetSenderId, address targetAddress, address voter)
        external
    {
        _revalidateSenderVote(groupId, targetSenderId, targetAddress, voter);
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
        ChatState storage state = _states[groupId];
        return _contains(state.addressDenyList, senderAddress) || _contains(state.senderIdDenyList, senderId);
    }

    function isAddressDenied(uint256 groupId, address senderAddress) external view returns (bool) {
        return _contains(_states[groupId].addressDenyList, senderAddress);
    }

    function isSenderIdDenied(uint256 groupId, uint256 senderId) external view returns (bool) {
        return _contains(_states[groupId].senderIdDenyList, senderId);
    }

    function isSenderIdExempt(uint256, uint256) external pure returns (bool) {
        return false;
    }

    function isAddressDeniedBatch(uint256 groupId, address[] calldata senderAddresses)
        external
        view
        returns (bool[] memory denied)
    {
        ChatState storage state = _states[groupId];
        denied = new bool[](senderAddresses.length);
        for (uint256 i = 0; i < senderAddresses.length; i++) {
            denied[i] = _contains(state.addressDenyList, senderAddresses[i]);
        }
    }

    function isSenderIdDeniedBatch(uint256 groupId, uint256[] calldata senderIds)
        external
        view
        returns (bool[] memory denied)
    {
        ChatState storage state = _states[groupId];
        denied = new bool[](senderIds.length);
        for (uint256 i = 0; i < senderIds.length; i++) {
            denied[i] = _contains(state.senderIdDenyList, senderIds[i]);
        }
    }

    function isSenderIdExemptBatch(uint256, uint256[] calldata senderIds)
        external
        pure
        returns (bool[] memory exempt)
    {
        exempt = new bool[](senderIds.length);
    }

    function addressDenyDetailsBatch(uint256 groupId, address[] calldata targetAddresses)
        external
        view
        returns (bool[] memory denied, uint256[] memory supportWeights, uint256[] memory opposeWeights)
    {
        ChatState storage state = _states[groupId];
        denied = new bool[](targetAddresses.length);
        supportWeights = new uint256[](targetAddresses.length);
        opposeWeights = new uint256[](targetAddresses.length);
        for (uint256 i = 0; i < targetAddresses.length; i++) {
            address targetAddress = targetAddresses[i];
            TargetState storage target = state.addressTargetStates[targetAddress];
            denied[i] = _contains(state.addressDenyList, targetAddress);
            supportWeights[i] = target.supportWeight;
            opposeWeights[i] = target.opposeWeight;
        }
    }

    function senderIdDenyDetailsBatch(uint256 groupId, uint256[] calldata targetSenderIds)
        external
        view
        returns (bool[] memory denied, uint256[] memory supportWeights, uint256[] memory opposeWeights)
    {
        ChatState storage state = _states[groupId];
        denied = new bool[](targetSenderIds.length);
        supportWeights = new uint256[](targetSenderIds.length);
        opposeWeights = new uint256[](targetSenderIds.length);
        for (uint256 i = 0; i < targetSenderIds.length; i++) {
            uint256 targetSenderId = targetSenderIds[i];
            TargetState storage target = state.senderIdTargetStates[targetSenderId];
            denied[i] = _contains(state.senderIdDenyList, targetSenderId);
            supportWeights[i] = target.supportWeight;
            opposeWeights[i] = target.opposeWeight;
        }
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
        uint256 totalWeight = _totalVoteWeightOrRevert(source, groupId);

        ChatState storage state = _states[groupId];
        TargetState storage target = state.addressTargetStates[targetAddress];
        VoteState storage vote = target.votes[voter];
        bool voteExists = vote.settledWeight != 0;
        if (voteExists && vote.supportDeny == supportDeny && vote.settledWeight == weight) {
            return _syncAddressDenyList(state, groupId, targetAddress, totalWeight, newVersion);
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
        newVersion = _syncAddressDenyList(state, groupId, targetAddress, totalWeight, newVersion);
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
        address source = _sourceOrRevert(groupId);
        uint256 totalWeight = _totalVoteWeightOrRevert(source, groupId);

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
        newVersion = _syncAddressDenyList(state, groupId, targetAddress, totalWeight, newVersion);
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
        uint256 totalWeight = _totalVoteWeightOrRevert(source, groupId);

        ChatState storage state = _states[groupId];
        TargetState storage target = state.addressTargetStates[targetAddress];
        VoteState storage vote = target.votes[voter];
        if (vote.settledWeight == 0) {
            return (false, newVersion);
        }

        uint256 weight = _voteWeightOrRevert(source, groupId, voter);
        if (weight == vote.settledWeight) {
            newVersion = _syncAddressDenyList(state, groupId, targetAddress, totalWeight, newVersion);
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
            newVersion = _syncAddressDenyList(state, groupId, targetAddress, totalWeight, newVersion);
            return (true, newVersion);
        }

        _addWeight(target, vote.supportDeny, weight);
        vote.settledWeight = weight;
        newVersion = _ensureStateVersion(state, newVersion);
        _emitAddressVoteSet(state, groupId, targetAddress, voter, vote.supportDeny, weight, newVersion);
        newVersion = _syncAddressDenyList(state, groupId, targetAddress, totalWeight, newVersion);
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
        uint256 totalWeight = _totalVoteWeightOrRevert(source, groupId);

        ChatState storage state = _states[groupId];
        TargetState storage target = state.senderIdTargetStates[targetSenderId];
        VoteState storage vote = target.votes[voter];
        bool voteExists = vote.settledWeight != 0;
        if (voteExists && vote.supportDeny == supportDeny && vote.settledWeight == weight) {
            return _syncSenderIdDenyList(state, groupId, targetSenderId, totalWeight, newVersion);
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
        newVersion = _syncSenderIdDenyList(state, groupId, targetSenderId, totalWeight, newVersion);
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
        address source = _sourceOrRevert(groupId);
        uint256 totalWeight = _totalVoteWeightOrRevert(source, groupId);

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
        newVersion = _syncSenderIdDenyList(state, groupId, targetSenderId, totalWeight, newVersion);
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
        uint256 totalWeight = _totalVoteWeightOrRevert(source, groupId);

        ChatState storage state = _states[groupId];
        TargetState storage target = state.senderIdTargetStates[targetSenderId];
        VoteState storage vote = target.votes[voter];
        if (vote.settledWeight == 0) {
            return (false, newVersion);
        }

        uint256 weight = _voteWeightOrRevert(source, groupId, voter);
        if (weight == vote.settledWeight) {
            newVersion = _syncSenderIdDenyList(state, groupId, targetSenderId, totalWeight, newVersion);
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
            newVersion = _syncSenderIdDenyList(state, groupId, targetSenderId, totalWeight, newVersion);
            return (true, newVersion);
        }

        _addWeight(target, vote.supportDeny, weight);
        vote.settledWeight = weight;
        newVersion = _ensureStateVersion(state, newVersion);
        _emitSenderIdVoteSet(state, groupId, targetSenderId, voter, vote.supportDeny, weight, newVersion);
        newVersion = _syncSenderIdDenyList(state, groupId, targetSenderId, totalWeight, newVersion);
        return (true, newVersion);
    }

    function _setSenderVote(
        uint256 groupId,
        uint256 targetSenderId,
        address targetAddress,
        address voter,
        bool supportDeny
    ) internal {
        _requireSenderTarget(targetSenderId, targetAddress);
        uint256 newVersion = _setAddressVoteIfChanged(groupId, targetAddress, voter, supportDeny, 0);
        newVersion = _setSenderIdVoteIfChanged(groupId, targetSenderId, voter, supportDeny, newVersion);
        if (newVersion == 0) {
            revert VoteUnchanged();
        }
        _emitStateVersionChanged(groupId, newVersion);
    }

    function _clearSenderVote(uint256 groupId, uint256 targetSenderId, address targetAddress, address voter) internal {
        _requireSenderTarget(targetSenderId, targetAddress);
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
        _requireSenderTarget(targetSenderId, targetAddress);
        (bool addressFound, uint256 newVersion) = _revalidateAddressVoteIfFound(groupId, targetAddress, voter, 0);
        (bool senderIdFound, uint256 newVersion2) =
            _revalidateSenderIdVoteIfFound(groupId, targetSenderId, voter, newVersion);
        if (!addressFound && !senderIdFound) {
            revert VoteNotFound();
        }
        _emitStateVersionChangedIfChanged(groupId, newVersion2);
    }

    function _requireSenderTarget(uint256 targetSenderId, address targetAddress) internal pure {
        if (targetSenderId == 0) {
            revert TargetSenderIdZero();
        }
        if (targetAddress == address(0)) {
            revert TargetAddressZero();
        }
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

    function _syncAddressDenyList(
        ChatState storage state,
        uint256 groupId,
        address targetAddress,
        uint256 totalWeight,
        uint256 newVersion
    ) internal returns (uint256) {
        bool shouldList = _isTargetDenied(state.addressTargetStates[targetAddress], totalWeight);
        if (_contains(state.addressDenyList, targetAddress) == shouldList) {
            return newVersion;
        }

        newVersion = _ensureStateVersion(state, newVersion);
        if (shouldList) {
            _addAddress(state.addressDenyList, targetAddress);
        } else {
            _removeAddress(state.addressDenyList, targetAddress);
        }
        emit AddressDenySet(groupId, targetAddress, shouldList, newVersion);
        return newVersion;
    }

    function _syncSenderIdDenyList(
        ChatState storage state,
        uint256 groupId,
        uint256 targetSenderId,
        uint256 totalWeight,
        uint256 newVersion
    ) internal returns (uint256) {
        bool shouldList = _isTargetDenied(state.senderIdTargetStates[targetSenderId], totalWeight);
        if (_contains(state.senderIdDenyList, targetSenderId) == shouldList) {
            return newVersion;
        }

        newVersion = _ensureStateVersion(state, newVersion);
        if (shouldList) {
            _addUint(state.senderIdDenyList, targetSenderId);
        } else {
            _removeUint(state.senderIdDenyList, targetSenderId);
        }
        emit SenderIdDenySet(groupId, targetSenderId, shouldList, newVersion);
        return newVersion;
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

    function _sourceHasCode(uint256 groupId) internal view returns (bool) {
        try ILOVE20Group(GROUP_ADDRESS).ownerOf(groupId) returns (address source) {
            return source.code.length != 0;
        } catch {
            return false;
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
        if (totalWeight == 0) {
            return false;
        }
        if (!_supportOutweighsOppose(target)) {
            return false;
        }
        return target.supportWeight * PERCENT_DENOMINATOR >= totalWeight * DENY_THRESHOLD_BPS;
    }

    function _contains(AddressSet storage set, address value) internal view returns (bool) {
        return set.indexPlusOne[value] != 0;
    }

    function _contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return set.indexPlusOne[value] != 0;
    }

    function _addAddress(AddressSet storage set, address value) internal returns (bool) {
        if (_contains(set, value)) {
            return false;
        }
        set.values.push(value);
        set.indexPlusOne[value] = set.values.length;
        return true;
    }

    function _removeAddress(AddressSet storage set, address value) internal returns (bool) {
        uint256 indexPlusOne = set.indexPlusOne[value];
        if (indexPlusOne == 0) {
            return false;
        }

        uint256 index = indexPlusOne - 1;
        uint256 lastIndex = set.values.length - 1;
        if (index != lastIndex) {
            address last = set.values[lastIndex];
            set.values[index] = last;
            set.indexPlusOne[last] = indexPlusOne;
        }
        set.values.pop();
        delete set.indexPlusOne[value];
        return true;
    }

    function _addUint(UintSet storage set, uint256 value) internal returns (bool) {
        if (_contains(set, value)) {
            return false;
        }
        set.values.push(value);
        set.indexPlusOne[value] = set.values.length;
        return true;
    }

    function _removeUint(UintSet storage set, uint256 value) internal returns (bool) {
        uint256 indexPlusOne = set.indexPlusOne[value];
        if (indexPlusOne == 0) {
            return false;
        }

        uint256 index = indexPlusOne - 1;
        uint256 lastIndex = set.values.length - 1;
        if (index != lastIndex) {
            uint256 last = set.values[lastIndex];
            set.values[index] = last;
            set.indexPlusOne[last] = indexPlusOne;
        }
        set.values.pop();
        delete set.indexPlusOne[value];
        return true;
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
