// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "../XENFT.sol";

contract ERC721BadHolder is IERC165, IERC721Receiver {
    XENTorrent public xenTorrent;

    constructor(address _xenTorrentAddress) {
        xenTorrent = XENTorrent(_xenTorrentAddress);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId;
    }

    function claimXENCommon(uint256 count, uint256 term) external {
        uint256 tokenId = xenTorrent.bulkClaimRank(count, term);
        require(tokenId > 10_000, "Unexpected tokenId received");
    }

    function claimXENSpecial(
        uint256 count,
        uint256 term,
        uint256 burning
    ) external {
        uint256 tokenId = xenTorrent.bulkClaimRankLimited(count, term, burning);
        require(tokenId > 0 && tokenId < 10_001, "Unexpected tokenId received");
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        revert();
    }
}
