// SPDX-License-Identifier: MIT

const assert = require('assert')
require('dotenv').config()
// const truffleAssert = require('truffle-assertions')
const timeMachine = require('ganache-time-traveler');

const XENCrypto = artifacts.require("XENCrypto")
const XENTorrent = artifacts.require("XENTorrent")

// const { bn2hexStr, toBigInt, maxBigInt, etherToWei } = require('../src/utils.js')

contract("XEN Torrent", async accounts => {

    let token;
    let minter;
    let xenCryptoAddress;
    let virtualMinters = [];
    let genesisTs = 0;
    let tokenId;
    const term = 10;
    const count = 100;

    before(async () => {
        try {
            token = await XENCrypto.deployed();
            minter = await XENTorrent.deployed();
            xenCryptoAddress = token.address;
        } catch (e) {
            console.error(e)
        }
    })

    it("Should read XEN Crypto Address params", async () => {
        assert.ok(await minter.xenCrypto() === xenCryptoAddress)
    })

    it("Should read XEN Crypto genesisTs", async () => {
        genesisTs = await token.genesisTs().then(_ => _.toNumber());
        assert.ok(genesisTs > 0);
    })

    it("Should verify that XEN Crypto has initial Global Rank === 1", async () => {
        const expectedInitialGlobalRank = 1;
        assert.ok(await token.globalRank().then(_ => _.toNumber()) === expectedInitialGlobalRank)
    })

    it("Should reject bulkClaimRank transaction with incorrect count OR term", async () => {
        assert.rejects(() => minter.bulkClaimRank(0, term, { from: accounts[0] }));
        assert.rejects(() => minter.bulkClaimRank(count, 0, { from: accounts[0] }));
    })

    it("Should perform bulkClaimRank operation", async () => {
        const res = await minter.bulkClaimRank(count, term, { from: accounts[0] });
        assert.ok(res.receipt.rawLogs.length === count + 1);
        console.log('      gas used', res.receipt.gasUsed.toLocaleString());
        res.receipt.rawLogs.slice(0, count).forEach(log => {
            virtualMinters.push(log.topics[1].replace('000000000000000000000000', ''))
        })
        tokenId = res.receipt.rawLogs[count]?.topics[3];
        assert.ok(virtualMinters.length === count);
    })

    it("Should verify that XEN Crypto has increased Global Rank by the number of virtual minters", async () => {
        assert.ok(await token.activeMinters().then(_ => _.toNumber()) === count);
    })

   it("Should generate SVG", async () => {
        console.log(await minter.genSVG(1));
    })

    it("Should verify that mint initiator possesses NFT by its tokenId", async () => {
        assert.ok(await minter.ownerOf(tokenId) === accounts[0]);
        assert.ok(await minter.balanceOf(accounts[0]).then(_ => _.toNumber()) === 1);
        console.log(await minter.tokenURI(tokenId));
        //console.log(await minter.asString(tokenId));
    })

    it("Should be able to return minters", async () => {
        assert.ok(await minter.minterInfo(tokenId).then(_ => _.toNumber()) === count)
    })

    it("Should perform bulkClaimMintReward operation for eligible NFT owner", async () => {
        await timeMachine.advanceTime(term * 24 * 3600 + 3600);
        await timeMachine.advanceBlock();
        await assert.rejects(() => minter.bulkClaimMintReward(tokenId, accounts[1], { from: accounts[1] }));
        const res = await minter.bulkClaimMintReward(tokenId, accounts[0], { from: accounts[0] });
        console.log('      gas used', res.receipt.gasUsed.toLocaleString());
        assert.ok(await token.activeMinters().then(_ => _.toNumber()) === 0);
        assert.ok(await token.balanceOf(accounts[0]).then(_ => '0x' + _.toString('hex')).then(BigInt) > 0n);
    })

    it("Should verify that post-mint NFT has been destroyed and cannot be reused", async () => {
        await assert.rejects(() => minter.ownerOf(tokenId));
        assert.ok(await minter.balanceOf(accounts[0]).then(_ => _.toNumber()) === 0);
    })

    it("Should perform another bulkClaimRank operation", async () => {
        const newVirtualMinters = [];
        const res = await minter.bulkClaimRank(count, term + 20, { from: accounts[1] });
        assert.ok(res.receipt.rawLogs.length === count + 1);
        console.log('      gas used', res.receipt.gasUsed.toLocaleString());
        res.receipt.rawLogs.slice(0, count).forEach(log => {
            newVirtualMinters.push(log.topics[1].replace('000000000000000000000000', ''))
        })
        tokenId = res.receipt.rawLogs[count]?.topics[3];
        assert.ok(newVirtualMinters.length === count);
        for (let i = 0; i < count; i++) {
            assert.ok(virtualMinters[i] !== newVirtualMinters[i]);
        }
        assert(BigInt(tokenId) === 2n)
    })

    it("NFT non-owner should NOT be able to transfer NFT ownership to another account", async () => {
        await assert.rejects(() => minter.transferFrom(accounts[0], accounts[1], tokenId, { from: accounts[1] }));
        await assert.rejects(() => minter.transferFrom(accounts[1], accounts[0], tokenId, { from: accounts[0] }));
    })

    it("NFT owner should be able to transfer NFT ownership to another account", async () => {
        await assert.doesNotReject(() => minter.transferFrom(accounts[1], accounts[0], tokenId, { from: accounts[1] }));
        assert.ok(await minter.ownerOf(tokenId, { from: accounts[0] }) === accounts[0]);
    })

    it("Should perform bulkClaimMintReward operation for (new) eligible NFT owner", async () => {
        await timeMachine.advanceTime((term + 20) * 24 * 3600 + 3600);
        await timeMachine.advanceBlock();
        await assert.rejects(() => minter.bulkClaimMintReward(tokenId, accounts[3], { from: accounts[1] }));
        await assert.rejects(() => minter.bulkClaimMintReward(tokenId + 1, accounts[3], { from: accounts[0] }));
        const res = await minter.bulkClaimMintReward(tokenId, accounts[3], { from: accounts[0] });
        console.log('      gas used', res.receipt.gasUsed.toLocaleString());
        assert.ok(await token.activeMinters().then(_ => _.toNumber()) === 0);
        assert.ok(await token.balanceOf(accounts[3]).then(_ => '0x' + _.toString('hex')).then(BigInt) > 0n);
    })

})
