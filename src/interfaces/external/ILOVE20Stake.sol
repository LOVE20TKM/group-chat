// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface ILOVE20Stake {
    function validGovVotes(address tokenAddress, address account) external view returns (uint256);
}
