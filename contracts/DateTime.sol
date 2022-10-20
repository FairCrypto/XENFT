// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/utils/Strings.sol";
import './BokkyPooBahsDateTimeLibrary.sol';

library DateTime {

    using Strings for uint256;

    bytes constant public months = bytes("JanFebMarAprMayJunJulAugSepOctNovDec");

    function monthAsString(uint256 idx) internal pure returns (string memory) {
        require(idx > 0, 'bad idx');
        bytes memory str = new bytes(3);
        uint256 offset = (idx - 1) * 3;
        str[0] = bytes1(months[offset]);
        str[1] = bytes1(months[offset + 1]);
        str[2] = bytes1(months[offset + 2]);
        return string(str);
    }

    /**
     *   @dev returns string of format 'Jan 01, 2022 18:00 UTC'
     */
    function asString(uint256 ts) external pure returns (string memory) {
        (uint year, uint month, uint day, uint hour, uint minute,) =
            BokkyPooBahsDateTimeLibrary.timestampToDateTime(ts);
        return string(abi.encodePacked(
            monthAsString(month),
            ' ',
            day.toString(),
            ', ',
            year.toString(),
            ' ',
            hour.toString(),
            ':',
            minute.toString(),
            ' UTC'
        ));
    }

}
