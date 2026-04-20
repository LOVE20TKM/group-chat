// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IGroupNFTOwner {
    function ownerOf(uint256 tokenId) external view returns (address);
}
