// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

contract MockLOVE20Group {
    uint256 internal _nextTokenId = 1;
    mapping(uint256 => address) internal _owners;

    function mint(address to) external returns (uint256 tokenId) {
        tokenId = _nextTokenId++;
        _owners[tokenId] = to;
    }

    function ownerOf(uint256 tokenId) external view returns (address owner) {
        owner = _owners[tokenId];
        require(owner != address(0), "NOT_MINTED");
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        require(_owners[tokenId] == from, "NOT_OWNER");
        _owners[tokenId] = to;
    }
}
