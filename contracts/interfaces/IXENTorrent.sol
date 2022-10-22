// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IXENTorrent {

    function bulkClaimRank(uint256 count, uint256 term) external;

    function bulkClaimMintReward(uint256 tokenId, address to) external;

}
