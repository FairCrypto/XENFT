// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
// TODO: restore after testing
import "@faircrypto/xen-crypto/contracts/XENCrypto.sol";
// import "./XENCrypto.sol";
import "./interfaces/IXENTorrent.sol";
import "./interfaces/IXENProxying.sol";
// import "./libs/SVG.sol";
import "./libs/MintInfo.sol";
import "./libs/Metadata.sol";
//import "./libs/DateTime.sol";
import "./libs/Array.sol";

/*

        \\      //   |||||||||||   |\      ||       A CRYPTOCURRENCY FOR THE MASSES
         \\    //    ||            |\\     ||
          \\  //     ||            ||\\    ||       PRINCIPLES OF XEN:
           \\//      ||            || \\   ||       - No pre-mint; starts with zero supply
            XX       ||||||||      ||  \\  ||       - No admin keys
           //\\      ||            ||   \\ ||       - Immutable contract
          //  \\     ||            ||    \\||
         //    \\    ||            ||     \\|
        //      \\   |||||||||||   ||      \|       Copyright (C) FairCrypto Foundation 2022


    XENFT props:
    - count: number of VMUs
    - term, maturityTs, cRank start / end, AMP and EAA
    - redeemed: is the XENFT redeemed (used)
 */
contract XENFT is IXENTorrent, IXENProxying, IBurnableToken, IBurnRedeemable, ERC721("XEN Torrent", "XENT") {
    //using DateTime for uint256;
    using Strings for uint256;
    using MintInfo for uint256;
    using Array for uint256[];

    // XENFT limited series params
    uint256 public constant RARE_SERIES_COUNT = 10_001;
    uint256 public constant RARE_SERIES_VMU_THRESHOLD = 99;
    uint256 public constant LIMITED_SERIES_TIME_THRESHOLD = 3_600 * 24 * 365;

    // XENFT series
    uint256 public constant POWER_GROUP_SIZE = 7_500;

    // Metadata image params

    // original contract marking to distinguish from proxy copies
    address private immutable _original;
    // original deployer address to be used for royalties' tracking
    address private immutable _deployer;

    // genesisTs for the contract
    uint256 public immutable genesisTs;

    // reentrancy guard
    uint256 private _tokenId = 0;

    // increasing counters for NFT tokenIds, also used as salt for proxies' spinning
    uint256 public tokenIdCounter = RARE_SERIES_COUNT;
    uint256[] public specialSeriesBurnRates;
    uint256[] public rareSeriesTokenLimits;
    uint256[] public rareSeriesCounters = [ 1, 1, 1, 1, 1 ];
    // uint256 public immutable limitedSeriesBurnRate;

    // pointer to XEN Crypto contract
    XENCrypto public immutable xenCrypto;

    // mapping Address => tokenId[]
    mapping(address => uint256[]) private _ownedTokens;
    // mapping: NFT tokenId => count of Virtual Mining Units
    mapping(uint256 => uint256) public vmuCount;
    // mapping: NFT tokenId => burned XEN
    mapping(uint256 => uint256) public xenBurned;
    // mapping: NFT tokenId => MintInfo (used in tokenURI generation)
    // MintInfo encoded as:
    //      term (uint16)
    //      | maturityTs (uint64)
    //      | rank (uint128)
    //      | amp (uint16)
    //      | eaa (uint16)
    //      | series (uint8):
    //          [7] isRare
    //          [6] isLimited
    //          [0-5] powerSeriesIdx
    //      | redeemed (uint8)
    mapping(uint256 => uint256) public mintInfo;

    /**
        @dev    Creates XENFT contract, writing down immutable address for XEN Crypto main contract
                and original(self) address to distinguish between proxy clones
     */
    constructor(address xenCrypto_, uint256[] memory burnRates_, uint256[] memory tokenLimits_) {
        require(xenCrypto_ != address(0));
        _original = address(this);
        _deployer = msg.sender;
        genesisTs = block.timestamp;
        xenCrypto = XENCrypto(xenCrypto_);
        specialSeriesBurnRates = burnRates_;
        rareSeriesTokenLimits = tokenLimits_;
        // limitedSeriesBurnRate = burnRate2_;
        for (uint i = 1; i < rareSeriesTokenLimits.length; i++) {
            rareSeriesCounters[i] = rareSeriesTokenLimits[i - 1] + 1;
        }
    }

    /**
        @dev support for IBurnRedeemable interface
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IBurnRedeemable).interfaceId;
    }

    /**
        @dev public getter to check for deployer / owner (Opensea, etc.)
     */
    function owner() external view returns (address) {
        return _deployer;
    }

    /**
        @dev public getter for tokens owned by address
     */
    function ownedTokens() external view returns (uint256[] memory) {
        return _ownedTokens[msg.sender];
    }

    /**
        @dev sets specified XENFT as redeemed
     */
    function _setRedeemed(uint256 tokenId) private {
        mintInfo[tokenId] = mintInfo[tokenId] | uint256(1);
    }

    /**
        @dev determines if tokenId corresponds to limited series
     */
    function isRare(uint256 tokenId) public pure returns (bool limited) {
        limited = tokenId < RARE_SERIES_COUNT;
    }

    /**
        @dev determines power group index
     */
    function _powerGroup(uint256 VMUs, uint256 term) private pure returns (uint256) {
        return (VMUs * term) / POWER_GROUP_SIZE;
    }

    /**
        @dev retrieves Series string name by index
    */
    function _seriesIdx(uint256 count, uint256 term) private pure returns (uint256 index) {
        if (_powerGroup(count, term) > 7) return 7;
        return _powerGroup(count, term);
    }

    /**
        @dev compliance with ERC-721 standard (NFT); returns NFT metadata, including SVG-encoded image
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        uint256 count = vmuCount[tokenId];
        uint256 info = mintInfo[tokenId];
        uint256 burned = xenBurned[tokenId];
        require(count > 0);
        bytes memory dataURI = abi.encodePacked(
            "{",
            '"name": "XENFT #',
            tokenId.toString(),
            '",',
            '"description": "XENFT: XEN Crypto Minting Torrent",',
            '"image": "',
            "data:image/svg+xml;base64,",
            Base64.encode(Metadata.svgData(tokenId, count, info, address(xenCrypto), burned)),
            '",',
            '"attributes": ',
            Metadata.attributes(count, info),
            "}"
        );
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(dataURI)));
    }

    /**
        @dev function callable only in proxy contracts from the original one => XENCrypto.claimRank(term)
     */
    function callClaimRank(uint256 term) external {
        require(msg.sender == _original, "XEN Proxy: unauthorized");
        bytes memory callData = abi.encodeWithSignature("claimRank(uint256)", term);
        (bool success, ) = address(xenCrypto).call(callData);
        require(success, "call failed");
    }

    /**
        @dev function callable only in proxy contracts from the original one => XENCrypto.claimMintRewardAndShare()
     */
    function callClaimMintReward(address to) external {
        require(msg.sender == _original, "XEN Proxy: unauthorized");
        bytes memory callData = abi.encodeWithSignature("claimMintRewardAndShare(address,uint256)", to, uint256(100));
        (bool success, ) = address(xenCrypto).call(callData);
        require(success, "call failed");
    }

    /**
        @dev function callable only in proxy contracts from the original one => destroys the proxy contract
     */
    function powerDown() external {
        require(msg.sender == _original, "XEN Proxy: unauthorized");
        selfdestruct(payable(address(0)));
    }

    /**
        @dev internal helper to collect params and encode MintInfo
     */
    function _mintInfo(address proxy, uint256 count, uint256 term, uint256 burning, uint256 tokenId) private view returns (uint256) {
        // if (count > LIMITED_SERIES_VMU_THRESHOLD1) return 8;
        // if (count > RARE_SERIES_VMU_THRESHOLD) return 9;
        bool rare = isRare(tokenId);
        uint256 series = _seriesIdx(count, term);
        if (rare) series = uint8(9) | 0x80;
        if (burning > 0 && !rare) series = uint8(8) | 0x40;
        (, , uint256 maturityTs, uint256 rank, uint256 amp, uint256 eaa) = xenCrypto.userMints(proxy);
        return MintInfo.encodeMintInfo(term, maturityTs, rank, amp, eaa, series, false);
    }

    /**
        @dev internal helper to determine limited tier based on XEN to be burned
     */
    function _limitedTier(uint256 burning) private view returns (uint256) {
        for(uint i = 0; i < specialSeriesBurnRates.length; i++) {
            if (burning > specialSeriesBurnRates[i] - 1) {
                return i + 1;
            }
        }
        //if (burning > limitedSeriesBurnRate - 1) {
        //    return specialSeriesBurnRates.length + 1;
        //}
        return 0;
    }

    /**
        @dev internal torrent interface. initiates Bulk Mint (Torrent) Operation
     */
    function _bulkClaimRank(uint256 count, uint256 term, uint256 tokenId, uint256 burning) private {
        bytes memory bytecode = bytes.concat(
            bytes20(0x3D602d80600A3D3981F3363d3d373d3D3D363d73),
            bytes20(address(this)),
            bytes15(0x5af43d82803e903d91602b57fd5bf3)
        );
        bytes memory callData = abi.encodeWithSignature("callClaimRank(uint256)", term);
        address proxy;
        bool succeeded;
        for (uint256 i = 1; i < count + 1; i++) {
            bytes32 salt = keccak256(abi.encodePacked(i, tokenId));
            assembly {
                proxy := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
                succeeded := call(gas(), proxy, 0, add(callData, 0x20), mload(callData), 0, 0)
            }
            require(succeeded, "XENFT: Error while claiming rank");
            if (i == 1) {
                mintInfo[tokenId] = _mintInfo(proxy, count, term, burning, tokenId);
            }
        }
        vmuCount[tokenId] = count;
    }

    /**
        @dev internal helper to claim tokenId (limited / ordinary)
     */
    function _getTokenId(uint256 count, uint256 burning) private returns (uint256) {
        // burn possibility has already been verified
        uint256 tier = _limitedTier(burning);
        if (tier == rareSeriesTokenLimits.length + 1) {
            require(block.timestamp < genesisTs + LIMITED_SERIES_TIME_THRESHOLD, 'XENFT: limited time expired');
            return tokenIdCounter++;
        }
        if (count > RARE_SERIES_VMU_THRESHOLD && burning > 0) {
            require(rareSeriesCounters[tier - 1] < rareSeriesTokenLimits[tier], 'XENFT: tier sold out');
            return rareSeriesCounters[tier - 1]++;
        }
        return tokenIdCounter++;
    }

    /**
        @dev public torrent interface. initiates Bulk Mint (Torrent) Operation (ordinary series)
     */
    function bulkClaimRank(uint256 count, uint256 term) public returns (uint256) {
        require(count > 0, "XENFT: Illegal count");
        require(term > 0, "XENFT: Illegal term");
        uint256 tokenId = _getTokenId(count, 0);
        _bulkClaimRank(count, term, tokenId, 0);
        _safeMint(msg.sender, tokenId);
        _ownedTokens[msg.sender].addItem(tokenId);
        emit StartTorrent(msg.sender, count, term);
        return tokenId;
    }

    /**
        @dev public torrent interface. initiates Bulk Mint (Torrent) Operation (limited series)
     */
    function bulkClaimRankLimited(uint256 count, uint256 term, uint256 burning) public returns (uint256) {
        require(_tokenId == 0, 'XENFT: reentrancy detected');
        require(count > 0, "XENFT: Illegal count");
        require(term > 0, "XENFT: Illegal term");
        // TODO: disambiguate between rare and limited !!!
        require(burning > specialSeriesBurnRates[specialSeriesBurnRates.length - 1] - 1, "XENFT: not enough burn amount");
        uint256 balance = IERC20(xenCrypto).balanceOf(msg.sender);
        require(balance > burning - 1, 'XENFT: not enough XEN balance');
        uint256 approved = IERC20(xenCrypto).allowance(msg.sender, address(this));
        require(approved > burning - 1, 'XENFT: not enough XEN balance approved for burn');
        _tokenId = _getTokenId(count, burning);
        _bulkClaimRank(count, term, _tokenId, burning);
        IBurnableToken(xenCrypto).burn(msg.sender, burning);
        return _tokenId;
    }

    /**
        @dev implements IBurnRedeemable interface for burning XEN and completing Bulk Mint for limited series
     */
    function onTokenBurned(address user, uint256 burned) external {
        require(_tokenId > 0, 'XENFT: illegal callback state');
        require(msg.sender == address(xenCrypto), 'XENFT: illegal callback caller');
        _safeMint(user, _tokenId);
        _ownedTokens[user].addItem(_tokenId);
        xenBurned[_tokenId] = burned;
        emit StartTorrent(msg.sender, vmuCount[_tokenId], mintInfo[_tokenId].getTerm());
        _tokenId = 0;
    }

    /**
        @dev public torrent interface. initiates Mint Reward claim and collection and terminates Torrent Operation
     */
    function bulkClaimMintReward(uint256 tokenId, address to) external {
        require(ownerOf(tokenId) == msg.sender, "XENFT: Incorrect owner");
        require(to != address(0), "XENFT: Illegal address");
        require(!mintInfo[tokenId].getRedeemed(), "XENFT: Already redeemed");
        bytes memory bytecode = bytes.concat(
            bytes20(0x3D602d80600A3D3981F3363d3d373d3D3D363d73),
            bytes20(address(this)),
            bytes15(0x5af43d82803e903d91602b57fd5bf3)
        );
        uint256 end = vmuCount[tokenId] + 1;
        bytes memory callData = abi.encodeWithSignature("callClaimMintReward(address)", to);
        bytes memory callData1 = abi.encodeWithSignature("powerDown()");
        for (uint256 i = 1; i < end; i++) {
            bytes32 salt = keccak256(abi.encodePacked(i, tokenId));
            bool succeeded;
            bytes32 hash = keccak256(abi.encodePacked(hex"ff", address(this), salt, keccak256(bytecode)));
            address proxy = address(uint160(uint256(hash)));
            assembly {
                succeeded := call(gas(), proxy, 0, add(callData, 0x20), mload(callData), 0, 0)
            }
            require(succeeded, "XENFT: Error while claiming rewards");
            assembly {
                succeeded := call(gas(), proxy, 0, add(callData1, 0x20), mload(callData1), 0, 0)
            }
            require(succeeded, "XENFT: Error while powering down");
        }
        _setRedeemed(tokenId);
        emit EndTorrent(msg.sender, tokenId, to);
    }

    /**
        @dev overrides OZ ERC-721 after transfer hook to allow token enumeration for owner
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        _ownedTokens[from].removeItem(tokenId);
        _ownedTokens[to].addItem(tokenId);
    }

    /**
        @dev burns XENFT which can be used by connected contracts services
     */
    function burn(address user, uint256 tokenId) public {
        require(
            IERC165(_msgSender()).supportsInterface(type(IBurnRedeemable).interfaceId),
            "XENFT burn: not a supported contract"
        );
        require(_isApprovedOrOwner(user, tokenId));
        _ownedTokens[user].removeItem(tokenId);
        _burn(tokenId);
        IBurnRedeemable(_msgSender()).onTokenBurned(user, tokenId);
    }

}
