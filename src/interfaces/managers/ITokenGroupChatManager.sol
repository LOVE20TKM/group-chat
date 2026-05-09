// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IBaseTokenGroupChatManager} from "./IBaseTokenGroupChatManager.sol";

interface ITokenGroupChatManager is IBaseTokenGroupChatManager {
    function JOIN_ADDRESS() external view returns (address);

    function VOTE_ADDRESS() external view returns (address);
}
