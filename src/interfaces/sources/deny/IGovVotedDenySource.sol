// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IPostDenySource} from "../../IPostDenySource.sol";

interface IGovVotedDenySource is IPostDenySource {
    error GovVotedDenySourceAddressHasNoCode();
    error DenyVoteWeightSourceUnavailable();
    error GroupNotExist();
    error TargetAddressZero();
    error TargetSenderIdZero();
    error VoteWeightZero();
    error VoteUnchanged();
    error VoteNotFound();

    event AddressDenyVoteSet(
        uint256 indexed chatGroupId,
        address indexed targetAddress,
        address indexed voter,
        bool supportDeny,
        uint256 settledWeight,
        uint256 supportWeight,
        uint256 opposeWeight,
        uint256 stateVersion
    );

    event SenderIdDenyVoteSet(
        uint256 indexed chatGroupId,
        uint256 indexed targetSenderId,
        address indexed voter,
        bool supportDeny,
        uint256 settledWeight,
        uint256 supportWeight,
        uint256 opposeWeight,
        uint256 stateVersion
    );

    event StateVersionChanged(uint256 indexed chatGroupId, uint256 stateVersion);

    function GROUP_ADDRESS() external view returns (address);

    function GROUP_DEFAULTS_ADDRESS() external view returns (address);

    function voteDenyAddress(uint256 chatGroupId, address targetAddress) external;

    function opposeDenyAddress(uint256 chatGroupId, address targetAddress) external;

    function clearDenyAddressVote(uint256 chatGroupId, address targetAddress) external;

    function revalidateDenyAddressVote(uint256 chatGroupId, address targetAddress, address voter) external;

    function voteDenySenderId(uint256 chatGroupId, uint256 targetSenderId) external;

    function opposeDenySenderId(uint256 chatGroupId, uint256 targetSenderId) external;

    function clearDenySenderIdVote(uint256 chatGroupId, uint256 targetSenderId) external;

    function revalidateDenySenderIdVote(uint256 chatGroupId, uint256 targetSenderId, address voter) external;

    function voteDenySenderBySenderId(uint256 chatGroupId, uint256 targetSenderId) external;

    function opposeDenySenderBySenderId(uint256 chatGroupId, uint256 targetSenderId) external;

    function clearDenySenderVoteBySenderId(uint256 chatGroupId, uint256 targetSenderId) external;

    function revalidateDenySenderVoteBySenderId(uint256 chatGroupId, uint256 targetSenderId, address voter) external;

    function voteDenySenderBySenderAddress(uint256 chatGroupId, address targetAddress) external;

    function opposeDenySenderBySenderAddress(uint256 chatGroupId, address targetAddress) external;

    function clearDenySenderVoteBySenderAddress(uint256 chatGroupId, address targetAddress) external;

    function revalidateDenySenderVoteBySenderAddress(uint256 chatGroupId, address targetAddress, address voter)
        external;

    function addressDenyVoteOf(uint256 chatGroupId, address targetAddress, address voter)
        external
        view
        returns (bool supportDeny, uint256 settledWeight);

    function addressDenyTallyOf(uint256 chatGroupId, address targetAddress)
        external
        view
        returns (uint256 supportWeight, uint256 opposeWeight);

    function addressDenyTargetsCount(uint256 chatGroupId) external view returns (uint256);

    function addressDenyTargets(uint256 chatGroupId, uint256 offset, uint256 limit)
        external
        view
        returns (
            address[] memory targetAddresses,
            uint256[] memory supportWeights,
            uint256[] memory opposeWeights,
            uint256[] memory voterCounts
        );

    function addressDenyVotersCount(uint256 chatGroupId, address targetAddress) external view returns (uint256);

    function addressDenyVoters(uint256 chatGroupId, address targetAddress, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory voters, bool[] memory supportDenies, uint256[] memory settledWeights);

    function senderIdDenyVoteOf(uint256 chatGroupId, uint256 targetSenderId, address voter)
        external
        view
        returns (bool supportDeny, uint256 settledWeight);

    function senderIdDenyTallyOf(uint256 chatGroupId, uint256 targetSenderId)
        external
        view
        returns (uint256 supportWeight, uint256 opposeWeight);

    function senderIdDenyTargetsCount(uint256 chatGroupId) external view returns (uint256);

    function senderIdDenyTargets(uint256 chatGroupId, uint256 offset, uint256 limit)
        external
        view
        returns (
            uint256[] memory targetSenderIds,
            uint256[] memory supportWeights,
            uint256[] memory opposeWeights,
            uint256[] memory voterCounts
        );

    function senderIdDenyVotersCount(uint256 chatGroupId, uint256 targetSenderId) external view returns (uint256);

    function senderIdDenyVoters(uint256 chatGroupId, uint256 targetSenderId, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory voters, bool[] memory supportDenies, uint256[] memory settledWeights);

    function stateVersion(uint256 chatGroupId) external view returns (uint256);
}
