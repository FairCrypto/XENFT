// SPDX-License-Identifier: MIT

const assert = require('assert');
const timeMachine = require('ganache-time-traveler');
const {toBigInt} = require("../src/utils");

const XENCrypto = artifacts.require("XENCrypto");
const XENFT = artifacts.require("XENFT");

const { burnRates, rareCounts } = require('../config/specialNFTs.js');

require('dotenv').config();

const extraPrint = process.env.EXTRA_PRINT;

// const { bn2hexStr, toBigInt, maxBigInt, etherToWei } = require('../src/utils.js')

contract("XENFT --- Limited Edition", async accounts => {

    let token;
    let xeNFT;
    let xenCryptoAddress;
    let virtualMinters = [];
    let tokenId;
    let burning;
    let xenBalance;
    const term = 10;
    const term2= 600;
    const countLimited = 100;
    // const countRegular = 90;
    const ether = 10n ** 18n;

    before(async () => {
        try {
            token = await XENCrypto.deployed();
            xeNFT = await XENFT.deployed();
            xenCryptoAddress = token.address;
        } catch (e) {
            console.error(e)
        }
    })

    it("Should obtain initial XEN balance via regular bulk minting", async () => {
        const c0 = 100;
        const t0 = 100;
        await assert.doesNotReject(() => xeNFT.bulkClaimRank(c0, t0, { from: accounts[1] }));
        const tokens = await xeNFT.ownedTokens({ from: accounts[1] });
        assert.ok(tokens.length === 1);
        await timeMachine.advanceTime(t0 * 24 * 3600 + 3600);
        await timeMachine.advanceBlock();
        await assert.doesNotReject(() => xeNFT.bulkClaimMintReward(tokens[0], accounts[1], { from: accounts[1] }));
    });

    it("XEN Crypto user shall have positive XEN balance post claimMintReward", async () => {
        xenBalance = await token.balanceOf(accounts[1], { from: accounts[1] }).then(toBigInt);
        assert.ok(xenBalance === 173_502_408n * ether);
    });

    it("Should perform bulkClaimRankLimited operation", async () => {
        burning = burnRates[3] * ether;
        await token.approve(xeNFT.address, burning, { from: accounts[1] });
        const res = await xeNFT.bulkClaimRankLimited(countLimited, term, burning, { from: accounts[1] });
        assert.ok(res.receipt.rawLogs.length === countLimited + 4);
        extraPrint && console.log('      gas used', res.receipt.gasUsed.toLocaleString());
        res.receipt.rawLogs.slice(0, countLimited).forEach(log => {
            virtualMinters.push(log.topics[1].replace('000000000000000000000000', ''))
        })
        tokenId = BigInt(res.receipt.rawLogs[countLimited + 2]?.topics[3]);
        // extraPrint && console.log('      tokenId', tokenId);
        assert.ok(await xeNFT.rareSeriesCounters(3).then(_ => _.toNumber()) === rareCounts[2] + 1 + 1);
        assert.ok(await xeNFT.rareSeriesCounters(4).then(_ => _.toNumber()) === rareCounts[3] + 1);
        assert.ok(tokenId === BigInt(rareCounts[2]) + 1n);
        assert.ok(virtualMinters.length === countLimited);
    })

    it("XEN Crypto user balance shall be reduced by amount of XEN burned", async () => {
        const newXenBalance = await token.balanceOf(accounts[1], { from: accounts[1] }).then(toBigInt);
        assert.ok(newXenBalance === xenBalance - burning);
    });

    it("Should verify that mint initiator possesses NFT by its tokenId", async () => {
        assert.ok(await xeNFT.ownerOf(tokenId) === accounts[1]);
        assert.ok(await xeNFT.balanceOf(accounts[1]).then(_ => _.toNumber()) === 2);
        const ownedTokens = await xeNFT.ownedTokens({ from: accounts[1] });
        assert.ok(ownedTokens.length === 2);
        assert.ok(BigInt(ownedTokens[1].toNumber()) === tokenId);
    })

    it("Should be able to return tokenURI as base-64 encoded data URL", async () => {
        const encodedStr = await xeNFT.tokenURI(tokenId)
        assert.ok(encodedStr.startsWith('data:application/json;base64,'));
        const base64str = encodedStr.replace('data:application/json;base64,', '');
        const decodedStr = Buffer.from(base64str, 'base64').toString('utf8');
        extraPrint === '2' && console.log(decodedStr)
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
        extraPrint === '2' && console.log(decodedImage);
    })

    it("Should perform bulkClaimRankLimited operation 2", async () => {
        virtualMinters = []
        burning = burnRates[5] * ether;
        await token.approve(xeNFT.address, burning, { from: accounts[1] });
        const res = await xeNFT.bulkClaimRankLimited(countLimited, term, burning, { from: accounts[1] });
        assert.ok(res.receipt.rawLogs.length === countLimited + 4);
        extraPrint && console.log('      gas used', res.receipt.gasUsed.toLocaleString());
        res.receipt.rawLogs.slice(0, countLimited).forEach(log => {
            virtualMinters.push(log.topics[1].replace('000000000000000000000000', ''))
        })
        tokenId = BigInt(res.receipt.rawLogs[countLimited + 2]?.topics[3]);
        // extraPrint && console.log('      tokenId', tokenId);
        assert.ok(await xeNFT.rareSeriesCounters(3).then(_ => _.toNumber()) === rareCounts[2] + 1 + 1);
        assert.ok(await xeNFT.rareSeriesCounters(4).then(_ => _.toNumber()) === rareCounts[3] + 1);
        assert.ok(tokenId === 10_002n);
        assert.ok(virtualMinters.length === countLimited);
    })

    it("Should verify that mint initiator possesses NFT by its tokenId 2", async () => {
        assert.ok(await xeNFT.ownerOf(tokenId) === accounts[1]);
        assert.ok(await xeNFT.balanceOf(accounts[1]).then(_ => _.toNumber()) === 3);
        const ownedTokens = await xeNFT.ownedTokens({ from: accounts[1] });
        assert.ok(ownedTokens.length === 3);
        assert.ok(BigInt(ownedTokens[2].toNumber()) === tokenId);
    })

    it("Should be able to return tokenURI as base-64 encoded data URL 2", async () => {
        const encodedStr = await xeNFT.tokenURI(tokenId)
        assert.ok(encodedStr.startsWith('data:application/json;base64,'));
        const base64str = encodedStr.replace('data:application/json;base64,', '');
        const decodedStr = Buffer.from(base64str, 'base64').toString('utf8');
        extraPrint === '2' && console.log(decodedStr)
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
        extraPrint === '2' && console.log(decodedImage);
    })

})
