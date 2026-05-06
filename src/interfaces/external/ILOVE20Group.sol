// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface ILOVE20Group {
    function ownerOf(uint256 tokenId) external view returns (address owner);
}
