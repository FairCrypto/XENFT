// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@faircrypto/xen-crypto/contracts/interfaces/IBurnableToken.sol";
import "@faircrypto/xen-crypto/contracts/interfaces/IBurnRedeemable.sol";

contract Burner is Context, IBurnRedeemable, IERC165, ERC20("Burner", "BURN") {
    IBurnableToken public xenContract;

    constructor(address _xenContractAddress) {
        xenContract = IBurnableToken(_xenContractAddress);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IBurnRedeemable).interfaceId;
    }

    function exchangeTokens(uint256 tokenId) external {
        xenContract.burn(msg.sender, tokenId);
    }

    function onTokenBurned(address user, uint256 tokenId) public {
        require(msg.sender == address(xenContract), "Burner: wrong caller");
        require(user != address(0), "Burner: zero user address");
        require(tokenId != 0, "Burner: bad tokenId");

        _mint(user, tokenId);
    }
}
