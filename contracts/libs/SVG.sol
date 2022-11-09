// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./DateTime.sol";
import "./StringData.sol";
import "./FormattedStrings.sol";

/*
    @dev        Library to create SVG image for XENFT metadata
    @dependency depends on DataTime.sol and StringData.sol libraries
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
        uint256 xenBurned;
        bool redeemed;
        string series;
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
        uint256[4] coords;
    }

    using DateTime for uint256;
    using Strings for uint256;
    using FormattedStrings for uint256;
    using Strings for address;

    string private constant _STYLE =
        "<style> "
        ".base {fill: #ededed;font-family:Montserrat,arial,sans-serif;font-size:30px;font-weight:400;} "
        ".series {text-transform: uppercase} "
        ".logo {font-size:200px;font-weight:100;} "
        ".meta {font-size:12px;} "
        ".small {font-size:8px;} "
        ".burn {font-weight:500;font-size:16px;} }"
        "</style>";

    string private constant _COMMON =
        '<g>'
        '<path '
        'fill="#ededed" '
        'transform="scale(0.3)" '
        'd="M928,1298 c14.95,18.54,22.23,40.44,21.28,60.48c-6.91,-16.93,-17.64,-34.09,-31.87,-49.9l-4.77,4.77c-0.54,0.54,-1.42,0.54,-1.96,0l-15.08,-15.07c-0.54,-0.54,-0.54,-1.42,0,-1.96l4.63,-4.63c-16.19,-14.04,-33.67,-24.49,-50.81,-30.96c20.2,-1.52,42.5,5.45,61.44,20.33l2.09,-2.09c0.54,-0.54,1.42,-0.54,1.96,0l15.08,15.08c0.54,0.54,0.54,1.42,0,1.96l-1.99,1.99l0,0zm-32.96,5.04l12.22,12.22l-65.64,65.64c-3.36,3.36,-8.86,3.36,-12.22,0l0,0c-3.36,-3.36,-3.36,-8.86,0,-12.22l65.64,-65.64l0,0z"/>'
        '</g>';

    string private constant _LIMITED =
        '<g> '
        '<path fill="#ededed" '
        'transform="scale(0.7) translate(333, 520)" '
        'd="m 37 75 c -6 -2 -15 -21 -1 -39 C 34 42 41 49 44 47 c 9 -4 11 -17 10 -30 c 0 0 7.4 11.6 7.6 25.8 c 0.2 9.4 8.8 -6.4 5.4 -12 c 9.6 8.2 10.2 30.4 -4 44.2 c 1.6 -12 -10 -15 -7 -27 c -1.8 6.6 -1 13 -6 17 c -2 2 -11.4 -2.2 -11 -11 c -2.4 7.2 6 20 3 21 z"/>'
        '</g>';

    string private constant _RARE =
        '<g transform="scale(0.5) translate(533, 790)">'
        '<circle r="39" stroke="#ededed" fill="transparent"/>'
        '<path fill="#ededed" '
        'd="M0,38 a38,38 0 0 1 0,-76 a19,19 0 0 1 0,38 a19,19 0 0 0 0,38 z m -5 -57 a 5,5 0 1,0 10,0 a 5,5 0 1,0 -10,0 z" '
        'fill-rule="evenodd"/>'
        '<path fill="#ededed" '
        'd="m -5, 19 a 5,5 0 1,0 10,0 a 5,5 0 1,0 -10,0"/>'
        '</g>';

    string private constant _LOGO =
        '<path fill="#ededed" '
        'd="M122.7,227.1 l-4.8,0l55.8,-74l0,3.2l-51.8,-69.2l5,0l48.8,65.4l-1.2,0l48.8,-65.4l4.8,0l-51.2,68.4l0,-1.6l55.2,73.2l-5,0l-52.8,-70.2l1.2,0l-52.8,70.2z" '
        'vector-effect="non-scaling-stroke" />';

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
        @dev internal helper to encode position for `Gradient` SVG tag
     */
    function pos(uint256[4] memory coords) internal pure returns (bytes memory) {
        return abi.encodePacked(
            'x1="', coords[0].toString(), '%" '
            'y1="', coords[1].toString(), '%" '
            'x2="', coords[2].toString(), '%" '
            'y2="', coords[3].toString(), '%" '
        );
    }

    /**
        @dev internal helper to create `Gradient` SVG tag
     */
    function linearGradient(Color[] memory colors, uint256 id, uint256[4] memory coords) internal pure returns (bytes memory) {
        string memory stops = "";
        for (uint256 i = 0; i < colors.length; i++) {
            if (colors[i].h != 0) {
                stops = string.concat(stops, string(colorStop(colors[i])));
            }
        }
        return
            abi.encodePacked(
                "<linearGradient  ",
                pos(coords),
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
        return abi.encodePacked("<defs>", linearGradient(grad.colors, 0, grad.coords), "</defs>");
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
        if (count == 1) return abi.encodePacked(rank.toString());
        return abi.encodePacked(rank.toString(), "..", (rank + count - 1).toString());
    }

    /**
        @dev internal helper to create 1st part of metadata section of SVG
     */
    function meta1(
        uint256 tokenId,
        uint256 count,
        uint256 eaa,
        string memory series,
        uint256 xenBurned
    ) internal pure returns (bytes memory) {
        bytes memory part1 = abi.encodePacked(
            "<text "
            'x="50%" '
            'y="50%" '
            'class="base " '
            'dominant-baseline="middle" '
            'text-anchor="middle">'
            "XEN CRYPTO"
            "</text>"
            "<text "
            'x="50%" '
            'y="56%" '
            'class="base burn" '
            'text-anchor="middle" '
            'dominant-baseline="middle"> ',
            xenBurned > 0 ? string.concat((xenBurned / 10**18).toFormattedString(), ' X') : '',
            "</text>"
            "<text "
            'x="18%" '
            'y="62%" '
            'class="base meta" '
            'dominant-baseline="middle"> '
            "#",
            tokenId.toString(),
            "</text>"
            "<text "
            'x="82%" '
            'y="62%" '
            'class="base meta series" '
            'dominant-baseline="middle" '
            'text-anchor="end" >',
            series,
            "</text>"

        );
        bytes memory part2 = abi.encodePacked(
            "<text "
            'x="18%" '
            'y="68%" '
            'class="base meta" '
            'dominant-baseline="middle" >'
            "VMU: ",
            count.toString(),
            "</text>"
            "<text "
            'x="18%" '
            'y="72%" '
            'class="base meta" '
            'dominant-baseline="middle" >'
            "EAA: ",
            (eaa / 10).toString(),
            "%"
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
        uint256 term,
        uint256 rank,
        uint256 count
    ) internal pure returns (bytes memory) {
        bytes memory part3 = abi.encodePacked(
            "<text "
            'x="18%" '
            'y="76%" '
            'class="base meta" '
            'dominant-baseline="middle" >'
            "AMP: ",
            amp.toString(),
            "</text>"
            "<text "
            'x="18%" '
            'y="80%" '
            'class="base meta" '
            'dominant-baseline="middle" >'
            "Term: ",
            term.toString()
        );
        bytes memory part4 = abi.encodePacked(
            "%"
            "</text>"
            "<text "
            'x="18%" '
            'y="84%" '
            'class="base meta" '
            'dominant-baseline="middle" >'
            "cRank: ",
            rankAndCount(rank, count),
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
                StringData.getQuote(StringData.QUOTES, idx),
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
        uint256 idx,
        bool rare,
        bool limited
    ) internal pure returns (bytes memory) {
        string memory mark = limited ? _LIMITED : rare ? _RARE : _COMMON;
        bytes memory graphics = abi.encodePacked(
            defs(gradients[0]),
            _STYLE,
            g(gradients.length),
            _LOGO,
            mark
        );
        bytes memory metadata = abi.encodePacked(
            contractData(params.symbol, params.xenAddress),
            meta1(params.tokenId, params.count, params.eaa, params.series, params.xenBurned),
            meta2(params.maturityTs, params.amp, params.term, params.rank, params.count),
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
