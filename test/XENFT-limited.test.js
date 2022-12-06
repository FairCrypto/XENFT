// SPDX-License-Identifier: MIT

const assert = require('assert');
const timeMachine = require('ganache-time-traveler');
const {toBigInt} = require("../src/utils");

const XENCrypto = artifacts.require("XENCrypto");
const XENFT = artifacts.require("XENFT");
const TestBulkMinter = artifacts.require("TestBulkMinter");

const { burnRates, rareLimits, Series } = require('../config/specialNFTs.test.js');

require('dotenv').config();

const extraPrint = process.env.EXTRA_PRINT;

const assertAttribute = (attributes = []) => (name, value) => {
    const attr = attributes.find(a => a.trait_type === name);
    assert.ok(attr);
    if (value) {
        assert.ok(attr.value === value);
    }
}

contract("XENFT --- Limited Edition", async accounts => {

    let token;
    let xeNFT;
    let bulkMinter;
    let xenCryptoAddress;
    let virtualMinters = [];
    let tokenId;
    let burning;
    let xenBalance;
    const term = 10;
    // const term2 = 600;
    const countLimited = 100;
    // const countRegular = 90;
    const ether = 10n ** 18n;
    const expectedXENBalance = 173_502_408n * ether;

    before(async () => {
        try {
            token = await XENCrypto.deployed();
            xeNFT = await XENFT.deployed();
            bulkMinter = await TestBulkMinter.deployed();
            xenCryptoAddress = token.address;
        } catch (e) {
            console.error(e)
        }
    });

    it("Should obtain initial XEN balance via regular bulk minting", async () => {
        const c0 = 100;
        const t0days = 100;
        await assert.doesNotReject(() => xeNFT.bulkClaimRank(c0, t0days, { from: accounts[1] }));
        const tokens = await xeNFT.ownedTokens({ from: accounts[1] });
        assert.ok(tokens.length === 1);
        await timeMachine.advanceTime(t0days * 24 * 3600 + 3600);
        await timeMachine.advanceBlock();
        await assert.doesNotReject(() => xeNFT.bulkClaimMintReward(tokens[0], accounts[1], { from: accounts[1] }));
    });

    it("XEN Crypto user shall have positive XEN balance post claimMintReward", async () => {
        xenBalance = await token.balanceOf(accounts[1], { from: accounts[1] }).then(toBigInt);
        assert.ok(xenBalance === expectedXENBalance);
    });

    it("Should reject claiming Rare XENFT if XEN is not approved", async () => {
        await assert.rejects(
            () => xeNFT.bulkClaimRankLimited(countLimited, term, burning, { from: accounts[1] }),
            'XENFT: not enough XEN balance approved for burn'
        );
    });

    it("Should reject claiming Rare XENFT if not enough XEN is available", async () => {
        const badAmount = (burnRates[Series.LIMITED] - 1n) * ether;
        await assert.doesNotReject(() => token.transfer(accounts[2], expectedXENBalance - badAmount, { from: accounts[1] }));
        await assert.doesNotReject(() => token.approve(xeNFT.address, badAmount, { from: accounts[1] }));
        await assert.rejects(
            () => xeNFT.bulkClaimRankLimited(countLimited, term, badAmount, { from: accounts[1] }),
            'XENFT: not enough burn amount'
        );
    });

    it("Should be able to claim a Xunicorn XENFT", async () => {
        burning = (burnRates[Series.XUNICORN]) * ether;
        const badAmount = (burnRates[Series.LIMITED] - 1n) * ether;
        await assert.doesNotReject(() => token.transfer(accounts[1], expectedXENBalance - badAmount, { from: accounts[2] }));
        await token.approve(xeNFT.address, burning, { from: accounts[1] });
        const res = await xeNFT.bulkClaimRankLimited(countLimited, term, burning, { from: accounts[1] });

        assert.ok(res.receipt.rawLogs.length === countLimited + 4);
        extraPrint && console.log('      gas used', res.receipt.gasUsed.toLocaleString());
        res.receipt.rawLogs.slice(0, countLimited).forEach(log => {
            virtualMinters.push(log.topics[1].replace('000000000000000000000000', ''))
        })
        tokenId = BigInt(res.receipt.rawLogs[countLimited + 2]?.topics[3]);
        extraPrint && console.log('      tokenId', tokenId);
        assert.ok(await xeNFT.specialSeriesCounters(Series.XUNICORN).then(_ => _.toNumber()) === 2);
        assert.ok(await xeNFT.specialSeriesCounters(Series.EXOTIC).then(_ => _.toNumber()) === rareLimits[Series.XUNICORN] + 1);
        assert.ok(tokenId === BigInt(1n));
        assert.ok(virtualMinters.length === countLimited);
    });

    it("Should be allowed to claim another Xunicorn XENFT (within limit)", async () => {
        burning = (burnRates[Series.XUNICORN]) * ether;
        await assert.doesNotReject(() => token.approve(xeNFT.address, burning, { from: accounts[1] }));
        await assert.doesNotReject(
            () => xeNFT.bulkClaimRankLimited(countLimited, term, burning, { from: accounts[1] })
        );
    });

    it("Should be rejected to claim another Xunicorn XENFT (over limit)", async () => {
        burning = (burnRates[Series.XUNICORN]) * ether;
        await assert.doesNotReject(() => token.approve(xeNFT.address, burning, { from: accounts[1] }));
        await assert.rejects(
            () => xeNFT.bulkClaimRankLimited(countLimited, term, burning, { from: accounts[1] }),
            'XENFT: series sold out');
    });

    it("XEN Crypto user balance shall be reduced by amount of XEN burned", async () => {
        const newXenBalance = await token.balanceOf(accounts[1], { from: accounts[1] }).then(toBigInt);
        assert.ok(newXenBalance === xenBalance - burning * 2n);
    });

    it("Should verify that mint initiator possesses NFT by its tokenId", async () => {
        assert.ok(await xeNFT.ownerOf(tokenId) === accounts[1]);
        assert.ok(await xeNFT.balanceOf(accounts[1]).then(_ => _.toNumber()) === 3);
        const ownedTokens = await xeNFT.ownedTokens({ from: accounts[1] });
        assert.ok(ownedTokens.length === 3);
        assert.ok(BigInt(ownedTokens[1].toNumber()) === tokenId);
    });

    it("Should be able to return tokenURI as base-64 encoded data URL", async () => {
        const encodedStr = await xeNFT.tokenURI(tokenId)
        assert.ok(encodedStr.startsWith('data:application/json;base64,'));
        const base64str = encodedStr.replace('data:application/json;base64,', '');
        const decodedStr = Buffer.from(base64str, 'base64').toString('utf8');
        extraPrint === '3' && console.log(decodedStr)
        const metadata = JSON.parse(decodedStr.replace(/\n/, ''));
        assert.ok('name' in metadata);
        assert.ok('description' in metadata);
        assert.ok('image' in metadata);
        assert.ok('attributes' in metadata);
        assert.ok(Array.isArray(metadata.attributes));
        assertAttribute(metadata.attributes)('Class', 'Apex');
        assertAttribute(metadata.attributes)('Series', 'Xunicorn'.padEnd(10, ' '));
        assertAttribute(metadata.attributes)('VMUs', countLimited.toString());
        assertAttribute(metadata.attributes)('Term', term.toString());
        assertAttribute(metadata.attributes)('Maturity Year');
        assertAttribute(metadata.attributes)('Maturity Month');
        assertAttribute(metadata.attributes)('Maturity DateTime');
        assertAttribute(metadata.attributes)('AMP');
        assertAttribute(metadata.attributes)('EAA (%)');
        assertAttribute(metadata.attributes)('XEN Burned');
        assert.ok(metadata.image.startsWith('data:image/svg+xml;base64,'));
        const imageBase64 = metadata.image.replace('data:image/svg+xml;base64,', '');
        const decodedImage = Buffer.from(imageBase64, 'base64').toString();
        assert.ok(decodedImage.startsWith('<svg'));
        assert.ok(decodedImage.endsWith('</svg>'));
        extraPrint === '2' && console.log(decodedImage);
    });

    it("Should be able to claim Exotic XENFT", async () => {
        virtualMinters = []
        burning = (burnRates[Series.EXOTIC] + 0n) * ether;
        await token.approve(xeNFT.address, burning, { from: accounts[1] });
        const res = await xeNFT.bulkClaimRankLimited(countLimited, term, burning, { from: accounts[1] });
        assert.ok(res.receipt.rawLogs.length === countLimited + 4);
        extraPrint && console.log('      gas used', res.receipt.gasUsed.toLocaleString());
        res.receipt.rawLogs.slice(0, countLimited).forEach(log => {
            virtualMinters.push(log.topics[1].replace('000000000000000000000000', ''))
        })
        tokenId = BigInt(res.receipt.rawLogs[countLimited + 2]?.topics[3]);
        // extraPrint && console.log('      tokenId', tokenId);
        assert.ok(await xeNFT.specialSeriesCounters(Series.EXOTIC).then(_ => _.toNumber()) === rareLimits[Series.XUNICORN] + 2);
        assert.ok(tokenId === BigInt(rareLimits[Series.XUNICORN]) + 1n);
        assert.ok(virtualMinters.length === countLimited);
    });

    it("Should be able to claim Legendary XENFT", async () => {
        virtualMinters = []
        burning = (burnRates[Series.LEGENDARY] + 0n) * ether;
        await token.approve(xeNFT.address, burning, { from: accounts[1] });
        const res = await xeNFT.bulkClaimRankLimited(countLimited, term, burning, { from: accounts[1] });
        assert.ok(res.receipt.rawLogs.length === countLimited + 4);
        extraPrint && console.log('      gas used', res.receipt.gasUsed.toLocaleString());
        res.receipt.rawLogs.slice(0, countLimited).forEach(log => {
            virtualMinters.push(log.topics[1].replace('000000000000000000000000', ''))
        })
        tokenId = BigInt(res.receipt.rawLogs[countLimited + 2]?.topics[3]);
        // extraPrint && console.log('      tokenId', tokenId);
        assert.ok(await xeNFT.specialSeriesCounters(Series.LEGENDARY).then(_ => _.toNumber()) === rareLimits[Series.EXOTIC] + 2);
        assert.ok(tokenId === BigInt(rareLimits[Series.EXOTIC]) + 1n);
        assert.ok(virtualMinters.length === countLimited);
    });

    it("Should be able to claim Epic XENFT", async () => {
        virtualMinters = []
        burning = (burnRates[Series.EPIC] + 0n) * ether;
        await token.approve(xeNFT.address, burning, { from: accounts[1] });
        const res = await xeNFT.bulkClaimRankLimited(countLimited, term, burning, { from: accounts[1] });
        assert.ok(res.receipt.rawLogs.length === countLimited + 4);
        extraPrint && console.log('      gas used', res.receipt.gasUsed.toLocaleString());
        res.receipt.rawLogs.slice(0, countLimited).forEach(log => {
            virtualMinters.push(log.topics[1].replace('000000000000000000000000', ''))
        })
        tokenId = BigInt(res.receipt.rawLogs[countLimited + 2]?.topics[3]);
        // extraPrint && console.log('      tokenId', tokenId);
        assert.ok(await xeNFT.specialSeriesCounters(Series.EPIC).then(_ => _.toNumber()) === rareLimits[Series.LEGENDARY] + 2);
        assert.ok(tokenId === BigInt(rareLimits[Series.LEGENDARY]) + 1n);
        assert.ok(virtualMinters.length === countLimited);
    });

    it("Should be able to claim Rare XENFT", async () => {
        virtualMinters = []
        burning = (burnRates[Series.RARE] + 0n) * ether;
        await token.approve(xeNFT.address, burning, { from: accounts[1] });
        const res = await xeNFT.bulkClaimRankLimited(countLimited, term, burning, { from: accounts[1] });
        assert.ok(res.receipt.rawLogs.length === countLimited + 4);
        extraPrint && console.log('      gas used', res.receipt.gasUsed.toLocaleString());
        res.receipt.rawLogs.slice(0, countLimited).forEach(log => {
            virtualMinters.push(log.topics[1].replace('000000000000000000000000', ''))
        })
        tokenId = BigInt(res.receipt.rawLogs[countLimited + 2]?.topics[3]);
        // extraPrint && console.log('      tokenId', tokenId);
        assert.ok(await xeNFT.specialSeriesCounters(Series.RARE).then(_ => _.toNumber()) === rareLimits[Series.EPIC] + 2);
        assert.ok(tokenId === BigInt(rareLimits[Series.EPIC]) + 1n);
        assert.ok(virtualMinters.length === countLimited);
    });

    it("Should be able to claim Limited XENFT", async () => {
        virtualMinters = []
        burning = (burnRates[Series.LIMITED] + 111n) * ether;
        await token.approve(xeNFT.address, burning, { from: accounts[1] });
        const res = await xeNFT.bulkClaimRankLimited(countLimited, term, burning, { from: accounts[1] });
        assert.ok(res.receipt.rawLogs.length === countLimited + 4);
        extraPrint && console.log('      gas used', res.receipt.gasUsed.toLocaleString());
        res.receipt.rawLogs.slice(0, countLimited).forEach(log => {
            virtualMinters.push(log.topics[1].replace('000000000000000000000000', ''))
        })
        tokenId = BigInt(res.receipt.rawLogs[countLimited + 2]?.topics[3]);
        // extraPrint && console.log('      tokenId', tokenId);
        assert.ok(await xeNFT.specialSeriesCounters(Series.LIMITED).then(_ => _.toNumber()) === 0);
        assert.ok(tokenId === 10_002n);
        assert.ok(virtualMinters.length === countLimited);
    });

    it("Should verify that mint initiator possesses NFT by its tokenId", async () => {
        assert.ok(await xeNFT.ownerOf(tokenId) === accounts[1]);
        assert.ok(await xeNFT.balanceOf(accounts[1]).then(_ => _.toNumber()) === 8);
        const ownedTokens = await xeNFT.ownedTokens({ from: accounts[1] });
        assert.ok(ownedTokens.length === 8);
        assert.ok(BigInt(ownedTokens[ownedTokens.length - 1].toNumber()) === tokenId);
    });

    it("Should be able to return tokenURI as base-64 encoded data URL 2", async () => {
        const encodedStr = await xeNFT.tokenURI(tokenId)
        assert.ok(encodedStr.startsWith('data:application/json;base64,'));
        const base64str = encodedStr.replace('data:application/json;base64,', '');
        const decodedStr = Buffer.from(base64str, 'base64').toString('utf8');
        extraPrint === '3' && console.log(decodedStr)
        const metadata = JSON.parse(decodedStr.replace(/\n/, ''));
        assert.ok('name' in metadata);
        assert.ok('description' in metadata);
        assert.ok('image' in metadata);
        assert.ok('attributes' in metadata);
        assert.ok(Array.isArray(metadata.attributes));
        assertAttribute(metadata.attributes)('Class', 'Limited');
        assert.ok(metadata.image.startsWith('data:image/svg+xml;base64,'));
        const imageBase64 = metadata.image.replace('data:image/svg+xml;base64,', '');
        const decodedImage = Buffer.from(imageBase64, 'base64').toString();
        assert.ok(decodedImage.startsWith('<svg'));
        assert.ok(decodedImage.endsWith('</svg>'));
        extraPrint === '2' && console.log(decodedImage);
    });

    it("Should allow to mint a Collector NFT from a Smart Contract", async () => {
        await assert.doesNotReject(() => bulkMinter.testBulkMintCollector({ from: accounts[2] }));
    });

    it("Should allow to mint a Limited NFT from a Smart Contract", async () => {
        const burning = burnRates[Series.LIMITED] * ether;
        await assert.doesNotReject(() => token.transfer(bulkMinter.address, burning, { from: accounts[1] }));
        await assert.doesNotReject(() => bulkMinter.approveXen(burning, { from: accounts[2] }));
        await assert.doesNotReject(() => bulkMinter.testBulkMintLimited({ from: accounts[2] }));
    });

    it("Should reject to mint a Rare NFT from a Smart Contract", async () => {
        await assert.rejects(
            () => bulkMinter.testBulkMintRare({ from: accounts[2] }),
            'XENFT: only EOA allowed for this category');
    });


    it("Should reject claiming Limited XENFT after 1 year", async () => {
        const oneYearInSeconds = 365 * 24 * 3600 + 3600;
        await timeMachine.advanceTime(oneYearInSeconds);
        await timeMachine.advanceBlock();
        await token.approve(xeNFT.address, burning, { from: accounts[1] });
        await assert.rejects(
            () => xeNFT.bulkClaimRankLimited(countLimited, term, burning, { from: accounts[1] }),
            'XENFT: limited time expired'
        );
    });

})
