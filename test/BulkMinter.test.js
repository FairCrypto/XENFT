// SPDX-License-Identifier: MIT

const assert = require('assert')
require('dotenv').config()
// const truffleAssert = require('truffle-assertions')
const timeMachine = require('ganache-time-traveler');

const XENCrypto = artifacts.require("XENCrypto")
// test 'fake' contracts with pre-set GlobalRanks
const XENMinter = artifacts.require("XENMinter")

// const { bn2hexStr, toBigInt, maxBigInt, etherToWei } = require('../src/utils.js')

contract("XEN Minter", async accounts => {

    let token;
    let minter;
    let xenCryptoAddress;
    let virtualMinters = [];
    let genesisTs = 0;
    const term = 10;
    const count = 64;
    const salt = '0x123123';

    before(async () => {
        try {
            token = await XENCrypto.deployed();
            minter = await XENMinter.deployed();
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

    it("Should perform bulkClaimRank operation", async () => {
        const res = await minter.bulkClaimRank(count, term, salt, { from: accounts[0] });
        assert.ok(res.receipt.rawLogs.length === count);
        console.log('gas used', res.receipt.gasUsed);
        res.receipt.rawLogs.forEach(log => {
            virtualMinters.push(log.topics[1].replace('000000000000000000000000', ''))
        })
        console.log(virtualMinters.length)
        //console.log(res.attempts.toNumber(), res.total.toNumber())
        //await timeMachine.advanceBlock();
    })

    it("Should verify that XEN Crypto has increased Global Rank by the number of virtual minters", async () => {
        const expectedNewGlobalRank = 1;
        //await minter.callClaimRank(10);
        assert.ok(await token.activeMinters().then(_ => _.toNumber()) === count)

    })

    it("Should be able to return minters", async () => {
        console.log(await minter.map(accounts[0], salt).then(_ => _.toNumber()) === count)
    })

    it("Test", async () => {
        // console.log(await minter.callClaimMintReward('0x0000000000000000000000000000000000000000'));
    })

    it("Should perform bulkClaimMintReward operation", async () => {
        await timeMachine.advanceTime(term * 24 * 3600 + 3600);
        await timeMachine.advanceBlock();
        const res = await minter.bulkClaimMintReward(count, accounts[0], salt, { from: accounts[0] });
        //console.log(res.attempts.toNumber(), res.total.toNumber())
        //console.log(res.receipt);
        //res.receipt.rawLogs.forEach(log => {
        //    virtualMinters.push(log.topics[1].replace('000000000000000000000000', ''))
        //})
        ///console.log(virtualMinters)
        console.log('gas used', res.receipt.gasUsed);
        assert.ok(await token.activeMinters().then(_ => _.toNumber()) === 0);
        assert.ok(await token.balanceOf(accounts[0]).then(_ => '0x' + _.toString('hex')).then(BigInt) > 0n);
        //console.log(await token.balanceOf(virtualMinters[0]).then(_ => '0x' + _.toString('hex')).then(BigInt))
        //console.log(await token.balanceOf(virtualMinters[1]).then(_ => '0x' + _.toString('hex')).then(BigInt))
        //await timeMachine.advanceBlock();
    })

})
