// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./DateTime.sol";

library SVG {

    struct SvgParams {
        string symbol;
        address xenAddress;
        uint256 tokenId;
        uint256 term;
        uint256 rank;
        uint256 count;
        uint256 maturityTs;
    }

    using DateTime for uint256;
    using Strings for uint256;
    using Strings for address;

    string constant STYLE = '<style>.base {fill: #ededed;font-family:Montserrat,arial,sans-serif;font-size:30px;font-weight:400;} .title {font-weight:100;}.meta {font-size:12px;}.small {font-size:8px;}.quote {font-size:10px;}.animated {animation: dash 0.3s linear infinite;}@keyframes dash {from {stroke-dashoffset: 0;} to {stroke-dashoffset: 8;} }</style>';

    function getQuote(uint256 idx) pure internal returns (bytes memory) {
        if (idx == 0) return unicode"“If you realize you have enough, you are truly rich.” ― Lao Tzu";
        return '';
    }

    function gradient(uint256 color, uint256 angle, uint256 id) pure internal returns (bytes memory) {
        return abi.encodePacked(
            '<linearGradient gradientTransform="rotate(',
            angle.toString(),
            ', 0.4, 0.4)" x1="50%" y1="0%" x2="50%" y2="100%" id="g',
            id.toString(),
            '"><stop stop-color="hsl(',
            color.toString(),
            ', 100%, 25%)" stop-opacity="1" offset="0%"/><stop stop-color="rgba(64,64,64,0)" stop-opacity="0.5" offset="100%"/></linearGradient>'
        );
    }

    function defs(uint256[] memory colors, uint256[] memory angles) pure internal returns (bytes memory) {
        string memory res;
        for(uint i = 0; i < colors.length; i++) {
            res = string.concat(res, string(gradient(colors[i], angles[i], i)));
        }
        return abi.encodePacked('<defs>', res, '</defs>');
    }

    function rect(uint256 id) pure internal returns (bytes memory) {
        return abi.encodePacked(
            '<rect width="100%" height="100%" fill="url(#g',
            id.toString(),
            ')" rx="10px" ry="10px" stroke-linejoin="round"/>'
        );
    }

    function animation() pure internal returns (string memory) {
        return '<rect width="94%" height="96%" fill="transparent" rx="10px" ry="10px" stroke-linejoin="round" x="3%" y="2%" stroke-dasharray="1,6" stroke="white" class="animated"/>';
    }

    function g(uint256[] memory colors) pure internal returns (bytes memory) {
        string memory res;
        for(uint i = 0; i < colors.length; i++) {
            res = string.concat(res, string(rect(i)));
        }
        return abi.encodePacked(res, animation());
    }

    function logo() pure internal returns (bytes memory) {
        return abi.encodePacked(
            '<line x1="120" y1="100" x2="230" y2="230" stroke="#ededed" stroke-width="2"/>',
            '<line x1="230" y1="100" x2="120" y2="230" stroke="#ededed" stroke-width="2"/>'
        );
    }

    function contractData(string memory symbol, address xenAddress) pure internal returns (bytes memory) {
        return abi.encodePacked(
            '<text x="50%" y="5%" class="base small" dominant-baseline="middle" text-anchor="middle">',
            symbol,
            unicode"・",
            xenAddress.toHexString(),
            '</text>'
        );
    }

    function meta(uint256 tokenId, uint256 term, uint256 rank, uint256 count, uint256 maturityTs) pure internal returns (bytes memory) {

        bytes memory part1 = abi.encodePacked(
            '<text x="50%" y="55%" class="base title" dominant-baseline="middle" text-anchor="middle">XEN CRYPTO</text><text x="18%" y="70%" class="base meta" dominant-baseline="middle" >#',
            tokenId.toString(),
            '</text><text x="18%" y="75%" class="base meta" dominant-baseline="middle" >Term: ',
            term.toString()
        );
        bytes memory part2 = abi.encodePacked(
            ' day(s)</text><text x="18%" y="80%" class="base meta" dominant-baseline="middle" >cRank: ',
            rank.toString(),
            '..',
            (rank + count - 1).toString()
        );
        bytes memory part3 = abi.encodePacked(
            ' (',
            count.toString(),
            ')</text><text x="18%" y="85%" class="base meta" dominant-baseline="middle" >Maturity: ',
            maturityTs.asString(),
            '</text>'
        );
        return abi.encodePacked(part1, part2, part3);
    }

    function quote() pure internal returns (bytes memory) {
        return abi.encodePacked(
            '<text x="50%" y="95%" class="base quote" dominant-baseline="middle" text-anchor="middle">',
            getQuote(0),
            '</text>'
        );
    }

    function image(SvgParams memory params, uint256[] memory colors, uint256[] memory angles) pure internal returns (bytes memory) {
        bytes memory graphics = abi.encodePacked(
            defs(colors, angles),
            STYLE,
            g(colors),
            logo()
        );
        bytes memory metadata = abi.encodePacked(
            contractData(params.symbol, params.xenAddress),
            meta(params.tokenId, params.term, params.rank, params.count, params.maturityTs),
            quote()
        );
        return abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 525">',
            graphics,
            metadata,
            '</svg>'
        );
    }

}
