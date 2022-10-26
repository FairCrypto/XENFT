// SPDX-License-Identifier: MIT

const assert = require('assert')
require('dotenv').config()
// const truffleAssert = require('truffle-assertions')
const timeMachine = require('ganache-time-traveler');
const {toBigInt} = require("../src/utils");

const XENCrypto = artifacts.require("XENCrypto")
const XENTorrent = artifacts.require("XENTorrent")
const Quotes = artifacts.require("Quotes")

// const { bn2hexStr, toBigInt, maxBigInt, etherToWei } = require('../src/utils.js')

contract("XEN Torrent", async accounts => {

    let token;
    let minter;
    let quotes;
    let xenCryptoAddress;
    let virtualMinters = [];
    let genesisTs = 0;
    let tokenId;
    const term = 10;
    const countLimited = 100;
    const countRegular = 90;


    before(async () => {
        try {
            token = await XENCrypto.deployed();
            minter = await XENTorrent.deployed();
            quotes = await Quotes.deployed();
            xenCryptoAddress = token.address;
        } catch (e) {
            console.error(e)
        }
    })

    it("Should extract quotes by id", async () => {
        const QUOTES = await quotes.QUOTES();
        console.log(await quotes.getQuote(QUOTES, 0));
        console.log(await quotes.getQuote(QUOTES, 11));
        console.log(await quotes.getQuote(QUOTES, 12));
        console.log(await quotes.getQuote(QUOTES, 13));
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

    it("Should test mintInfo encoding", async () => {
        const mintInfo = await minter.encodeMintInfo(1,2,3,4,5,true,false).then(toBigInt);
        // console.log(BigInt(mintInfo).toString(2))
        const { term, maturityTs, rank, amp, eaa, limited, redeemed } =  await minter.decodeMintInfo(mintInfo);
        assert.ok(term.toNumber() === 1);
        assert.ok(maturityTs.toNumber() === 2);
        assert.ok(rank.toNumber() === 3);
        assert.ok(amp.toNumber() === 4);
        assert.ok(eaa.toNumber() === 5);
        assert.ok(limited === true);
        assert.ok(redeemed === false);
    })

    it("Should reject bulkClaimRank transaction with incorrect count OR term", async () => {
        assert.rejects(() => minter.bulkClaimRank(0, term, { from: accounts[0] }));
        assert.rejects(() => minter.bulkClaimRank(countLimited, 0, { from: accounts[0] }));
    })

    it("Should perform bulkClaimRank operation", async () => {
        const res = await minter.bulkClaimRank(countLimited, term, { from: accounts[0] });
        assert.ok(res.receipt.rawLogs.length === countLimited + 1);
        console.log('      gas used', res.receipt.gasUsed.toLocaleString());
        res.receipt.rawLogs.slice(0, countLimited).forEach(log => {
            virtualMinters.push(log.topics[1].replace('000000000000000000000000', ''))
        })
        tokenId = res.receipt.rawLogs[countLimited]?.topics[3];
        assert.ok(virtualMinters.length === countLimited);
    })

    it("Should verify that XEN Crypto has increased Global Rank by the number of virtual minters", async () => {
        assert.ok(await token.activeMinters().then(_ => _.toNumber()) === countLimited);
    })

    it("Should generate SVG", async () => {
        //console.log(await minter.genSVG(1));
    })

    it("Should verify that mint initiator possesses NFT by its tokenId", async () => {
        assert.ok(await minter.ownerOf(tokenId) === accounts[0]);
        assert.ok(await minter.balanceOf(accounts[0]).then(_ => _.toNumber()) === 1);
    })

    it("Should be able to return tokenURI as base-64 encoded data URL", async () => {
        const encodedStr = await minter.tokenURI(tokenId)
        assert.ok(encodedStr.startsWith('data:application/json;base64,'));
        const base64str = encodedStr.replace('data:application/json;base64,', '');
        const decodedStr = Buffer.from(base64str, 'base64').toString('utf8');
        console.log(decodedStr)
        const metadata = JSON.parse(decodedStr.replace(/\n/, ''));
        assert.ok('name' in metadata);
        assert.ok('description' in metadata);
        assert.ok('image' in metadata);
        assert.ok('attributes' in metadata);
        assert.ok(Array.isArray(metadata.attributes));
        assert.ok(metadata.image.startsWith('data:image/svg+xml;base64,'));
        const imageBase64 = metadata.image.replace('data:image/svg+xml;base64,', '');
        const decodedImage = Buffer.from(imageBase64, 'base64').toString();
        assert.ok(decodedImage.startsWith('<svg'));
        assert.ok(decodedImage.endsWith('</svg>'));
    })

    it("Should be able to return minters", async () => {
        assert.ok(await minter.vmuCount(tokenId).then(_ => _.toNumber()) === countLimited)
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
        // await assert.rejects(() => minter.ownerOf(tokenId));
        assert.ok(await minter.balanceOf(accounts[0]).then(_ => _.toNumber()) === 1);
    })

    it("Should generate SVG of a redeemed NFT", async () => {
        //console.log(await minter.genSVG(1));
    })

    it("Should perform another bulkClaimRank operation with regular count", async () => {
        const newVirtualMinters = [];

        for await(const i of Array(Math.floor(Math.random() * 100)).fill(null)) {
            await timeMachine.advanceBlock();
        }
        const res = await minter.bulkClaimRank(countRegular, term + 20, { from: accounts[1] });
        assert.ok(res.receipt.rawLogs.length === countRegular + 1);
        console.log('      gas used', res.receipt.gasUsed.toLocaleString());
        res.receipt.rawLogs.slice(0, countRegular).forEach(log => {
            newVirtualMinters.push(log.topics[1].replace('000000000000000000000000', ''))
        })
        tokenId = res.receipt.rawLogs[countRegular]?.topics[3];
        assert.ok(newVirtualMinters.length === countRegular);
        for (let i = 0; i < countRegular; i++) {
            assert.ok(virtualMinters[i] !== newVirtualMinters[i]);
        }
        assert(BigInt(tokenId) === 2n)
    })

    it("Should generate SVG of a regular NFT", async () => {
        //console.log(await minter.genSVG(2));
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
