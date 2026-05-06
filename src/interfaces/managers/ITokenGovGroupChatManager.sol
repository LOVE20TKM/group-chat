// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IBaseGroupChatManager} from "./IBaseGroupChatManager.sol";

interface ITokenGovGroupChatManager is IBaseGroupChatManager {
    function STAKE() external view returns (address);

    function EXTENSION_CENTER() external view returns (address);

    function tokenOf(uint256 chatGroupId) external view returns (address);

    function chatGroupIdOfToken(address token) external view returns (uint256);

    function activate(address token) external returns (uint256 chatGroupId);
}
