// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IPostDenySource} from "../IPostDenySource.sol";

interface IGovVotedDenySource is IPostDenySource {
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

    function GROUP_ADDRESS() external view returns (address);

    function PRECISION() external view returns (uint256);

    function DENY_THRESHOLD_RATIO() external view returns (uint256);

    function voteBySenderAddress(uint256 groupId, address senderAddress, bool supportDeny) external;

    function clearVoteBySenderAddress(uint256 groupId, address senderAddress) external;

    function refreshVoteBySenderAddress(uint256 groupId, address senderAddress, address voter) external;

    function voteBySenderId(uint256 groupId, uint256 senderId, bool supportDeny) external;

    function clearVoteBySenderId(uint256 groupId, uint256 senderId) external;

    function refreshVoteBySenderId(uint256 groupId, uint256 senderId, address voter) external;

    function voteBySender(uint256 groupId, uint256 senderId, address senderAddress, bool supportDeny) external;

    function clearVoteBySender(uint256 groupId, uint256 senderId, address senderAddress) external;

    function refreshVoteBySender(uint256 groupId, uint256 senderId, address senderAddress, address voter) external;

    function voteWeightsBySenderAddressesByVoter(uint256 groupId, address[] calldata senderAddresses, address voter)
        external
        view
        returns (uint256[] memory supportWeights, uint256[] memory opposeWeights);

    function voteStatusBySenderAddress(uint256 groupId, address senderAddress)
        external
        view
        returns (bool denied, uint256 supportWeight, uint256 opposeWeight);

    function voteStatusBySenderAddresses(uint256 groupId, address[] calldata senderAddresses)
        external
        view
        returns (bool[] memory denied, uint256[] memory supportWeights, uint256[] memory opposeWeights);

    function isAddressDenied(uint256 groupId, address senderAddress) external view returns (bool);

    function isAddressDeniedBatch(uint256 groupId, address[] calldata senderAddresses)
        external
        view
        returns (bool[] memory denied);

    function votedSenderAddressesCount(uint256 groupId) external view returns (uint256);

    function votedSenderAddresses(uint256 groupId, uint256 offset, uint256 limit)
        external
        view
        returns (
            address[] memory senderAddresses,
            uint256[] memory supportWeights,
            uint256[] memory opposeWeights,
            uint256[] memory voterCounts
        );

    function votersBySenderAddressCount(uint256 groupId, address senderAddress) external view returns (uint256);

    function votersBySenderAddress(uint256 groupId, address senderAddress, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory voters, uint256[] memory supportWeights, uint256[] memory opposeWeights);

    function voteWeightsBySenderIdsByVoter(uint256 groupId, uint256[] calldata senderIds, address voter)
        external
        view
        returns (uint256[] memory supportWeights, uint256[] memory opposeWeights);

    function voteStatusBySenderId(uint256 groupId, uint256 senderId)
        external
        view
        returns (bool denied, uint256 supportWeight, uint256 opposeWeight);

    function voteStatusBySenderIds(uint256 groupId, uint256[] calldata senderIds)
        external
        view
        returns (bool[] memory denied, uint256[] memory supportWeights, uint256[] memory opposeWeights);

    function isSenderIdDenied(uint256 groupId, uint256 senderId) external view returns (bool);

    function isSenderIdDeniedBatch(uint256 groupId, uint256[] calldata senderIds)
        external
        view
        returns (bool[] memory denied);

    function votedSenderIdsCount(uint256 groupId) external view returns (uint256);

    function votedSenderIds(uint256 groupId, uint256 offset, uint256 limit)
        external
        view
        returns (
            uint256[] memory senderIds,
            uint256[] memory supportWeights,
            uint256[] memory opposeWeights,
            uint256[] memory voterCounts
        );

    function votersBySenderIdCount(uint256 groupId, uint256 senderId) external view returns (uint256);

    function votersBySenderId(uint256 groupId, uint256 senderId, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory voters, uint256[] memory supportWeights, uint256[] memory opposeWeights);

    function stateVersion(uint256 groupId) external view returns (uint256);
}
