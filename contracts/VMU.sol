// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IXENProxying.sol";

contract VMU is IXENProxying {

    // original contract marking to distinguish from proxy copies
    address private immutable _original;
    address private immutable _xenCrypto;

    constructor(address xenCrypto_, address original_) {
        _original = original_;
        _xenCrypto = xenCrypto_;
    }

    // IMPLEMENTATION OF XENProxying INTERFACE
    // FUNCTIONS IN PROXY COPY CONTRACTS (VMUs), CALLING ORIGINAL XEN CRYPTO CONTRACT
    /**
        @dev function callable only in proxy contracts from the original one => XENCrypto.claimRank(term)
     */
    function callClaimRank(uint256 term) external {
        require(msg.sender == _original, "XEN Proxy: unauthorized");
        bytes memory callData = abi.encodeWithSignature("claimRank(uint256)", term);
        (bool success, ) = _xenCrypto.call(callData);
        require(success, "call failed");
    }

    /**
        @dev function callable only in proxy contracts from the original one => XENCrypto.claimMintRewardAndShare()
     */
    function callClaimMintReward(address to) external {
        require(msg.sender == _original, "XEN Proxy: unauthorized");
        bytes memory callData = abi.encodeWithSignature("claimMintRewardAndShare(address,uint256)", to, uint256(100));
        (bool success, ) = _xenCrypto.call(callData);
        require(success, "call failed");
    }

    /**
        @dev function callable only in proxy contracts from the original one => destroys the proxy contract
     */
    function powerDown() external {
        require(msg.sender == _original, "XEN Proxy: unauthorized");
        selfdestruct(payable(address(0)));
    }

}
