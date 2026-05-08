// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IBaseGroupChatManager} from "./IBaseGroupChatManager.sol";

interface ITokenGroupChatManager is IBaseGroupChatManager {
    function STAKE_ADDRESS() external view returns (address);

    function JOIN_ADDRESS() external view returns (address);

    function VOTE_ADDRESS() external view returns (address);

    function SUBMIT_ADDRESS() external view returns (address);

    function EXTENSION_CENTER_ADDRESS() external view returns (address);

    function activate(address token) external returns (uint256 chatGroupId);

    function tokenOf(uint256 chatGroupId) external view returns (address);

    function chatGroupIdOfToken(address token) external view returns (uint256);

    function activatedTokensCount() external view returns (uint256);

    function activatedTokens(uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (address[] memory tokens, uint256[] memory chatGroupIds);
}
