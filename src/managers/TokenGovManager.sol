// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseTokenManager} from "./BaseTokenManager.sol";

contract TokenGovManager is BaseTokenManager {
    constructor(
        address groupChat_,
        address denySource_,
        address beforePostPlugin_,
        address afterPostPlugin_,
        address extensionCenter_
    ) BaseTokenManager(groupChat_, denySource_, beforePostPlugin_, afterPostPlugin_, extensionCenter_) {}

    function activate(address token) external returns (uint256 groupId) {
        return _activateToken(token, "mgr_token_gov_");
    }

    function canPost(uint256 groupId, uint256, address senderAddress) external view returns (bool) {
        address token = tokenOfGroup[groupId];
        return token != address(0) && _tokenGovVoteWeight(token, senderAddress) != 0;
    }
}
