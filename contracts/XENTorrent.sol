// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import '@faircrypto/xen-crypto/contracts/XENCrypto.sol';
import './libs/SVG.sol';
import './libs/DateTime.sol';
import "./interfaces/IXENTorrent.sol";
import "./interfaces/IXENProxying.sol";

/*
    NFT props:
    - number of virtual minters
    - MintInfo (term, cRank, maturityDate) for each virtual minter
 */
contract XENTorrent is IXENTorrent, IXENProxying, ERC721("XEN Torrent", "XENTORR") {

    using DateTime for uint256;
    using Strings for uint256;

    uint256 public constant LIMITED_SERIES_COUNT = 10_000;
    uint256 public constant LIMITED_SERIES_VMU_THRESHOLD = 99;

    //uint256[] public COLORS = [206, 20, 331, 230];
    uint256[] public COLORS_LIMITED = [38, 169, 191, 305];
    uint256[] public COLORS_REGULAR = [225, 220, 215, 205];
    uint256[] public ANGLES = [45, 135, 225, 315];

    // original contract marking to distinguish from proxy copies
    address private immutable _original;
    // ever increasing counter for NFT tokenIds, also used as salt for proxies' spinning
    // TODO: make the next 2 public ???
    uint256 private _tokenIdCounter = 1;
    uint256 private _limitedSeriesCounter;
    // pointer to XEN Crypto contract
    XENCrypto immutable public xenCrypto;

    // mapping: NFT tokenId => count of Virtual Mining Units
    mapping(uint256 => uint256) public vmuCount;
    // mapping: NFT tokenId => MintInfo (used in tokenURI generation)
    // MintInfo encoded as:
    // term (uint16) | maturity (uint64) | rank (uint128) | amp (uint16) | eaa (uint16) | limited (uint88) redeemed (uint8)
    mapping(uint256 => uint256) public mintInfo;

    constructor(address xenCrypto_) {
        require(xenCrypto_ != address(0));
        _original = address(this);
        xenCrypto = XENCrypto(xenCrypto_);
    }

    function toU256(bool x) public pure returns (uint256 r) {
        assembly { r := x }
    }

    function encodeMintInfo(uint256 term, uint256 maturityTs, uint256 rank, uint256 amp, uint256 eaa, bool limited, bool redeemed)
        public
        pure
        returns (uint256 info)
    {
        info = info | toU256(redeemed);
        info = info | (toU256(limited) << 8);
        info = info | (eaa << 16);
        info = info | (amp << 32);
        info = info | (rank << 48);
        info = info | (maturityTs << 176);
        info = info | (term << 240);
    }

    function decodeMintInfo(uint256 info)
        public
        pure
        returns (uint256 term, uint256 maturityTs, uint256 rank, uint256 amp, uint256 eaa, bool limited, bool redeemed)
    {
        term = uint16(info >> 240);
        maturityTs = uint64(info >> 176);
        rank = uint128(info >> 48);
        amp = uint16(info >> 32);
        eaa = uint16(info >> 16);
        limited = uint8(info >> 8) == 1;
        redeemed = uint8(info) == 1;
    }

    function getTerm(uint256 info) public pure returns (uint256 term) {
        (term,,,,,,) = decodeMintInfo(info);
    }

    function getMaturityTs(uint256 info) public pure returns (uint256 maturityTs) {
        (,maturityTs,,,,,) = decodeMintInfo(info);
    }

    function getRank(uint256 info) public pure returns (uint256 rank) {
        (,,rank,,,,) = decodeMintInfo(info);
    }

    function getAMP(uint256 info) public pure returns (uint256 amp) {
        (,,,amp,,,) = decodeMintInfo(info);
    }

    function getEAA(uint256 info) public pure returns (uint256 eaa) {
        (,,,,eaa,,) = decodeMintInfo(info);
    }

    function getLimited(uint256 info) public pure returns (bool limited) {
        (,,,,,limited,) = decodeMintInfo(info);
    }

    function getRedeemed(uint256 info) public pure returns (bool redeemed) {
        (,,,,,,redeemed) = decodeMintInfo(info);
    }

    function _setRedeemed(uint256 tokenId) private {
        mintInfo[tokenId] = mintInfo[tokenId] | uint256(1);
    }

    /**
        @dev private helper to generate SVG image based on Torrent params
     */
    function _svgData(uint256 tokenId) private view returns (bytes memory) {
        string memory symbol = IERC20Metadata(address(xenCrypto)).symbol();
        SVG.SvgParams memory params = SVG.SvgParams({
            symbol: symbol,
            xenAddress: address(xenCrypto),
            tokenId: tokenId,
            term: getTerm(mintInfo[tokenId]),
            rank: getRank(mintInfo[tokenId]),
            count: vmuCount[tokenId],
            maturityTs: getMaturityTs(mintInfo[tokenId]),
            amp: getAMP(mintInfo[tokenId]),
            eaa: getEAA(mintInfo[tokenId]),
            redeemed: getRedeemed(mintInfo[tokenId])
        });
        uint256 idx = uint256(keccak256(abi.encode(mintInfo[tokenId]))) % Quotes.QUOTES_COUNT;
        return SVG.image(
            params,
            getLimited(mintInfo[tokenId]) ? COLORS_LIMITED: COLORS_REGULAR,
            ANGLES,
            idx);
    }

    // TODO: remove after testing
    //function genSVG(uint256 tokenId) public view returns (string memory) {
    //    return string(_svgData(tokenId));
    //}

    function _attributes(uint256 tokenId) private view returns (bytes memory) {
        uint256 count = vmuCount[tokenId];
        (, uint256 maturityTs, uint256 rank, uint256 amp, uint256 eaa, bool limited, bool redeemed) =
            decodeMintInfo(mintInfo[tokenId]);
        bytes memory attr1 = abi.encodePacked(
            '{"trait_type":"Limited","value":"', limited?'yes':'no', '"},'
            '{"trait_type":"VMUs","value":"', count.toString(), '"},'
            '{"trait_type":"cRank Start","value":"', rank.toString(), '"},'
            '{"trait_type":"cRank End","value":"', (rank + count - 1).toString(), '"},'
        );
        bytes memory attr2 = abi.encodePacked(
            '{"trait_type":"AMP","value":"', amp.toString(), '"},'
            '{"trait_type":"EAA (%)","value":"', (eaa/10).toString(), '"},'
            '{"trait_type":"Maturity","display_type":"date","value":"', maturityTs.toString(), '"},'
            '{"trait_type":"Redeemed","value":"', redeemed?'yes':'no', '"}'
        );
        return abi.encodePacked(
            '[',
                attr1,
                attr2,
            ']'
        );
    }

    /**
        @dev compliance with ERC-721 standard (NFT); returns NFT metadata, including SVG-encoded image
     */
    function tokenURI(uint256 tokenId) override public view returns (string memory) {
        uint256 count = vmuCount[tokenId];
        require(count > 0);
        bytes memory dataURI = abi.encodePacked(
            '{',
                '"name": "XEN Torrent #', tokenId.toString(), '",',
                '"description": "XEN Crypto Minting Torrent",',
                '"image": "',
                    'data:image/svg+xml;base64,',
                    Base64.encode(_svgData(tokenId)),
                    '",',
                '"attributes": ', _attributes(tokenId),
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
        require(count > 0, "XEN Torrent: Illegal count");
        require(term > 0, "XEN Torrent: Illegal term");
        bytes memory callData = abi.encodeWithSignature("callClaimRank(uint256)", term);
        address proxy;
        bool succeeded;
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
            require(succeeded, "XEN Torrent: Error while claiming rank");
            if (i == 1) {
                bool limited;
                if (count > LIMITED_SERIES_VMU_THRESHOLD && _limitedSeriesCounter < LIMITED_SERIES_COUNT) {
                    _limitedSeriesCounter++;
                    limited = true;
                }
                (,
                uint256 t,
                uint256 m,
                uint256 r,
                uint256 a,
                uint256 e) = xenCrypto.userMints(proxy);
                mintInfo[_tokenIdCounter] = encodeMintInfo(t, m, r, a, e, limited, false);
            }
        }
        vmuCount[_tokenIdCounter] = count;
        _mint(msg.sender, _tokenIdCounter++);
    }

    /**
        @dev main torrent interface. initiates Mint Reward claim and collection and terminates Torrent Operation
     */
    function bulkClaimMintReward(uint256 tokenId, address to) external {
        require(ownerOf(tokenId) == msg.sender, "XEN Torrent: Incorrect owner");
        require(to != address(0), "XEN Torrent: Illegal address");
        require(!getRedeemed(mintInfo[tokenId]), "XEN Torrent: Already redeemed");
        bytes memory bytecode = bytes.concat(
            bytes20(0x3D602d80600A3D3981F3363d3d373d3D3D363d73),
            bytes20(address(this)),
            bytes15(0x5af43d82803e903d91602b57fd5bf3)
        );
        uint256 end = vmuCount[tokenId] + 1;
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
            require(succeeded, "XEN Torrent: Error while claiming rewards");
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
            require(succeeded, "XEN Torrent: Error while powering down");
        }
        _setRedeemed(tokenId);
    }

}
