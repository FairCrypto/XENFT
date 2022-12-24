// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@faircrypto/xen-crypto/contracts/interfaces/IBurnableToken.sol";
import "@faircrypto/xen-crypto/contracts/interfaces/IBurnRedeemable.sol";

/**
    This contract implements IBurnRedeemable but reverts in the callback hook
 */
contract RevertingBurner is IBurnRedeemable, IERC165 {
    IBurnableToken public xenContract;

    constructor(address _xenContractAddress) {
        xenContract = IBurnableToken(_xenContractAddress);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IBurnRedeemable).interfaceId;
    }

    function exchangeTokens(uint256 amount) external {
        xenContract.burn(msg.sender, amount);
    }

    function onTokenBurned(address, uint256) public pure {
        revert();
    }
}
