// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@faircrypto/xen-crypto/contracts/XENCrypto.sol";
import "@faircrypto/xen-crypto/contracts/interfaces/IBurnableToken.sol";
import "@faircrypto/xen-crypto/contracts/interfaces/IBurnRedeemable.sol";
import "operator-filter-registry/src/DefaultOperatorFilterer.sol";
import "./libs/ERC2771Context.sol";
import "./interfaces/IERC2771.sol";
import "./interfaces/IXENTorrent.sol";
import "./interfaces/IXENProxying.sol";
import "./libs/MintInfo.sol";
import "./libs/Metadata.sol";
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


    XENFT XEN Torrent props:
    - count: number of VMUs
    - mintInfo: (term, maturityTs, cRank start, AMP,  EAA, apex, limited, group, redeemed)
 */
contract XENTorrent is
    DefaultOperatorFilterer, // required to support OpenSea royalties
    IXENTorrent,
    IXENProxying,
    IBurnableToken,
    IBurnRedeemable,
    ERC2771Context, // required to support meta transactions
    IERC2981, // required to support NFT royalties
    ERC721("XEN Torrent", "XENT")
{
    // HELPER LIBRARIES

    using Strings for uint256;
    using MintInfo for uint256;
    using Array for uint256[];

    // PUBLIC CONSTANTS

    // XENFT common business logic
    uint256 public constant BLACKOUT_TERM = 7 * 24 * 3600; /* 7 days in sec */

    // XENFT limited series params
    uint256 public constant COLLECTOR_CLASS_COUNTER = 10_001;
    uint256 public constant SPECIAL_CLASSES_VMU_THRESHOLD = 99;
    uint256 public constant LIMITED_CLASS_TIME_THRESHOLD = 3_600 * 24 * 365;

    uint256 public constant POWER_GROUP_SIZE = 7_500;

    string public constant AUTHORS = "@MrJackLevin @lbelyaev faircrypto.org";

    uint256 public constant ROYALTY_PCT = 5;
    uint256 public constant ROYALTY_MIN_AMOUNT = 0.01 ether;

    // PUBLIC MUTABLE STATE

    // increasing counters for NFT tokenIds, also used as salt for proxies' spinning
    uint256 public tokenIdCounter = COLLECTOR_CLASS_COUNTER;
    // 0: Collector
    // 1: Limited
    // 2: Rare
    // 3: Epic
    // 4: Legendary
    // 5: Exotic
    // 6: Xunicorn
    uint256[] public specialSeriesBurnRates;
    // [0, 0, R1, R2, R3, R4, R5]
    uint256[] public specialSeriesTokenLimits;
    // [0, 0, 0 + 1, R1+1, R2+1, R3+1, R4+1]
    uint256[] public specialSeriesCounters;

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
    //          [7] isApex
    //          [6] isLimited
    //          [0-5] powerSeriesIdx
    //      | redeemed (uint8)
    mapping(uint256 => uint256) public mintInfo;

    // PUBLIC IMMUTABLE STATE

    // pointer to XEN Crypto contract
    XENCrypto public immutable xenCrypto;
    // genesisTs for the contract
    uint256 public immutable genesisTs;

    // PRIVATE STATE

    // original contract marking to distinguish from proxy copies
    address private immutable _original;
    // original deployer address to be used for royalties' tracking
    address private immutable _deployer;
    // reentrancy guard
    uint256 private _tokenId = 0;
    // mapping Address => tokenId[]
    mapping(address => uint256[]) private _ownedTokens;

    /**
        @dev    Constructor. Creates XEN Torrent contract, setting immutable parameters
     */
    constructor(
        address xenCrypto_,
        uint256[] memory burnRates_,
        uint256[] memory tokenLimits_,
        address forwarder_
    ) ERC2771Context(forwarder_) {
        require(xenCrypto_ != address(0), "bad address");
        require(burnRates_.length == tokenLimits_.length && burnRates_.length > 0, "params mismatch");
        _original = address(this);
        _deployer = msg.sender;
        genesisTs = block.timestamp;
        xenCrypto = XENCrypto(xenCrypto_);
        specialSeriesBurnRates = burnRates_;
        specialSeriesTokenLimits = tokenLimits_;
        specialSeriesCounters = new uint256[](tokenLimits_.length);
        for (uint256 i = 2; i < specialSeriesBurnRates.length - 1; i++) {
            specialSeriesCounters[i] = specialSeriesTokenLimits[i + 1] + 1;
        }
        specialSeriesCounters[specialSeriesBurnRates.length - 1] = 1;
    }

    // INTERFACES & STANDARDS
    // IERC165 IMPLEMENTATION

    /**
        @dev confirms support for IERC-165, IERC-721, IERC2981, IERC2771 and IBurnRedeemable interfaces
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return
            interfaceId == type(IBurnRedeemable).interfaceId ||
            interfaceId == type(IERC2981).interfaceId ||
            interfaceId == type(IERC2771).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // ERC2771 IMPLEMENTATION

    /**
        @dev use ERC2771Context implementation of _msgSender()
     */
    function _msgSender() internal view virtual override(Context, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    /**
        @dev use ERC2771Context implementation of _msgData()
     */
    function _msgData() internal view virtual override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    // OWNABLE IMPLEMENTATION

    /**
        @dev public getter to check for deployer / owner (Opensea, etc.)
     */
    function owner() external view returns (address) {
        return _deployer;
    }

    // ERC-721 METADATA IMPLEMENTATION
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
            '"name": "XEN Torrent #',
            tokenId.toString(),
            '",',
            '"description": "XENFT: XEN Crypto Minting Torrent",',
            '"image": "',
            "data:image/svg+xml;base64,",
            Base64.encode(Metadata.svgData(tokenId, count, info, address(xenCrypto), burned)),
            '",',
            '"attributes": ',
            Metadata.attributes(count, burned, info),
            "}"
        );
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(dataURI)));
    }

    // IMPLEMENTATION OF XENProxying INTERFACE
    // FUNCTIONS IN PROXY COPY CONTRACTS (VMUs), CALLING ORIGINAL XEN CRYPTO CONTRACT
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

    // OVERRIDING OF ERC-721 IMPLEMENTATION
    // ENFORCEMENT OF TRANSFER BLACKOUT PERIOD

    /**
        @dev overrides OZ ERC-721 before transfer hook to check if there's no blackout period
     */
    function _beforeTokenTransfer(
        address from,
        address,
        uint256 tokenId
    ) internal virtual override {
        if (from != address(0)) {
            uint256 maturityTs = mintInfo[tokenId].getMaturityTs();
            uint256 delta = maturityTs > block.timestamp ? maturityTs - block.timestamp : block.timestamp - maturityTs;
            require(delta > BLACKOUT_TERM, "XENFT: transfer prohibited in blackout period");
        }
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

    // IBurnRedeemable IMPLEMENTATION

    /**
        @dev implements IBurnRedeemable interface for burning XEN and completing Bulk Mint for limited series
     */
    function onTokenBurned(address user, uint256 burned) external {
        require(_tokenId > 0, "XENFT: illegal callback state");
        require(msg.sender == address(xenCrypto), "XENFT: illegal callback caller");
        _safeMint(user, _tokenId);
        _ownedTokens[user].addItem(_tokenId);
        xenBurned[_tokenId] = burned;
        emit StartTorrent(user, vmuCount[_tokenId], mintInfo[_tokenId].getTerm());
        _tokenId = 0;
    }

    // IBurnableToken IMPLEMENTATION

    /**
        @dev burns XENTorrent XENFT which can be used by connected contracts services
     */
    function burn(address user, uint256 tokenId) public {
        require(
            IERC165(_msgSender()).supportsInterface(type(IBurnRedeemable).interfaceId),
            "XENFT burn: not a supported contract"
        );
        require(user != address(0), "XENFT burn: illegal owner address");
        require(tokenId > 0, "XENFT burn: illegal tokenId");
        require(_isApprovedOrOwner(_msgSender(), tokenId), "XENFT burn: not an approved operator");
        require(ownerOf(tokenId) == user, "XENFT burn: user is not tokenId owner");
        _ownedTokens[user].removeItem(tokenId);
        _burn(tokenId);
        IBurnRedeemable(_msgSender()).onTokenBurned(user, tokenId);
    }

    // OVERRIDING ERC-721 IMPLEMENTATION TO ALLOW OPENSEA ROYALTIES ENFORCEMENT PROTOCOL

    /**
        @dev implements `setApprovalForAll` with additional approved Operator checking
     */
    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    /**
        @dev implements `approve` with additional approved Operator checking
     */
    function approve(address operator, uint256 tokenId) public override onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    /**
        @dev implements `transferFrom` with additional approved Operator checking
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    /**
        @dev implements `safeTransferFrom` with additional approved Operator checking
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    /**
        @dev implements `safeTransferFrom` with additional approved Operator checking
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    // SUPPORT FOR ERC2771 META-TRANSACTIONS

    /**
        @dev Implements setting a `Trusted Forwarder` for meta-txs. Settable only once
     */
    function addForwarder(address trustedForwarder) external {
        require(msg.sender == _deployer, "XENFT: not an deployer");
        require(_trustedForwarder == address(0), "XENFT: Forwarder is already set");
        _trustedForwarder = trustedForwarder;
    }

    // SUPPORT FOR ERC2981 ROYALTY INFO

    /**
        @dev Implements getting Royalty Info by supported operators
     */
    function royaltyInfo(uint256, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount) {
        uint256 amount = (salePrice * ROYALTY_PCT) / 100;
        return (_deployer, amount > ROYALTY_MIN_AMOUNT ? amount : ROYALTY_MIN_AMOUNT);
    }

    // XEN TORRENT PRIVATE / INTERNAL HELPERS

    /**
        @dev Sets specified XENFT as redeemed
     */
    function _setRedeemed(uint256 tokenId) private {
        mintInfo[tokenId] = mintInfo[tokenId] | uint256(1);
    }

    /**
        @dev Determines power group index for Collector Class
     */
    function _powerGroup(uint256 vmus, uint256 term) private pure returns (uint256) {
        return (vmus * term) / POWER_GROUP_SIZE;
    }

    /**
        @dev calculates Collector Series index
    */
    function _seriesIdx(uint256 count, uint256 term) private pure returns (uint256 index) {
        if (_powerGroup(count, term) > 7) return 7;
        return _powerGroup(count, term);
    }

    /**
        @dev internal helper to determine special class tier based on XEN to be burned
     */
    function _specialTier(uint256 burning) private view returns (uint256) {
        for (uint256 i = specialSeriesBurnRates.length - 1; i > 0; i--) {
            if (burning > specialSeriesBurnRates[i] - 1) {
                return i;
            }
        }
        return 0;
    }

    /**
        @dev internal helper to collect params and encode MintInfo
     */
    function _mintInfo(
        address proxy,
        uint256 count,
        uint256 term,
        uint256 burning,
        uint256 tokenId
    ) private view returns (uint256) {
        bool apex = isApex(tokenId);
        uint256 series = _seriesIdx(count, term);
        if (apex) series = uint8(7 + _specialTier(burning)) | 0x80; // Apex Class
        if (burning > 0 && !apex) series = uint8(8) | 0x40; // Limited Class
        (, , uint256 maturityTs, uint256 rank, uint256 amp, uint256 eaa) = xenCrypto.userMints(proxy);
        return MintInfo.encodeMintInfo(term, maturityTs, rank, amp, eaa, series, false);
    }

    /**
        @dev internal torrent interface. initiates Bulk Mint (Torrent) Operation
     */
    function _bulkClaimRank(
        uint256 count,
        uint256 term,
        uint256 tokenId,
        uint256 burning
    ) private {
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
        uint256 tier = _specialTier(burning);
        if (tier == 1) {
            require(count > SPECIAL_CLASSES_VMU_THRESHOLD, "XENFT: under req VMU count");
            require(block.timestamp < genesisTs + LIMITED_CLASS_TIME_THRESHOLD, "XENFT: limited time expired");
            return tokenIdCounter++;
        }
        if (tier > 1) {
            require(_msgSender() == tx.origin, "XENFT: only EOA allowed for this category");
            require(count > SPECIAL_CLASSES_VMU_THRESHOLD, "XENFT: under req VMU count");
            require(specialSeriesCounters[tier] < specialSeriesTokenLimits[tier] + 1, "XENFT: series sold out");
            return specialSeriesCounters[tier]++;
        }
        return tokenIdCounter++;
    }

    // PUBLIC GETTERS

    /**
        @dev public getter for tokens owned by address
     */
    function ownedTokens() external view returns (uint256[] memory) {
        return _ownedTokens[_msgSender()];
    }

    /**
        @dev determines if tokenId corresponds to limited series
     */
    function isApex(uint256 tokenId) public pure returns (bool apex) {
        apex = tokenId < COLLECTOR_CLASS_COUNTER;
    }

    // PUBLIC TRANSACTIONAL INTERFACE

    /**
        @dev public torrent interface. initiates Bulk Mint (Torrent) Operation (ordinary series)
     */
    function bulkClaimRank(uint256 count, uint256 term) public returns (uint256) {
        require(count > 0, "XENFT: Illegal count");
        require(term > 0, "XENFT: Illegal term");
        uint256 tokenId = _getTokenId(count, 0);
        _bulkClaimRank(count, term, tokenId, 0);
        _safeMint(_msgSender(), tokenId);
        _ownedTokens[_msgSender()].addItem(tokenId);
        emit StartTorrent(_msgSender(), count, term);
        return tokenId;
    }

    /**
        @dev public torrent interface. initiates Bulk Mint (Torrent) Operation (special series)
     */
    function bulkClaimRankLimited(
        uint256 count,
        uint256 term,
        uint256 burning
    ) public returns (uint256) {
        require(_tokenId == 0, "XENFT: reentrancy detected");
        require(count > 0, "XENFT: Illegal count");
        require(term > 0, "XENFT: Illegal term");
        require(burning > specialSeriesBurnRates[1] - 1, "XENFT: not enough burn amount");
        uint256 balance = IERC20(xenCrypto).balanceOf(_msgSender());
        require(balance > burning - 1, "XENFT: not enough XEN balance");
        uint256 approved = IERC20(xenCrypto).allowance(_msgSender(), address(this));
        require(approved > burning - 1, "XENFT: not enough XEN balance approved for burn");
        _tokenId = _getTokenId(count, burning);
        _bulkClaimRank(count, term, _tokenId, burning);
        IBurnableToken(xenCrypto).burn(_msgSender(), burning);
        return _tokenId;
    }

    /**
        @dev public torrent interface. initiates Mint Reward claim and collection and terminates Torrent Operation
     */
    function bulkClaimMintReward(uint256 tokenId, address to) external {
        require(ownerOf(tokenId) == _msgSender(), "XENFT: Incorrect owner");
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
        emit EndTorrent(_msgSender(), tokenId, to);
    }
}
