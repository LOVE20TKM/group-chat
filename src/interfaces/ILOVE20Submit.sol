// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

struct ActionHead {
    uint256 id;
    address author;
    uint256 createAtBlock;
}

struct ActionBody {
    uint256 minStake;
    uint256 maxRandomAccounts;
    address whiteListAddress;
    string title;
    string verificationRule;
    string[] verificationKeys;
    string[] verificationInfoGuides;
}

struct ActionInfo {
    ActionHead head;
    ActionBody body;
}

interface ILOVE20Submit {
    function actionInfo(address tokenAddress, uint256 actionId) external view returns (ActionInfo memory);
}
