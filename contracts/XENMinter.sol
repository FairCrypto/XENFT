// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import '@faircrypto/xen-crypto/contracts/XENCrypto.sol';

contract XENMinter {

    XENCrypto immutable public xenCrypto;
    mapping(address => mapping(bytes =>uint256)) public map;

    constructor(address xenCrypto_) {
        xenCrypto = XENCrypto(xenCrypto_);
    }

    function callClaimRank(uint256 term) external {
        bytes memory callData = abi.encodeWithSignature("claimRank(uint256)", term);
        (bool success, ) = address(xenCrypto).call(callData);
        require(success, 'call failed');
    }

    function callClaimMintReward(address to) external {
        bytes memory callData = abi.encodeWithSignature("claimMintRewardAndShare(address,uint256)", to, uint256(100));
        (bool success, ) = address(xenCrypto).call(callData);
        require(success, 'call failed');
    }

    function bulkClaimRank(uint256 count, uint256 term, bytes calldata salt_)
        external
        // returns(uint256 total, uint256 attempts)
    {
        bytes memory bytecode = bytes.concat(
            bytes20(0x3D602d80600A3D3981F3363d3d373d3D3D363d73),
            bytes20(address(this)),
            bytes15(0x5af43d82803e903d91602b57fd5bf3)
        );
        uint256 i = map[msg.sender][salt_] + 1;
        uint256 end = count + i;
        bytes memory callData = abi.encodeWithSignature("callClaimRank(uint256)", term);
        for (i; i < end; i++) {
            bytes32 salt = keccak256(abi.encodePacked(salt_, i, msg.sender));
            bool succeeded;
            assembly {
                let proxy := create2(
                    0,
                    add(bytecode, 0x20),
                    mload(bytecode),
                    salt)
                succeeded := call(
                    gas(),
                    proxy,
                    0,
                    add(callData, 0x20),
                    mload(callData),
                    0,
                    0
                )
            }
            //total = succeeded ? total + 1 : total;
            //attempts++;
        }
        map[msg.sender][salt_] += count;
    }

    function bulkClaimMintReward(uint256 count, address to, bytes calldata salt_)
        external
        // returns(uint256 total, uint256 attempts)
    {
        bytes memory bytecode = bytes.concat(
            bytes20(0x3D602d80600A3D3981F3363d3d373d3D3D363d73),
            bytes20(address(this)),
            bytes15(0x5af43d82803e903d91602b57fd5bf3)
        );
        // uint256 i = map[msg.sender][salt_] + 1;
        uint256 i = 1;
        uint256 end = count + i;
        bytes memory callData = abi.encodeWithSignature("callClaimMintReward(address)", to);
        for (i; i < end; i++) {
            bytes32 salt = keccak256(abi.encodePacked(salt_, i, msg.sender));
            bool succeeded;
            bytes32 hash = keccak256(abi.encodePacked(hex'ff', address(this), salt, keccak256(bytecode)));
            address proxy = address(uint160(uint(hash)));
            // require(proxy == proxy_, 'bad proxy');
            assembly {
                succeeded := call(
                    gas(),
                    proxy,
                    0,
                    add(callData, 0x20),
                    mload(callData),
                    0,
                    0
                )
            }
            // total = succeeded ? total + 1 : total;
            // attempts++;
        }
        //map[msg.sender][salt_] += count;
    }

}
