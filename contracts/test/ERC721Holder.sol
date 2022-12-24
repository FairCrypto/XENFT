// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "../XENFT.sol";

contract ERC721Holder is IERC165, IERC721Receiver {
    XENCrypto public xenCrypto;
    XENTorrent public xenTorrent;

    constructor(address _xenCryptoAddress, address _xenTorrentAddress) {
        xenCrypto = XENCrypto(_xenCryptoAddress);
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
        xenCrypto.approve(address(xenTorrent), burning);
        uint256 tokenId = xenTorrent.bulkClaimRankLimited(count, term, burning);
        require(tokenId > 0, "Unexpected tokenId received");
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
