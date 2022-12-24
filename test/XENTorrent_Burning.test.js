// SPDX-License-Identifier: MIT

const assert = require('assert');
const timeMachine = require('ganache-time-traveler');
const truffleAssert = require('truffle-assertions');

const XENCrypto = artifacts.require("XENCrypto");
const XENTorrent = artifacts.require("XENTorrent");
const Burner = artifacts.require("Burner");
const BadBurner = artifacts.require("BadBurner");
const RevertingBurner = artifacts.require("RevertingBurner");

const { startBlock } = require('../config/genesisParams.test');

require('dotenv').config();

// const extraPrint = process.env.EXTRA_PRINT;

contract("XENFTs --- Burn interface", async accounts => {

    let token;
    let xeNFT;
    let burner;
    let badBurner;
    let revertingBurner;
    let ownedTokens;
    let xenBalance;
    let currentBlock;

    before(async () => {
        try {
            token = await XENCrypto.deployed();
            xeNFT = await XENTorrent.deployed();

            burner = await Burner.new(xeNFT.address);
            badBurner = await BadBurner.new(xeNFT.address);
            revertingBurner = await RevertingBurner.new(xeNFT.address);

            currentBlock = await web3.eth.getBlockNumber();
        } catch (e) {
            console.error(e)
        }
    });

    it("Should reject bulkClaimRank transaction submitted before start block", async () => {
        assert.ok(currentBlock <= startBlock);
        assert.rejects(() => xeNFT.bulkClaimRank(1, 1, { from: accounts[0] }), 'XENFT: Not active yet');
        const blockDelta = startBlock - currentBlock + 1;
        const blocks = Array(blockDelta).fill(null);
        for await (const _ of blocks) {
            await timeMachine.advanceBlock();
        }
        currentBlock = await web3.eth.getBlockNumber();
        assert.ok(currentBlock > startBlock);
    });

    it("Should obtain some XENFTs via regular bulk minting", async () => {
        await assert.doesNotReject(() => xeNFT.bulkClaimRank(1, 100, { from: accounts[1] }));
        await assert.doesNotReject(() => xeNFT.bulkClaimRank(1, 100, { from: accounts[1] }));
        await assert.doesNotReject(() => xeNFT.bulkClaimRank(1, 100, { from: accounts[1] }));
        await assert.doesNotReject(() => xeNFT.bulkClaimRank(1, 100, { from: accounts[1] }));
        //await timeMachine.advanceTime(24 * 3600 + 3600);
        //await timeMachine.advanceBlock();
        xenBalance = await xeNFT.balanceOf(accounts[1], {from: accounts[1]}).then(_ => _.toNumber());
        assert.ok(xenBalance === 4);
        ownedTokens = await xeNFT.ownedTokens({from: accounts[1]}).then(tokenIds => tokenIds.map(_ => _.toNumber()));
        // console.log(ownedTokens);
        assert.ok(ownedTokens.length === 4);
    });

    it('Should not allow calling Burn function directly from EOA', async () => {
        await truffleAssert.fails(xeNFT.burn(accounts[1], 1, {from: accounts[1]}));
    })

    it('Should not allow calling Burn function for tokenId which is not owned', async () => {
        await truffleAssert.fails(
            burner.exchangeTokens(0, {from: accounts[1]}),
            'XENFT burn: illegal tokenId'
        )
    })

    it('Should not allow calling Burn function for tokenId which is owned but not approved', async () => {
        await truffleAssert.fails(
            burner.exchangeTokens(ownedTokens[0], {from: accounts[1]}),
            'XENFT burn: not an approved operator'
        )
    })

    it('Should not allow calling Burn function for tokenId which is approved but not owned', async () => {
       await truffleAssert.fails(
           xeNFT.approve(burner.address, 1111, {from: accounts[1]}),
           'ERC721: invalid token ID'
        )
    })

    it('Should allow calling Burn function from supported contract after prior approval', async () => {
        await assert.doesNotReject(() => xeNFT.approve(burner.address, ownedTokens[0], {from: accounts[1]}));
        await assert.doesNotReject(burner.exchangeTokens(ownedTokens[0], {from: accounts[1]}));
    })

    it('Post burn, balances for XEN and other contract should show correct numbers', async () => {
        const _xenBalance = await xeNFT.balanceOf(accounts[1], {from: accounts[1]}).then(_ => _.toNumber())
        const otherBalance = await burner.balanceOf(accounts[1], {from: accounts[1]}).then(_ => _.toNumber())
        assert.ok(_xenBalance === xenBalance - 1);
        assert.ok(otherBalance === ownedTokens[0]);
    })

    it('Should NOT allow calling Burn function from reentrancy-exploiting contract', async () => {
        await assert.doesNotReject(() => xeNFT.approve(badBurner.address, ownedTokens[1], {from: accounts[1]}));
        await truffleAssert.fails(
            badBurner.exchangeTokens(ownedTokens[1], {from: accounts[1]}),
            'XENFT: Reentrancy detected'
        );
        const _xenBalance = await xeNFT.balanceOf(accounts[1], {from: accounts[1]}).then(_ => _.toNumber())
        assert.ok(_xenBalance === xenBalance - 1);
    })

    it('Should fail transaction and revert state if an error happened in a Burner contract', async () => {
        await assert.doesNotReject(() => xeNFT.approve(revertingBurner.address, ownedTokens[1], {from: accounts[1]}));
        await truffleAssert.fails(revertingBurner.exchangeTokens(ownedTokens[1], {from: accounts[1]}));
        const _xenBalance = await xeNFT.balanceOf(accounts[1], {from: accounts[1]}).then(_ => _.toNumber())
        assert.ok(_xenBalance === xenBalance - 1);
    })

})
