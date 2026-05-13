// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IBaseGroupChatManager} from "./IBaseGroupChatManager.sol";

interface IBaseTokenGroupChatManager is IBaseGroupChatManager {
    function EXTENSION_CENTER_ADDRESS() external view returns (address);

    function activate(address token) external returns (uint256 groupId);

    function tokenOfGroup(uint256 groupId) external view returns (address);

    function groupIdOfToken(address token) external view returns (uint256);

    function tokensCount() external view returns (uint256);

    function tokens(uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (address[] memory tokenList, uint256[] memory groupIds);
}
