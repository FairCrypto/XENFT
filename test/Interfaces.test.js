// SPDX-License-Identifier: MIT

const assert = require('assert')
const {id} = require("ethers/lib/utils");
require('dotenv').config()

const XENFT = artifacts.require("XENFT");

const INTERFACES = {
    ERC165: [
        'supportsInterface(bytes4)',
    ],
    ERC721: [
        'balanceOf(address)',
        'ownerOf(uint256)',
        'approve(address,uint256)',
        'getApproved(uint256)',
        'setApprovalForAll(address,bool)',
        'isApprovedForAll(address,address)',
        'transferFrom(address,address,uint256)',
        'safeTransferFrom(address,address,uint256)',
        'safeTransferFrom(address,address,uint256,bytes)',
    ],
    ERC721Metadata: [
        'name()',
        'symbol()',
        'tokenURI(uint256)',
    ],
    ERC2981: [
        'royaltyInfo(uint256,uint256)',
    ],
    ERC2771: [
        'isTrustedForwarder(address)'
    ],
    IBurnableRedeemable: [
        'onTokenBurned(address,uint256)'
    ],
    BAD_ONE: [
        'selfdestruct(bytes,address,address)'
    ]
};

const interfaceSelector = (abi = []) => {
    const buf = abi.reduce((res, m) => {
        const methodId = id(m);
        const sigHash = Buffer.from(methodId.slice(2), 'hex').slice(0, 4);
        return res.map((b,i) => b ^ sigHash[i]);
    }, Buffer.of(0,0,0,0))
    return `0x${buf.toString('hex')}`
}

contract("Interfaces", async () => {

    let xeNFT;

    before(async () => {
        try {
            xeNFT = await XENFT.deployed();
        } catch (e) {
            console.error(e)
        }
    })

    it("XENFT Contract should support IBurnableRedeemable interface", async () => {
        assert.ok(await xeNFT.supportsInterface(interfaceSelector(INTERFACES.IBurnableRedeemable)));
    })

    it("XENFT Contract should support IERC165 interface", async () => {
        assert.ok(await xeNFT.supportsInterface(interfaceSelector(INTERFACES.ERC165)));
    })

    it("XENFT Contract should support IERC721 interface", async () => {
        assert.ok(await xeNFT.supportsInterface(interfaceSelector(INTERFACES.ERC721)));
    })

    it("XENFT Contract should support ERC721Metadata interface", async () => {
        assert.ok(await xeNFT.supportsInterface(interfaceSelector(INTERFACES.ERC721Metadata)));
    })

    it("XENFT Contract should support ERC2981 interface", async () => {
        assert.ok(await xeNFT.supportsInterface(interfaceSelector(INTERFACES.ERC2981)));
    })

    it("XENFT Contract should support ERC2771 interface", async () => {
        assert.ok(await xeNFT.supportsInterface(interfaceSelector(INTERFACES.ERC2771)));
    })

    it("XENFT Contract should NOT support unsupported interface", async () => {
        assert.ok(!(await xeNFT.supportsInterface(interfaceSelector(INTERFACES.BAD_ONE))));
    })

})
