// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IERC721Receiver} from "../external/IERC721Receiver.sol";
import {IDenyVoteWeightSource} from "../sources/IDenyVoteWeightSource.sol";
import {IPostScopeSource} from "../sources/IPostScopeSource.sol";

interface IBaseManager is IPostScopeSource, IDenyVoteWeightSource, IERC721Receiver {
    error ManagerAddressHasNoCode();
    error AlreadyManaged();
    error RecentRoundsZero();
    error ManagerGroupNameUnavailable();
    error ManagerMintCostChanged();
    error ManagerPaymentFailed();
    error ManagerApprovalFailed();
    error TokenNotLOVE20();

    function GROUP_CHAT_ADDRESS() external view returns (address);

    function LOVE20_GROUP_ADDRESS() external view returns (address);

    function DENY_SOURCE_ADDRESS() external view returns (address);

    function BEFORE_POST_PLUGIN_ADDRESS() external view returns (address);

    function AFTER_POST_PLUGIN_ADDRESS() external view returns (address);
}
