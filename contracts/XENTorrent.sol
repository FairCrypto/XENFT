// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import '@faircrypto/xen-crypto/contracts/XENCrypto.sol';
import './libs/SVG.sol';
import "./interfaces/IXENTorrent.sol";
import "./interfaces/IXENProxying.sol";

/*
    NFT props:
    - number of virtual minters
    - MintInfo (term, cRank, maturityDate) for each virtual minter
 */
contract XENTorrent is IXENTorrent, IXENProxying, ERC721("XEN Torrent", "XENTORR") {

    //using DateTime for uint256;
    using Strings for uint256;

    // essential info about Torrent Mint Ops
    struct MintInfo {
        uint256 term;
        uint256 rank;
        uint256 maturityTs;
    }

    uint256[] public COLORS = [206, 20, 331, 230];
    uint256[] public ANGLES = [45, 135, 225, 315];

    // original contract marking to distinguish from proxy copies
    address private immutable _original;
    // ever increasing counter for NFT tokenIds, also used as salt for proxies' spinning
    uint256 private _tokenIdCounter = 1;
    // pointer to XEN Crypto contract
    XENCrypto immutable public xenCrypto;
    // mapping: NFT tokenId => count of virtual minters
    mapping(uint256 => uint256) public minterInfo;
    // mapping: NFT tokenId => MintInfo (used in tokenURI generation)
    mapping(uint256 => MintInfo) public mints;

    constructor(address xenCrypto_) {
        require(xenCrypto_ != address(0));
        _original = address(this);
        xenCrypto = XENCrypto(xenCrypto_);
    }

    /**
        @dev private helper to generate SVG image based on Torrent params
     */
    function _svgData(uint256 tokenId) private view returns (bytes memory) {
        SVG.SvgParams memory params = SVG.SvgParams({
            symbol: "XEN",
            xenAddress: address(0),
            tokenId: tokenId,
            term: mints[tokenId].term,
            rank: mints[tokenId].rank,
            count: minterInfo[tokenId],
            maturityTs: mints[tokenId].maturityTs
        });
        return SVG.image(params, COLORS, ANGLES);
    }

    // TODO: remove after testing
    function genSVG(uint256 tokenId) public view returns (string memory) {
        return string(_svgData(tokenId));
    }

    /**
        @dev compliance with ERC-721 standard (NFT); returns NFT metadata, including SVG-encoded image
     */
    function tokenURI(uint256 tokenId) override public view returns (string memory) {
        uint256 count = minterInfo[tokenId];
        require(count > 0);
        bytes memory dataURI = abi.encodePacked(
            '{',
            '"name": "XEN Torrent (id ', tokenId.toString(), ')",',
            '"description": "XEN Mass Minting Ops",',
            '"image": "',
                'data:image/svg+xml;base64,',
                Base64.encode(_svgData(tokenId)),
                '"',
            '}'
        );
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(dataURI)
            )
        );
    }

    /**
        @dev function callable only in proxy contracts from the original one => XENCrypto.claimRank(term)
     */
    function callClaimRank(uint256 term) external {
        require(msg.sender == _original, 'unauthorized');
        bytes memory callData = abi.encodeWithSignature("claimRank(uint256)", term);
        (bool success, ) = address(xenCrypto).call(callData);
        require(success, 'call failed');
    }

    /**
        @dev function callable only in proxy contracts from the original one => XENCrypto.claimMintRewardAndShare()
     */
    function callClaimMintReward(address to) external {
        require(msg.sender == _original, 'unauthorized');
        bytes memory callData = abi.encodeWithSignature("claimMintRewardAndShare(address,uint256)", to, uint256(100));
        (bool success, ) = address(xenCrypto).call(callData);
        require(success, 'call failed');
    }

    /**
        @dev function callable only in proxy contracts from the original one => destroys the proxy contract
     */
    function powerDown() external {
        require(msg.sender == _original, 'unauthorized');
        selfdestruct(payable(address(0)));
    }

    /**
        @dev main torrent interface. initiates Bulk Mint (Torrent) Operation
     */
    function bulkClaimRank(uint256 count, uint256 term) public {
        bytes memory bytecode = bytes.concat(
            bytes20(0x3D602d80600A3D3981F3363d3d373d3D3D363d73),
            bytes20(address(this)),
            bytes15(0x5af43d82803e903d91602b57fd5bf3)
        );
        require(count > 0, "XEN Minter: illegal count");
        require(term > 0, "XEN Minter: illegal term");
        bytes memory callData = abi.encodeWithSignature("callClaimRank(uint256)", term);
        address proxy;
        bool succeeded;
        uint256 rank;
        uint256 maturityTs;
        for (uint256 i = 1; i < count + 1; i++) {
            bytes32 salt = keccak256(abi.encodePacked(i, _tokenIdCounter));
            assembly {
                proxy := create2(
                    0,
                    add(bytecode, 0x20),
                    mload(bytecode),
                    salt)
                succeeded := call(
                    gas(),
                    proxy,
                    0,
                    add(callData, 0x20),
                    mload(callData),
                    0,
                    0
                )
            }
            require(succeeded, "Error while claiming rank");
            if (i == 1) {
                (,,maturityTs,rank,,) = xenCrypto.userMints(proxy);
            }
        }
        minterInfo[_tokenIdCounter] = count;
        mints[_tokenIdCounter] = MintInfo({ term: term, rank: rank, maturityTs: maturityTs });
        _mint(msg.sender, _tokenIdCounter++);
    }

    /**
        @dev main torrent interface. initiates Mint Reward claim and collection and terminates Torrent Operation
     */
    function bulkClaimMintReward(uint256 tokenId, address to) external {
        require(ownerOf(tokenId) == msg.sender, "ERC721: incorrect owner");
        require(to != address(0), "illegal address");
        bytes memory bytecode = bytes.concat(
            bytes20(0x3D602d80600A3D3981F3363d3d373d3D3D363d73),
            bytes20(address(this)),
            bytes15(0x5af43d82803e903d91602b57fd5bf3)
        );
        uint256 end = minterInfo[tokenId] + 1;
        bytes memory callData = abi.encodeWithSignature("callClaimMintReward(address)", to);
        bytes memory callData1 = abi.encodeWithSignature("powerDown()");
        for (uint i = 1; i < end; i++) {
            bytes32 salt = keccak256(abi.encodePacked(i, tokenId));
            bool succeeded;
            bytes32 hash = keccak256(abi.encodePacked(hex'ff', address(this), salt, keccak256(bytecode)));
            address proxy = address(uint160(uint(hash)));
            assembly {
                succeeded := call(
                    gas(),
                    proxy,
                    0,
                    add(callData, 0x20),
                    mload(callData),
                    0,
                    0
                )
            }
            require(succeeded, "Error while claiming rewards");
            assembly {
                succeeded := call(
                    gas(),
                    proxy,
                    0,
                    add(callData1, 0x20),
                    mload(callData1),
                    0,
                    0
                )
            }
            require(succeeded, "Error while powering down");
        }
        delete minterInfo[tokenId];
        delete mints[tokenId];
        _burn(tokenId);
    }

}
