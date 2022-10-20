// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import '@faircrypto/xen-crypto/contracts/XENCrypto.sol';

/*
    NFT props:
    - number of virtual minters
    - XEN MintInfo (cRank, AMP, EAA, term, maturityDate) for each server
 */
contract XENMinter is ERC721("XEN Torrent", "XENTORR") {

    string constant private _p1 = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: arial; font-size: 20px; }</style><rect width="100%" height="500%" fill="#222222" /><line x1="120" y1="50" x2="220" y2="180" stroke="white" /><line x1="220" y1="50" x2="120" y2="180" stroke="white" /><text x="50%" y="65%" class="base" dominant-baseline="middle" text-anchor="middle">XEN Crypto</text><text x="50%" y="81%" class="base" dominant-baseline="middle" text-anchor="middle">Bulk Mint #';
    string constant private _p2 = '</text><text x="50%" y="89%" class="base" dominant-baseline="middle" text-anchor="middle">Term: ';
    string constant private _p3 = 'd</text></svg>';

    // original contract marking to distinguish from proxy copies
    address private immutable _original;
    uint256 private _tokenIdCounter = 1;
    // pointer to XEN Crypto contract
    XENCrypto immutable public xenCrypto;
    // mapping: NFT ID => count of virtual minters
    mapping(uint256 => uint256) public minterInfo;
    // mapping: NFT ID => mint term (for metadata)
    mapping(uint256 => uint256) public mintTerms;

    constructor(address xenCrypto_) {
        require(xenCrypto_ != address(0));
        _original = address(this);
        xenCrypto = XENCrypto(xenCrypto_);
    }

    /**
        @dev compliance with ERC-721 standard (NFT); returns NFT metadata, including SVG-encoded image
     */
    function tokenURI(uint256 tokenId) override public view returns (string memory) {
        require(minterInfo[tokenId] > 0);
        string memory id = Strings.toString(tokenId);
        string memory term = Strings.toString(mintTerms[tokenId]);
        bytes memory svgData = abi.encodePacked(_p1, id, _p2, term, _p3);
        bytes memory dataURI = abi.encodePacked(
            '{',
            '"name": "XEN Torrent (id ',
                id,
                ')",',
            '"description": "XEN Mass Minting Ops",',
            '"image": "',
                'data:image/svg+xml;base64,',
                Base64.encode(bytes(svgData)),
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

    function callClaimRank(uint256 term) external {
        require(msg.sender == _original, 'unauthorized');
        bytes memory callData = abi.encodeWithSignature("claimRank(uint256)", term);
        (bool success, ) = address(xenCrypto).call(callData);
        require(success, 'call failed');
    }

    function callClaimMintReward(address to) external {
        require(msg.sender == _original, 'unauthorized');
        bytes memory callData = abi.encodeWithSignature("claimMintRewardAndShare(address,uint256)", to, uint256(100));
        (bool success, ) = address(xenCrypto).call(callData);
        require(success, 'call failed');
    }

    function bulkClaimRank0(uint256 count, uint256 term) external {
        bytes memory bytecode = bytes.concat(
            bytes20(0x3D602d80600A3D3981F3363d3d373d3D3D363d73),
            bytes20(address(this)),
            bytes15(0x5af43d82803e903d91602b57fd5bf3)
        );
        require(count > 0, "XEN Minter: illegal count");
        require(term > 0, "XEN Minter: illegal term");
        bytes memory callData = abi.encodeWithSignature("callClaimRank(uint256)", term);
        bool result = true;
        for (uint256 i = 1; i < count + 1; i++) {
            bytes32 salt = keccak256(abi.encodePacked(i, _tokenIdCounter));
            bool succeeded;
            assembly {
                let proxy := create2(
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
            result = result && succeeded;
        }
        require(result, "Error while claiming rank");
        minterInfo[_tokenIdCounter] = count;
        mintTerms[_tokenIdCounter] = term;
        _mint(msg.sender, _tokenIdCounter++);
    }

    /*
    function bulkClaimRank(uint256 count, uint256 term, bytes calldata salt_) external {
        bytes memory bytecode = bytes.concat(
            bytes20(0x3D602d80600A3D3981F3363d3d373d3D3D363d73),
            bytes20(address(this)),
            bytes15(0x5af43d82803e903d91602b57fd5bf3)
        );
        uint256 i = 1;
        uint256 end = count + i;
        bytes memory callData = abi.encodeWithSignature("callClaimRank(uint256)", term);
        for (i; i < end; i++) {
            bytes32 salt = keccak256(abi.encodePacked(salt_, i, msg.sender));
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
        }
    }
    */

    function bulkClaimMintReward(uint256 tokenId, address to) external {
        bytes memory bytecode = bytes.concat(
            bytes20(0x3D602d80600A3D3981F3363d3d373d3D3D363d73),
            bytes20(address(this)),
            bytes15(0x5af43d82803e903d91602b57fd5bf3)
        );
        require(ownerOf(tokenId) == msg.sender, "ERC721: incorrect owner");
        uint256 end = minterInfo[tokenId] + 1;
        bytes memory callData = abi.encodeWithSignature("callClaimMintReward(address)", to);
        bool result = true;
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
            result = result && succeeded;
        }
        require(result, "Error while claiming rewards");
        minterInfo[tokenId] = 0;
        mintTerms[tokenId] = 0;
        _burn(tokenId);
    }

}
