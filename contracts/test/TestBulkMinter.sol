// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@faircrypto/xen-crypto/contracts/XENCrypto.sol";
import "../XENFT.sol";

contract TestBulkMinter is IERC721Receiver {
    XENCrypto private _xenCrypto;
    XENTorrent private _xenTorrent;

    constructor(address xenCrypto_, address xenTorrent_) {
        _xenCrypto = XENCrypto(xenCrypto_);
        _xenTorrent = XENTorrent(xenTorrent_);
    }

    function testBulkMintCollector() external {
        _xenTorrent.bulkClaimRank(1, 1);
    }

    function testBulkMintLimited() external {
        _xenTorrent.bulkClaimRankLimited(100, 1, 1_000 ether);
    }

    function testBulkMintRare() external {
        _xenTorrent.bulkClaimRankLimited(100, 1, 50_000 ether);
    }

    function approveXen(uint256 amount) external {
        _xenCrypto.approve(address(_xenTorrent), amount);
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
