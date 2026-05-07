// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IBaseGroupChatManager} from "./IBaseGroupChatManager.sol";

interface ITokenActionGovGroupChatManager is IBaseGroupChatManager {
    function VOTE_ADDRESS() external view returns (address);

    function EXTENSION_CENTER_ADDRESS() external view returns (address);

    function RECENT_ROUNDS() external view returns (uint256);

    function paramsOf(uint256 chatGroupId) external view returns (address token, uint256 actionId);

    function chatGroupIdOfAction(address token, uint256 actionId) external view returns (uint256);

    function activatedActionsCount(address token) external view returns (uint256);

    function activatedActions(address token, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (uint256[] memory actionIds, uint256[] memory chatGroupIds);

    function chatGroupIdsOfActions(address token, uint256[] calldata actionIds)
        external
        view
        returns (uint256[] memory chatGroupIds);

    function activate(address token, uint256 actionId) external returns (uint256 chatGroupId);
}
