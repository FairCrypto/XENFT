// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./MintInfo.sol";
import "./DateTime.sol";
import "./FormattedStrings.sol";
import "./SVG.sol";

/**
    @dev Library contains methods to generate on-chain NFT metadata
*/
library Metadata {
    using DateTime for uint256;
    using MintInfo for uint256;
    using Strings for uint256;

    uint256 public constant POWER_GROUP_SIZE = 7_500;
    uint256 public constant MAX_POWER = 52_500;

    uint256 public constant COLORS_FULL_SCALE = 300;
    uint256 public constant LIMITED_LUMINOSITY = 45;
    uint256 public constant BASE_SATURATION = 75;
    uint256 public constant BASE_LUMINOSITY = 38;
    uint256 public constant GROUP_SATURATION = 100;
    uint256 public constant GROUP_LUMINOSITY = 50;
    uint256 public constant DEFAULT_OPACITY = 1;
    uint256 public constant NO_COLOR = 360;

    // PRIVATE HELPERS

    // The following pure methods returning arrays are workaround to use array constants,
    // not yet available in Solidity

    function _powerGroupColors() private pure returns (uint256[8] memory) {
        return [uint256(360), 1, 30, 60, 120, 180, 240, 300];
    }

    function _huesRare() private pure returns (uint256[3] memory) {
        return [uint256(169), 210, 305];
    }

    function _huesLimited() private pure returns (uint256[3] memory) {
        return [uint256(263), 0, 42];
    }

    function _stopOffsets() private pure returns (uint256[3] memory) {
        return [uint256(10), 50, 90];
    }

    function _gradColorsRegular() private pure returns (uint256[4] memory) {
        return [uint256(150), 150, 20, 20];
    }

    function _gradColorsBlack() private pure returns (uint256[4] memory) {
        return [uint256(100), 100, 20, 20];
    }

    function _gradColorsSpecial() private pure returns (uint256[4] memory) {
        return [uint256(100), 100, 0, 0];
    }

    /**
        @dev private helper to determine XENFT group index by its power
             (power = count of VMUs * mint term in days)
     */
    function _powerGroup(uint256 vmus, uint256 term) private pure returns (uint256) {
        return (vmus * term) / POWER_GROUP_SIZE;
    }

    /**
        @dev private helper to generate SVG gradients for limited XENFT series
     */
    function _limitedSeriesGradients(bool rare) private pure returns (SVG.Gradient[] memory gradients) {
        uint256[3] memory specialColors = rare ? _huesRare() : _huesLimited();
        SVG.Color[] memory colors = new SVG.Color[](3);
        for (uint256 i = 0; i < colors.length; i++) {
            colors[i] = SVG.Color({
                h: specialColors[i],
                s: BASE_SATURATION,
                l: LIMITED_LUMINOSITY,
                a: DEFAULT_OPACITY,
                off: _stopOffsets()[i]
            });
        }
        gradients = new SVG.Gradient[](1);
        gradients[0] = SVG.Gradient({colors: colors, id: 0, coords: _gradColorsSpecial()});
    }

    /**
        @dev private helper to generate SVG gradients for regular XENFT series
     */
    function _regularSeriesGradients(uint256 vmus, uint256 term)
        private
        pure
        returns (SVG.Gradient[] memory gradients)
    {
        SVG.Color[] memory colors = new SVG.Color[](2);
        uint256 powerHue = term * vmus > MAX_POWER ? NO_COLOR : 1 + (term * vmus * COLORS_FULL_SCALE) / MAX_POWER;
        // group
        uint256 groupHue = _powerGroupColors()[_powerGroup(vmus, term) > 7 ? 7 : _powerGroup(vmus, term)];
        colors[0] = SVG.Color({
            h: groupHue,
            s: groupHue == NO_COLOR ? 0 : GROUP_SATURATION,
            l: groupHue == NO_COLOR ? 0 : GROUP_LUMINOSITY,
            a: DEFAULT_OPACITY,
            off: _stopOffsets()[0]
        });
        // power
        colors[1] = SVG.Color({
            h: powerHue,
            s: powerHue == NO_COLOR ? 0 : BASE_SATURATION,
            l: powerHue == NO_COLOR ? 0 : BASE_LUMINOSITY,
            a: DEFAULT_OPACITY,
            off: _stopOffsets()[2]
        });
        gradients = new SVG.Gradient[](1);
        gradients[0] = SVG.Gradient({
            colors: colors,
            id: 0,
            coords: groupHue == NO_COLOR ? _gradColorsBlack() : _gradColorsRegular()
        });
    }

    /**
        @dev private helper to construct cRank prop of NFT metadata
     */
    function _cRankProp(uint256 rank, uint256 count) private pure returns (bytes memory) {
        if (count == 1) return abi.encodePacked(rank.toString());
        return abi.encodePacked(rank.toString(), "..", (rank + count - 1).toString());
    }

    // PUBLIC INTERFACE

    /**
        @dev public interface to generate SVG image based on XENFT params
     */
    function svgData(
        uint256 tokenId,
        uint256 count,
        uint256 info,
        address token,
        uint256 burned
    ) external view returns (bytes memory) {
        string memory symbol = IERC20Metadata(token).symbol();
        (uint256 seriesIdx, bool rare, bool limited) = info.getSeries();
        SVG.SvgParams memory params = SVG.SvgParams({
            symbol: symbol,
            xenAddress: token,
            tokenId: tokenId,
            term: info.getTerm(),
            rank: info.getRank(),
            count: count,
            maturityTs: info.getMaturityTs(),
            amp: info.getAMP(),
            eaa: info.getEAA(),
            xenBurned: burned,
            series: StringData.getSeriesName(StringData.SERIES, seriesIdx),
            redeemed: info.getRedeemed()
        });
        uint256 quoteIdx = uint256(keccak256(abi.encode(info))) % StringData.QUOTES_COUNT;
        if (rare || limited) {
            return SVG.image(params, _limitedSeriesGradients(rare), quoteIdx, rare, limited);
        }
        return SVG.image(params, _regularSeriesGradients(count, info.getTerm()), quoteIdx, rare, limited);
    }

    /**
        @dev private helper to construct attributes portion of NFT metadata
     */
    function attributes(uint256 count, uint256 mintInfo, uint256 burned) external pure returns (bytes memory) {
        (
            ,
            uint256 maturityTs,
            uint256 rank,
            uint256 amp,
            uint256 eaa,
            uint256 series,
            bool rare,
            bool limited,
            bool redeemed
        ) = MintInfo.decodeMintInfo(mintInfo);
        bytes memory attr1 = abi.encodePacked(
            '{"trait_type":"Series","value":"',
            StringData.getSeriesName(StringData.SERIES, series),
            '"},'
            '{"trait_type":"VMUs","value":"',
            count.toString(),
            '"},'
            '{"trait_type":"cRank","value":"',
            _cRankProp(rank, count),
            '"},'
        );
        bytes memory attr2 = abi.encodePacked(
            '{"trait_type":"AMP","value":"',
            amp.toString(),
            '"},'
            '{"trait_type":"EAA (%)","value":"',
            (eaa / 10).toString(),
            '"},'
            '{"trait_type":"Maturity","display_type":"date","value":"',
            maturityTs.toString(),
            '"},'
            '{"trait_type":"Redeemed","value":"',
            redeemed ? "yes" : "no",
            '"},'
        );
        bytes memory attr3 = abi.encodePacked(
            '{"trait_type":"limited","value":"',
            limited ? "yes" : "no",
            '"},'
            '{"trait_type":"rare","value":"',
            rare ? "yes" : "no",
            '"},'
            '{"trait_type":"XEN Burned","value":"',
            burned.toString(),
            '"}'
        );
        return abi.encodePacked("[", attr1, attr2, attr3, "]");
    }

    // TODO: delete after testing
    function formattedString(uint256 n) public pure returns (string memory) {
        return FormattedStrings.toFormattedString(n);
    }
}
