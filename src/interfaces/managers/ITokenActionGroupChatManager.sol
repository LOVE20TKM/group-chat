// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IBaseTokenActionGroupChatManager} from "./IBaseTokenActionGroupChatManager.sol";

interface ITokenActionGroupChatManager is IBaseTokenActionGroupChatManager {
    function JOIN_ADDRESS() external view returns (address);
}
