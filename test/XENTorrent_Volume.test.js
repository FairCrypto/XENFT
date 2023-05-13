// SPDX-License-Identifier: MIT

const assert = require('assert');
const { Contract } = require('ethers');
const { Web3Provider } = require('@ethersproject/providers');
const timeMachine = require('ganache-time-traveler');
const {toBigInt} = require("../src/utils");

const XENCrypto = artifacts.require("XENCrypto");
const XENTorrent = artifacts.require("XENTorrent");

const { burnRates, rareLimits, Series, startBlock } = require('../config/genesisParams.test');

require('dotenv').config();

const extraPrint = process.env.EXTRA_PRINT;

const ether = 10n ** 18n;

const assertAttribute = (attributes = []) => (name, value) => {
    const attr = attributes.find(a => a.trait_type === name);
    assert.ok(attr);
    if (value) {
        assert.ok(attr.value === value);
    }
}

contract("XENFTs --- Collector category", async accounts => {

    let token;
    let xeNFT;
    let xenCryptoAddress;
    let virtualMinters = [];
    let genesisTs = 0;
    let tokenId;
    let currentBlock;
    const term = 10;
    const term2= 100;
    const count = 10;
    const tokenIdRegular = 10_001n;

    before(async () => {
        try {
            token = await XENCrypto.deployed();
            xeNFT = await XENTorrent.deployed();
            currentBlock = await web3.eth.getBlockNumber();
            xenCryptoAddress = token.address;
        } catch (e) {
            console.error(e)
        }
    })

    //it("Should allow bulkClaimRank with min params", async () => {
    //    await assert.doesNotReject(() => xeNFT.bulkClaimRank(1, 1, { from: accounts[3] }));
    //});
    // ..................................................................................

    it("Should perform multiple bulkClaimRank operations", async () => {
        const count = 50;
        const term = 1;
        const gasUsed = {};
        const flights = Array(75)
            .fill(null)
            .map((_, idx) => idx);
        for await (const acc of accounts.slice(0, 1)) {
            for await (const i of flights) {
                const est = await xeNFT.bulkClaimRank.estimateGas(count, term, {from: acc}).then(toBigInt).then(Number);
                const res = await xeNFT.bulkClaimRank(count, term, {from: acc});
                process.stdout.write('.');
                if (!gasUsed[acc]) {
                    gasUsed[acc] = {}
                }
                gasUsed[acc][i + 1] = {
                    est: est.toLocaleString(),
                    act: res.receipt.gasUsed.toLocaleString(),
                    d: (res.receipt.gasUsed - est).toLocaleString()
                };
            }
            process.stdout.write('\n');
        }
        console.log(gasUsed)
    })
})
