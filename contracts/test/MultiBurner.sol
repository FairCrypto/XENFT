// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@faircrypto/xen-crypto/contracts/interfaces/IBurnableToken.sol";
import "@faircrypto/xen-crypto/contracts/interfaces/IBurnRedeemable.sol";

contract MultiBurner is Context, IBurnRedeemable, ERC721("Burner", "BURN") {

    using Strings for uint256;

    IBurnableToken public xenContract;

    uint256 private _counter;

    constructor(address _xenContractAddress) {
        xenContract = IBurnableToken(_xenContractAddress);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IBurnRedeemable).interfaceId;
    }

    function exchangeTokens(uint256[] memory tokenIds) external {
        _counter = tokenIds.length - 1;
        for (uint i = 0; i < tokenIds.length; i++) {
            xenContract.burn(msg.sender, tokenIds[i]);
        }
    }

    function onTokenBurned(address user, uint256 tokenId) public {
        // require(_counter > 0, string(abi.encodePacked("Burner: illegal state ", tokenId.toString())));
        require(msg.sender == address(xenContract), "Burner: wrong caller");
        require(user != address(0), "Burner: zero user address");
        require(tokenId != 0, "Burner: bad tokenId");
        if (_counter == 0) {
            _safeMint(user, tokenId);
        } else {
            _counter--;
        }
    }
}
