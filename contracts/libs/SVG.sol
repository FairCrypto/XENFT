// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./DateTime.sol";
import "./Quotes.sol";

/*
    @dev        Library to create SVG image for XENFT metadata
    @dependency depends on DataTime.sol and Quotes.sol libraries
 */
library SVG {
    // Type to encode all data params for SVG image generation
    struct SvgParams {
        string symbol;
        address xenAddress;
        uint256 tokenId;
        uint256 term;
        uint256 rank;
        uint256 count;
        uint256 maturityTs;
        uint256 amp;
        uint256 eaa;
        bool redeemed;
    }

    // Type to encode SVG gradient stop color on HSL color scale
    struct Color {
        uint256 h;
        uint256 s;
        uint256 l;
        uint256 a;
        uint256 off;
    }

    // Type to encode SVG gradient
    struct Gradient {
        Color[] colors;
        uint256 id;
    }

    using DateTime for uint256;
    using Strings for uint256;
    using Strings for address;

    string private constant _STYLE =
        "<style> "
        ".base {fill: #ededed;font-family:Montserrat,arial,sans-serif;font-size:30px;font-weight:400;} "
        ".title {} "
        ".logo {font-size:200px;font-weight:100;} "
        ".meta {font-size:12px;} "
        ".small {font-size:8px;} }"
        "</style>";

    /**
        @dev internal helper to create HSL-encoded color prop for SVG tags
     */
    function colorHSL(Color memory c) internal pure returns (bytes memory) {
        return abi.encodePacked("hsl(", c.h.toString(), ", ", c.s.toString(), "%, ", c.l.toString(), "%)");
    }

    /**
        @dev internal helper to create `stop` SVG tag
     */
    function colorStop(Color memory c) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                '<stop stop-color="',
                colorHSL(c),
                '" stop-opacity="',
                c.a.toString(),
                '" offset="',
                c.off.toString(),
                '%"/>'
            );
    }

    /**
        @dev internal helper to create `Gradient` SVG tag
     */
    function linearGradient(Color[] memory colors, uint256 id) internal pure returns (bytes memory) {
        string memory stops = "";
        for (uint256 i = 0; i < colors.length; i++) {
            if (colors[i].h != 0) {
                stops = string.concat(stops, string(colorStop(colors[i])));
            }
        }
        return
            abi.encodePacked(
                "<linearGradient  "
                'x1="100%" '
                'y1="100%" '
                'x2="0%" '
                'y2="0%" '
                'id="g',
                id.toString(),
                '">',
                stops,
                "</linearGradient>"
            );
    }

    /**
        @dev internal helper to create `Defs` SVG tag
     */
    function defs(Gradient memory grad) internal pure returns (bytes memory) {
        return abi.encodePacked("<defs>", linearGradient(grad.colors, 0), "</defs>");
    }

    /**
        @dev internal helper to create `Rect` SVG tag
     */
    function rect(uint256 id) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                "<rect "
                'width="100%" '
                'height="100%" '
                'fill="url(#g',
                id.toString(),
                ')" '
                'rx="10px" '
                'ry="10px" '
                'stroke-linejoin="round" '
                "/>"
            );
    }

    /**
        @dev internal helper to create border `Rect` SVG tag
     */
    function border() internal pure returns (string memory) {
        return
            "<rect "
            'width="94%" '
            'height="96%" '
            'fill="transparent" '
            'rx="10px" '
            'ry="10px" '
            'stroke-linejoin="round" '
            'x="3%" '
            'y="2%" '
            'stroke-dasharray="1,6" '
            'stroke="white" '
            "/>";
    }

    /**
        @dev internal helper to create group `G` SVG tag
     */
    function g(uint256 gradientsCount) internal pure returns (bytes memory) {
        string memory background = "";
        for (uint256 i = 0; i < gradientsCount; i++) {
            background = string.concat(background, string(rect(i)));
        }
        return abi.encodePacked("<g>", background, border(), "</g>");
    }

    /**
        @dev internal helper to create XEN logo line pattern with 2 SVG `lines`
     */
    function logo() internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                '<text '
                'x="50%" '
                'y="31%" '
                'class="base logo" '
                'dominant-baseline="middle" '
                'text-anchor="middle">'
                'X'
                '</text>'
            );
    }

    /**
        @dev internal helper to create `Text` SVG tag with XEN Crypto contract data
     */
    function contractData(string memory symbol, address xenAddress) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                "<text "
                'x="50%" '
                'y="5%" '
                'class="base small" '
                'dominant-baseline="middle" '
                'text-anchor="middle">',
                symbol,
                unicode"・",
                xenAddress.toHexString(),
                "</text>"
            );
    }

    /**
        @dev internal helper to create cRank range string
     */
    function rankAndCount(uint256 rank, uint256 count) internal pure returns (bytes memory) {
        if (count == 1) return abi.encodePacked(rank.toString(), " (", count.toString());
        return abi.encodePacked(rank.toString(), "..", (rank + count - 1).toString(), " (", count.toString());
    }

    /**
        @dev internal helper to create 1st part of metadata section of SVG
     */
    function meta1(
        uint256 tokenId,
        uint256 term,
        uint256 rank,
        uint256 count
    ) internal pure returns (bytes memory) {
        bytes memory part1 = abi.encodePacked(
            "<text "
            'x="50%" '
            'y="50%" '
            'class="base title" '
            'dominant-baseline="middle" '
            'text-anchor="middle">'
            "XEN CRYPTO"
            "</text>"
            "<text "
            'x="18%" '
            'y="63%" '
            'class="base meta" '
            'dominant-baseline="middle"> '
            "#",
            tokenId.toString(),
            "</text>"
            "<text "
            'x="18%" '
            'y="68%" '
            'class="base meta" '
            'dominant-baseline="middle" >'
            "Term: ",
            term.toString()
        );
        bytes memory part2 = abi.encodePacked(
            " day(s)"
            "</text>"
            "<text "
            'x="18%" '
            'y="73%" '
            'class="base meta" '
            'dominant-baseline="middle" >'
            "cRank: ",
            rankAndCount(rank, count),
            " VMUs)"
            "</text>"
        );
        return abi.encodePacked(part1, part2);
    }

    /**
        @dev internal helper to create 2nd part of metadata section of SVG
     */
    function meta2(
        uint256 maturityTs,
        uint256 amp,
        uint256 eaa
    ) internal pure returns (bytes memory) {
        bytes memory part3 = abi.encodePacked(
            "<text "
            'x="18%" '
            'y="78%" '
            'class="base meta" '
            'dominant-baseline="middle" >'
            "AMP: ",
            amp.toString(),
            "</text>"
            "<text "
            'x="18%" '
            'y="83%" '
            'class="base meta" '
            'dominant-baseline="middle" >'
            "EAA: ",
            (eaa / 10).toString()
        );
        bytes memory part4 = abi.encodePacked(
            "%"
            "</text>"
            "<text "
            'x="18%" '
            'y="88%" '
            'class="base meta" '
            'dominant-baseline="middle" >'
            "Maturity: ",
            maturityTs.asString(),
            "</text>"
        );
        return abi.encodePacked(part3, part4);
    }

    /**
        @dev internal helper to create `Text` SVG tag for XEN quote
     */
    function quote(uint256 idx) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                "<text "
                'x="50%" '
                'y="95%" '
                'class="base small" '
                'dominant-baseline="middle" '
                'text-anchor="middle" >',
                Quotes.getQuote(Quotes.QUOTES, idx),
                "</text>"
            );
    }

    /**
        @dev internal helper to generate `Redeemed` stamp
     */
    function stamp(bool redeemed) internal pure returns (bytes memory) {
        if (!redeemed) return "";
        return
            abi.encodePacked(
                "<rect "
                'x="50%" '
                'y="77.5%" '
                'width="100" '
                'height="40" '
                'stroke="black" '
                'stroke-width="1" '
                'fill="none" '
                'rx="5px" '
                'ry="5px" '
                'transform="translate(-50,-20) '
                'rotate(-20,0,400)" />',
                "<text "
                'x="50%" '
                'y="77.5%" '
                'stroke="black" '
                'class="base meta" '
                'dominant-baseline="middle" '
                'text-anchor="middle" '
                'transform="translate(0,0) rotate(-20,-45,380)" >'
                "Redeemed"
                "</text>"
            );
    }

    /**
        @dev main internal helper to create SVG file representing XENFT
     */
    function image(
        SvgParams memory params,
        Gradient[] memory gradients,
        uint256 idx
    ) internal pure returns (bytes memory) {
        bytes memory graphics = abi.encodePacked(defs(gradients[0]), _STYLE, g(gradients.length), logo());
        bytes memory metadata = abi.encodePacked(
            contractData(params.symbol, params.xenAddress),
            meta1(params.tokenId, params.term, params.rank, params.count),
            meta2(params.maturityTs, params.amp, params.eaa),
            quote(idx),
            stamp(params.redeemed)
        );
        return
            abi.encodePacked(
                "<svg "
                'xmlns="http://www.w3.org/2000/svg" '
                'preserveAspectRatio="xMinYMin meet" '
                'viewBox="0 0 350 566">',
                graphics,
                metadata,
                "</svg>"
            );
    }
}
