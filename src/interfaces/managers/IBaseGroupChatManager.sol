// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IDenyVoteWeightSource} from "../IDenyVoteWeightSource.sol";
import {IPostScopeSource} from "../IPostScopeSource.sol";
import {IERC721Receiver} from "../external/IERC721Receiver.sol";

interface IBaseGroupChatManager is IPostScopeSource, IDenyVoteWeightSource, IERC721Receiver {
    error ManagerAddressHasNoCode();
    error ChatAlreadyManaged();
    error RecentRoundsZero();
    error ManagerGroupNameUnavailable();
    error ManagerMintCostChanged();
    error ManagerPaymentFailed();
    error ManagerApprovalFailed();

    function GROUP_CHAT() external view returns (address);

    function LOVE20_GROUP() external view returns (address);

    function MAX_GROUP_NAME_LENGTH() external view returns (uint256);

    function DENY_SOURCE() external view returns (address);

    function BEFORE_POST_PLUGIN() external view returns (address);

    function AFTER_POST_PLUGIN() external view returns (address);
}
