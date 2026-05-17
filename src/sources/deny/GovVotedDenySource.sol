// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20Group} from "../../interfaces/external/ILOVE20Group.sol";

import {IDenyVoteWeightSource} from "../../interfaces/sources/deny/IDenyVoteWeightSource.sol";
import {IGovVotedDenySource} from "../../interfaces/sources/deny/IGovVotedDenySource.sol";
import {EnumerableSets} from "../../libraries/EnumerableSets.sol";

contract GovVotedDenySource is IGovVotedDenySource {
    using EnumerableSets for EnumerableSets.AddressSet;
    using EnumerableSets for EnumerableSets.UintSet;

    address public immutable GROUP_ADDRESS;
    uint256 public constant PRECISION = 1e18;
    uint256 public immutable DENY_THRESHOLD_RATIO;

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
        EnumerableSets.AddressSet addressDenyList;
        EnumerableSets.UintSet senderIdDenyList;
    }

    enum TargetKind {
        SenderAddress,
        SenderId
    }

    struct TargetKey {
        TargetKind kind;
        address targetAddress;
        uint256 targetSenderId;
    }

    mapping(uint256 => ChatState) internal _states;

    constructor(address groupAddress_, uint256 denyThresholdRatio_) {
        if (groupAddress_.code.length == 0) {
            revert GovVotedDenySourceAddressHasNoCode();
        }
        if (denyThresholdRatio_ > PRECISION) {
            revert DenyThresholdTooHigh();
        }
        GROUP_ADDRESS = groupAddress_;
        DENY_THRESHOLD_RATIO = denyThresholdRatio_;
    }

    function voteBySenderAddress(uint256 groupId, address senderAddress, bool supportDeny) external {
        _setAddressVote(groupId, senderAddress, msg.sender, supportDeny);
    }

    function clearVoteBySenderAddress(uint256 groupId, address senderAddress) external {
        _clearAddressVote(groupId, senderAddress, msg.sender);
    }

    function refreshVoteBySenderAddress(uint256 groupId, address senderAddress, address voter) external {
        _refreshAddressVote(groupId, senderAddress, voter);
    }

    function voteBySenderId(uint256 groupId, uint256 senderId, bool supportDeny) external {
        _setSenderIdVote(groupId, senderId, msg.sender, supportDeny);
    }

    function clearVoteBySenderId(uint256 groupId, uint256 senderId) external {
        _clearSenderIdVote(groupId, senderId, msg.sender);
    }

    function refreshVoteBySenderId(uint256 groupId, uint256 senderId, address voter) external {
        _refreshSenderIdVote(groupId, senderId, voter);
    }

    function voteBySender(uint256 groupId, uint256 senderId, address senderAddress, bool supportDeny) external {
        _setSenderVote(groupId, senderId, senderAddress, msg.sender, supportDeny);
    }

    function clearVoteBySender(uint256 groupId, uint256 senderId, address senderAddress) external {
        _clearSenderVote(groupId, senderId, senderAddress, msg.sender);
    }

    function refreshVoteBySender(uint256 groupId, uint256 senderId, address senderAddress, address voter) external {
        _refreshSenderVote(groupId, senderId, senderAddress, voter);
    }

    function voteWeightsBySenderAddressByVoter(uint256 groupId, address senderAddress, address voter)
        external
        view
        returns (uint256 supportWeight, uint256 opposeWeight)
    {
        if (!_sourceHasCode(groupId)) {
            return (0, 0);
        }
        VoteState storage vote = _states[groupId].addressTargetStates[senderAddress].votes[voter];
        return _voteWeights(vote);
    }

    function voteWeightsBySenderIdByVoter(uint256 groupId, uint256 senderId, address voter)
        external
        view
        returns (uint256 supportWeight, uint256 opposeWeight)
    {
        if (!_sourceHasCode(groupId)) {
            return (0, 0);
        }
        VoteState storage vote = _states[groupId].senderIdTargetStates[senderId].votes[voter];
        return _voteWeights(vote);
    }

    function voteStatusBySenderAddress(uint256 groupId, address senderAddress)
        external
        view
        returns (bool denied, uint256 supportWeight, uint256 opposeWeight)
    {
        if (!_sourceHasCode(groupId)) {
            return (false, 0, 0);
        }
        ChatState storage state = _states[groupId];
        TargetState storage target = state.addressTargetStates[senderAddress];
        return (state.addressDenyList.contains(senderAddress), target.supportWeight, target.opposeWeight);
    }

    function voteStatusBySenderId(uint256 groupId, uint256 senderId)
        external
        view
        returns (bool denied, uint256 supportWeight, uint256 opposeWeight)
    {
        if (!_sourceHasCode(groupId)) {
            return (false, 0, 0);
        }
        ChatState storage state = _states[groupId];
        TargetState storage target = state.senderIdTargetStates[senderId];
        return (state.senderIdDenyList.contains(senderId), target.supportWeight, target.opposeWeight);
    }

    function votedSenderAddressesCount(uint256 groupId) external view returns (uint256) {
        if (!_sourceHasCode(groupId)) {
            return 0;
        }
        return _states[groupId].addressTargets.length;
    }

    function votedSenderAddresses(uint256 groupId, uint256 offset, uint256 limit)
        external
        view
        returns (
            address[] memory senderAddresses,
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
        senderAddresses = new address[](count);
        supportWeights = new uint256[](count);
        opposeWeights = new uint256[](count);
        voterCounts = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            address senderAddress = state.addressTargets[offset + i];
            TargetState storage target = state.addressTargetStates[senderAddress];
            senderAddresses[i] = senderAddress;
            supportWeights[i] = target.supportWeight;
            opposeWeights[i] = target.opposeWeight;
            voterCounts[i] = target.voters.length;
        }
    }

    function votedSenderIdsCount(uint256 groupId) external view returns (uint256) {
        if (!_sourceHasCode(groupId)) {
            return 0;
        }
        return _states[groupId].senderIdTargets.length;
    }

    function votedSenderIds(uint256 groupId, uint256 offset, uint256 limit)
        external
        view
        returns (
            uint256[] memory senderIds,
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
        senderIds = new uint256[](count);
        supportWeights = new uint256[](count);
        opposeWeights = new uint256[](count);
        voterCounts = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 senderId = state.senderIdTargets[offset + i];
            TargetState storage target = state.senderIdTargetStates[senderId];
            senderIds[i] = senderId;
            supportWeights[i] = target.supportWeight;
            opposeWeights[i] = target.opposeWeight;
            voterCounts[i] = target.voters.length;
        }
    }

    function votersBySenderAddressCount(uint256 groupId, address senderAddress) external view returns (uint256) {
        if (!_sourceHasCode(groupId)) {
            return 0;
        }
        return _states[groupId].addressTargetStates[senderAddress].voters.length;
    }

    function votersBySenderAddress(uint256 groupId, address senderAddress, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory voters, uint256[] memory supportWeights, uint256[] memory opposeWeights)
    {
        if (!_sourceHasCode(groupId)) {
            return (new address[](0), new uint256[](0), new uint256[](0));
        }
        return _votersPage(_states[groupId].addressTargetStates[senderAddress], offset, limit);
    }

    function votersBySenderIdCount(uint256 groupId, uint256 senderId) external view returns (uint256) {
        if (!_sourceHasCode(groupId)) {
            return 0;
        }
        return _states[groupId].senderIdTargetStates[senderId].voters.length;
    }

    function votersBySenderId(uint256 groupId, uint256 senderId, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory voters, uint256[] memory supportWeights, uint256[] memory opposeWeights)
    {
        if (!_sourceHasCode(groupId)) {
            return (new address[](0), new uint256[](0), new uint256[](0));
        }
        return _votersPage(_states[groupId].senderIdTargetStates[senderId], offset, limit);
    }

    function isDenied(uint256 groupId, uint256 senderId, address senderAddress) external view returns (bool) {
        ChatState storage state = _states[groupId];
        return state.addressDenyList.contains(senderAddress) || state.senderIdDenyList.contains(senderId);
    }

    function isAddressDenied(uint256 groupId, address senderAddress) external view returns (bool) {
        return _states[groupId].addressDenyList.contains(senderAddress);
    }

    function isSenderIdDenied(uint256 groupId, uint256 senderId) external view returns (bool) {
        return _states[groupId].senderIdDenyList.contains(senderId);
    }

    function isAddressDeniedBatch(uint256 groupId, address[] calldata senderAddresses)
        external
        view
        returns (bool[] memory denied)
    {
        ChatState storage state = _states[groupId];
        denied = new bool[](senderAddresses.length);
        for (uint256 i = 0; i < senderAddresses.length; i++) {
            denied[i] = state.addressDenyList.contains(senderAddresses[i]);
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
            denied[i] = state.senderIdDenyList.contains(senderIds[i]);
        }
    }

    function voteStatusBySenderAddresses(uint256 groupId, address[] calldata senderAddresses)
        external
        view
        returns (bool[] memory denied, uint256[] memory supportWeights, uint256[] memory opposeWeights)
    {
        ChatState storage state = _states[groupId];
        denied = new bool[](senderAddresses.length);
        supportWeights = new uint256[](senderAddresses.length);
        opposeWeights = new uint256[](senderAddresses.length);
        for (uint256 i = 0; i < senderAddresses.length; i++) {
            address senderAddress = senderAddresses[i];
            TargetState storage target = state.addressTargetStates[senderAddress];
            denied[i] = state.addressDenyList.contains(senderAddress);
            supportWeights[i] = target.supportWeight;
            opposeWeights[i] = target.opposeWeight;
        }
    }

    function voteStatusBySenderIds(uint256 groupId, uint256[] calldata senderIds)
        external
        view
        returns (bool[] memory denied, uint256[] memory supportWeights, uint256[] memory opposeWeights)
    {
        ChatState storage state = _states[groupId];
        denied = new bool[](senderIds.length);
        supportWeights = new uint256[](senderIds.length);
        opposeWeights = new uint256[](senderIds.length);
        for (uint256 i = 0; i < senderIds.length; i++) {
            uint256 senderId = senderIds[i];
            TargetState storage target = state.senderIdTargetStates[senderId];
            denied[i] = state.senderIdDenyList.contains(senderId);
            supportWeights[i] = target.supportWeight;
            opposeWeights[i] = target.opposeWeight;
        }
    }

    function stateVersion(uint256 groupId) external view returns (uint256) {
        return _states[groupId].stateVersion;
    }

    function _setAddressVote(uint256 groupId, address targetAddress, address voter, bool supportDeny) internal {
        uint256 newVersion =
            _setVoteIfChanged(groupId, TargetKey(TargetKind.SenderAddress, targetAddress, 0), voter, supportDeny, 0);
        if (newVersion == 0) {
            revert VoteUnchanged();
        }
        _emitStateVersionChanged(groupId, newVersion);
    }

    function _setSenderIdVote(uint256 groupId, uint256 targetSenderId, address voter, bool supportDeny) internal {
        uint256 newVersion = _setVoteIfChanged(
            groupId, TargetKey(TargetKind.SenderId, address(0), targetSenderId), voter, supportDeny, 0
        );
        if (newVersion == 0) {
            revert VoteUnchanged();
        }
        _emitStateVersionChanged(groupId, newVersion);
    }

    function _setVoteIfChanged(
        uint256 groupId,
        TargetKey memory key,
        address voter,
        bool supportDeny,
        uint256 newVersion
    ) internal returns (uint256) {
        _requireTarget(key);
        address source = _sourceOrRevert(groupId);
        uint256 weight = _voteWeightOrRevert(source, groupId, voter);
        if (weight == 0) {
            revert VoteWeightZero();
        }
        uint256 totalWeight = _totalVoteWeightOrRevert(source, groupId);

        ChatState storage state = _states[groupId];
        TargetState storage target = _targetState(state, key);
        VoteState storage vote = target.votes[voter];
        bool voteExists = vote.settledWeight != 0;
        if (voteExists && vote.supportDeny == supportDeny && vote.settledWeight == weight) {
            return _syncDenyList(state, groupId, key, totalWeight, newVersion);
        }

        if (!voteExists) {
            _addTarget(state, key);
            _addVoter(target, voter);
        } else {
            _removeWeight(target, vote.supportDeny, vote.settledWeight);
        }

        _addWeight(target, supportDeny, weight);
        vote.supportDeny = supportDeny;
        vote.settledWeight = weight;
        newVersion = _ensureStateVersion(state, newVersion);
        _emitVoteSet(state, groupId, key, voter, supportDeny, weight, newVersion);
        newVersion = _syncDenyList(state, groupId, key, totalWeight, newVersion);
        return newVersion;
    }

    function _clearAddressVote(uint256 groupId, address targetAddress, address voter) internal {
        uint256 newVersion = _clearVoteIfFound(groupId, TargetKey(TargetKind.SenderAddress, targetAddress, 0), voter, 0);
        if (newVersion == 0) {
            revert VoteNotFound();
        }
        _emitStateVersionChanged(groupId, newVersion);
    }

    function _clearSenderIdVote(uint256 groupId, uint256 targetSenderId, address voter) internal {
        uint256 newVersion =
            _clearVoteIfFound(groupId, TargetKey(TargetKind.SenderId, address(0), targetSenderId), voter, 0);
        if (newVersion == 0) {
            revert VoteNotFound();
        }
        _emitStateVersionChanged(groupId, newVersion);
    }

    function _clearVoteIfFound(uint256 groupId, TargetKey memory key, address voter, uint256 newVersion)
        internal
        returns (uint256)
    {
        _requireTarget(key);
        address source = _sourceOrRevert(groupId);
        uint256 totalWeight = _totalVoteWeightOrRevert(source, groupId);

        ChatState storage state = _states[groupId];
        TargetState storage target = _targetState(state, key);
        VoteState storage vote = target.votes[voter];
        if (vote.settledWeight == 0) {
            return newVersion;
        }

        _removeVote(state, target, key, voter);
        newVersion = _ensureStateVersion(state, newVersion);
        _emitVoteSet(state, groupId, key, voter, false, 0, newVersion);
        newVersion = _syncDenyList(state, groupId, key, totalWeight, newVersion);
        return newVersion;
    }

    function _refreshAddressVote(uint256 groupId, address targetAddress, address voter) internal {
        (bool found, uint256 newVersion) =
            _refreshVoteIfFound(groupId, TargetKey(TargetKind.SenderAddress, targetAddress, 0), voter, 0);
        if (!found) {
            revert VoteNotFound();
        }
        _emitStateVersionChangedIfChanged(groupId, newVersion);
    }

    function _refreshSenderIdVote(uint256 groupId, uint256 targetSenderId, address voter) internal {
        (bool found, uint256 newVersion) =
            _refreshVoteIfFound(groupId, TargetKey(TargetKind.SenderId, address(0), targetSenderId), voter, 0);
        if (!found) {
            revert VoteNotFound();
        }
        _emitStateVersionChangedIfChanged(groupId, newVersion);
    }

    function _refreshVoteIfFound(uint256 groupId, TargetKey memory key, address voter, uint256 newVersion)
        internal
        returns (bool found, uint256)
    {
        _requireTarget(key);
        address source = _sourceOrRevert(groupId);
        uint256 totalWeight = _totalVoteWeightOrRevert(source, groupId);

        ChatState storage state = _states[groupId];
        TargetState storage target = _targetState(state, key);
        VoteState storage vote = target.votes[voter];
        if (vote.settledWeight == 0) {
            return (false, newVersion);
        }

        uint256 weight = _voteWeightOrRevert(source, groupId, voter);
        if (weight == vote.settledWeight) {
            newVersion = _syncDenyList(state, groupId, key, totalWeight, newVersion);
            return (true, newVersion);
        }

        _removeWeight(target, vote.supportDeny, vote.settledWeight);
        if (weight == 0) {
            _removeVoteAfterWeightRemoved(state, target, key, voter);
            newVersion = _ensureStateVersion(state, newVersion);
            _emitVoteSet(state, groupId, key, voter, false, 0, newVersion);
            newVersion = _syncDenyList(state, groupId, key, totalWeight, newVersion);
            return (true, newVersion);
        }

        _addWeight(target, vote.supportDeny, weight);
        vote.settledWeight = weight;
        newVersion = _ensureStateVersion(state, newVersion);
        _emitVoteSet(state, groupId, key, voter, vote.supportDeny, weight, newVersion);
        newVersion = _syncDenyList(state, groupId, key, totalWeight, newVersion);
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
        uint256 newVersion =
            _setVoteIfChanged(groupId, TargetKey(TargetKind.SenderAddress, targetAddress, 0), voter, supportDeny, 0);
        newVersion = _setVoteIfChanged(
            groupId, TargetKey(TargetKind.SenderId, address(0), targetSenderId), voter, supportDeny, newVersion
        );
        if (newVersion == 0) {
            revert VoteUnchanged();
        }
        _emitStateVersionChanged(groupId, newVersion);
    }

    function _clearSenderVote(uint256 groupId, uint256 targetSenderId, address targetAddress, address voter) internal {
        _requireSenderTarget(targetSenderId, targetAddress);
        uint256 newVersion = _clearVoteIfFound(groupId, TargetKey(TargetKind.SenderAddress, targetAddress, 0), voter, 0);
        newVersion =
            _clearVoteIfFound(groupId, TargetKey(TargetKind.SenderId, address(0), targetSenderId), voter, newVersion);
        if (newVersion == 0) {
            revert VoteNotFound();
        }
        _emitStateVersionChanged(groupId, newVersion);
    }

    function _refreshSenderVote(uint256 groupId, uint256 targetSenderId, address targetAddress, address voter)
        internal
    {
        _requireSenderTarget(targetSenderId, targetAddress);
        (bool addressFound, uint256 newVersion) =
            _refreshVoteIfFound(groupId, TargetKey(TargetKind.SenderAddress, targetAddress, 0), voter, 0);
        (bool senderIdFound, uint256 newVersion2) =
            _refreshVoteIfFound(groupId, TargetKey(TargetKind.SenderId, address(0), targetSenderId), voter, newVersion);
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

    function _emitVoteSet(
        ChatState storage state,
        uint256 groupId,
        TargetKey memory key,
        address voter,
        bool supportDeny,
        uint256 settledWeight,
        uint256 newVersion
    ) internal {
        TargetState storage target = _targetState(state, key);
        if (key.kind == TargetKind.SenderAddress) {
            emit AddressDenyVoteSet(
                groupId,
                key.targetAddress,
                voter,
                supportDeny,
                settledWeight,
                target.supportWeight,
                target.opposeWeight,
                newVersion
            );
        } else {
            emit SenderIdDenyVoteSet(
                groupId,
                key.targetSenderId,
                voter,
                supportDeny,
                settledWeight,
                target.supportWeight,
                target.opposeWeight,
                newVersion
            );
        }
    }

    function _syncDenyList(
        ChatState storage state,
        uint256 groupId,
        TargetKey memory key,
        uint256 totalWeight,
        uint256 newVersion
    ) internal returns (uint256) {
        bool shouldList = _isTargetDenied(_targetState(state, key), totalWeight);
        if (_isDenyListed(state, key) == shouldList) {
            return newVersion;
        }

        newVersion = _ensureStateVersion(state, newVersion);
        _setDenyListed(state, key, shouldList);
        _emitDenySet(groupId, key, shouldList, newVersion);
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
        try IDenyVoteWeightSource(source).voteWeightOf(groupId, voter) returns (uint256 resolved) {
            return resolved;
        } catch {
            revert DenyVoteWeightSourceUnavailable();
        }
    }

    function _totalVoteWeightOrRevert(address source, uint256 groupId) internal view returns (uint256) {
        try IDenyVoteWeightSource(source).totalVoteWeight(groupId) returns (uint256 resolved) {
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
        return target.supportWeight * PRECISION >= totalWeight * DENY_THRESHOLD_RATIO;
    }

    function _requireTarget(TargetKey memory key) internal pure {
        if (key.kind == TargetKind.SenderAddress) {
            if (key.targetAddress == address(0)) {
                revert TargetAddressZero();
            }
        } else if (key.targetSenderId == 0) {
            revert TargetSenderIdZero();
        }
    }

    function _targetState(ChatState storage state, TargetKey memory key) internal view returns (TargetState storage) {
        if (key.kind == TargetKind.SenderAddress) {
            return state.addressTargetStates[key.targetAddress];
        }
        return state.senderIdTargetStates[key.targetSenderId];
    }

    function _addTarget(ChatState storage state, TargetKey memory key) internal {
        if (key.kind == TargetKind.SenderAddress) {
            _addAddressTarget(state, key.targetAddress);
        } else {
            _addSenderIdTarget(state, key.targetSenderId);
        }
    }

    function _removeTarget(ChatState storage state, TargetKey memory key) internal {
        if (key.kind == TargetKind.SenderAddress) {
            _removeAddressTarget(state, key.targetAddress);
        } else {
            _removeSenderIdTarget(state, key.targetSenderId);
        }
    }

    function _removeVote(ChatState storage state, TargetState storage target, TargetKey memory key, address voter)
        internal
    {
        VoteState storage vote = target.votes[voter];
        _removeWeight(target, vote.supportDeny, vote.settledWeight);
        _removeVoteAfterWeightRemoved(state, target, key, voter);
    }

    function _removeVoteAfterWeightRemoved(
        ChatState storage state,
        TargetState storage target,
        TargetKey memory key,
        address voter
    ) internal {
        delete target.votes[voter];
        _removeVoter(target, voter);
        if (target.voters.length == 0) {
            _removeTarget(state, key);
        }
    }

    function _isDenyListed(ChatState storage state, TargetKey memory key) internal view returns (bool) {
        if (key.kind == TargetKind.SenderAddress) {
            return state.addressDenyList.contains(key.targetAddress);
        }
        return state.senderIdDenyList.contains(key.targetSenderId);
    }

    function _setDenyListed(ChatState storage state, TargetKey memory key, bool listed) internal {
        if (key.kind == TargetKind.SenderAddress) {
            if (listed) {
                state.addressDenyList.add(key.targetAddress);
            } else {
                state.addressDenyList.remove(key.targetAddress);
            }
        } else if (listed) {
            state.senderIdDenyList.add(key.targetSenderId);
        } else {
            state.senderIdDenyList.remove(key.targetSenderId);
        }
    }

    function _emitDenySet(uint256 groupId, TargetKey memory key, bool listed, uint256 newVersion) internal {
        if (key.kind == TargetKind.SenderAddress) {
            emit AddressDenySet(groupId, key.targetAddress, listed, newVersion);
        } else {
            emit SenderIdDenySet(groupId, key.targetSenderId, listed, newVersion);
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
        returns (address[] memory voters, uint256[] memory supportWeights, uint256[] memory opposeWeights)
    {
        uint256 count = _pageCount(target.voters.length, offset, limit);
        voters = new address[](count);
        supportWeights = new uint256[](count);
        opposeWeights = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            address voter = target.voters[offset + i];
            VoteState storage vote = target.votes[voter];
            voters[i] = voter;
            (supportWeights[i], opposeWeights[i]) = _voteWeights(vote);
        }
    }

    function _voteWeights(VoteState storage vote) internal view returns (uint256 supportWeight, uint256 opposeWeight) {
        if (vote.settledWeight == 0) {
            return (0, 0);
        }
        if (vote.supportDeny) {
            return (vote.settledWeight, 0);
        }
        return (0, vote.settledWeight);
    }

    function _pageCount(uint256 total, uint256 offset, uint256 limit) internal pure returns (uint256) {
        if (limit == 0 || offset >= total) {
            return 0;
        }

        uint256 remaining = total - offset;
        return remaining < limit ? remaining : limit;
    }
}
