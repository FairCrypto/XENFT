// SPDX-License-Identifier: MIT

const assert = require('assert');
const timeMachine = require('ganache-time-traveler');
const truffleAssert = require('truffle-assertions');

const XENCrypto = artifacts.require("XENCrypto");
const XENTorrent = artifacts.require("XENTorrent");
const MultiBurner = artifacts.require("MultiBurner");

const { startBlock } = require('../config/genesisParams.test');

require('dotenv').config();

// const extraPrint = process.env.EXTRA_PRINT;

contract("XENFTs --- Burn interface", async accounts => {

    let token;
    let xeNFT;
    let burner;
    let ownedTokens;
    let xenBalance;
    let currentBlock;

    before(async () => {
        try {
            token = await XENCrypto.deployed();
            xeNFT = await XENTorrent.deployed();

            burner = await MultiBurner.new(xeNFT.address);
            currentBlock = await web3.eth.getBlockNumber();
            // console.log(currentBlock)
        } catch (e) {
            console.error(e)
        }
    });

    it("Should start minting not before the startBlock", async () => {
        for await (const i of Array(startBlock - currentBlock + 1)) {
            await timeMachine.advanceBlock()
        }
    });

    it("Should obtain some XENFTs via regular bulk minting", async () => {
        await assert.doesNotReject(() => xeNFT.bulkClaimRank(1, 100, { from: accounts[1] }));
        await assert.doesNotReject(() => xeNFT.bulkClaimRank(20, 100, { from: accounts[1] }));
        await assert.doesNotReject(() => xeNFT.bulkClaimRank(75, 100, { from: accounts[1] }));
        await assert.doesNotReject(() => xeNFT.bulkClaimRank(100, 100, { from: accounts[1] }));

        xenBalance = await xeNFT.balanceOf(accounts[1], {from: accounts[1]}).then(_ => _.toNumber());
        assert.ok(xenBalance === 4);
        ownedTokens = await xeNFT.ownedTokens({from: accounts[1]}).then(tokenIds => tokenIds.map(_ => _.toNumber()));
        // console.log(ownedTokens);
        assert.ok(ownedTokens.length === 4);
    });

    it('Should allow calling Burn function from supported contract after prior approval', async () => {
        await assert.doesNotReject(() => xeNFT.approve(burner.address, ownedTokens[0], {from: accounts[1]}));
        await assert.doesNotReject(() => xeNFT.approve(burner.address, ownedTokens[1], {from: accounts[1]}));
        await assert.doesNotReject(() => xeNFT.approve(burner.address, ownedTokens[2], {from: accounts[1]}));
        await assert.doesNotReject(() => xeNFT.approve(burner.address, ownedTokens[3], {from: accounts[1]}));
        await assert.doesNotReject(() => {
            return burner.exchangeTokens(ownedTokens, {from: accounts[1]})
                .then(rec => console.log(rec.receipt.gasUsed))
        });
    })

    it('Should show zero XENFT balance post burning', async () => {
        xenBalance = await xeNFT.balanceOf(accounts[1], {from: accounts[1]}).then(_ => _.toNumber());
        assert.ok(xenBalance === 0);
        ownedTokens = await xeNFT.ownedTokens({from: accounts[1]}).then(tokenIds => tokenIds.map(_ => _.toNumber()));
        // console.log(ownedTokens);
        assert.ok(ownedTokens.length === 0);

        const newBalance = await burner.balanceOf(accounts[1], {from: accounts[1]}).then(_ => _.toNumber());
        console.log(newBalance);
        assert.ok(newBalance === 1);
    })

})
