// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IPostDenySource} from "../../IPostDenySource.sol";

interface IGovVotedDenySource is IPostDenySource {
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

    function voteDenySenderGroupId(uint256 chatGroupId, uint256 targetSenderGroupId) external;

    function opposeDenySenderGroupId(uint256 chatGroupId, uint256 targetSenderGroupId) external;

    function clearDenySenderGroupIdVote(uint256 chatGroupId, uint256 targetSenderGroupId) external;

    function revalidateDenySenderGroupIdVote(uint256 chatGroupId, uint256 targetSenderGroupId, address voter)
        external;

    function voteDenySenderBySenderGroupId(uint256 chatGroupId, uint256 targetSenderGroupId) external;

    function opposeDenySenderBySenderGroupId(uint256 chatGroupId, uint256 targetSenderGroupId) external;

    function clearDenySenderVoteBySenderGroupId(uint256 chatGroupId, uint256 targetSenderGroupId) external;

    function revalidateDenySenderVoteBySenderGroupId(uint256 chatGroupId, uint256 targetSenderGroupId, address voter)
        external;

    function voteDenySenderBySenderAddress(uint256 chatGroupId, address targetAddress) external;

    function opposeDenySenderBySenderAddress(uint256 chatGroupId, address targetAddress) external;

    function clearDenySenderVoteBySenderAddress(uint256 chatGroupId, address targetAddress) external;

    function revalidateDenySenderVoteBySenderAddress(uint256 chatGroupId, address targetAddress, address voter)
        external;

    function addressDenyVoteOf(uint256 chatGroupId, address targetAddress, address voter)
        external
        view
        returns (bool supportDeny, uint256 settledWeight);

    function senderGroupIdDenyVoteOf(uint256 chatGroupId, uint256 targetSenderGroupId, address voter)
        external
        view
        returns (bool supportDeny, uint256 settledWeight);

    function addressDenyTallyOf(uint256 chatGroupId, address targetAddress)
        external
        view
        returns (uint256 supportWeight, uint256 opposeWeight);

    function senderGroupIdDenyTallyOf(uint256 chatGroupId, uint256 targetSenderGroupId)
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

    function senderGroupIdDenyTargetsCount(uint256 chatGroupId) external view returns (uint256);

    function senderGroupIdDenyTargets(uint256 chatGroupId, uint256 offset, uint256 limit)
        external
        view
        returns (
            uint256[] memory targetSenderGroupIds,
            uint256[] memory supportWeights,
            uint256[] memory opposeWeights,
            uint256[] memory voterCounts
        );

    function addressDenyVotersCount(uint256 chatGroupId, address targetAddress) external view returns (uint256);

    function addressDenyVoters(uint256 chatGroupId, address targetAddress, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory voters, bool[] memory supportDenies, uint256[] memory settledWeights);

    function senderGroupIdDenyVotersCount(uint256 chatGroupId, uint256 targetSenderGroupId)
        external
        view
        returns (uint256);

    function senderGroupIdDenyVoters(uint256 chatGroupId, uint256 targetSenderGroupId, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory voters, bool[] memory supportDenies, uint256[] memory settledWeights);

    function stateVersion(uint256 chatGroupId) external view returns (uint256);
}
