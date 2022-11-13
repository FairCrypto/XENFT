// SPDX-License-Identifier: MIT

const assert = require('assert');
const { Contract } = require('ethers');
const { Web3Provider } = require('@ethersproject/providers');
const timeMachine = require('ganache-time-traveler');
const {toBigInt} = require("../src/utils");

const XENCrypto = artifacts.require("XENCrypto");
const XENFT = artifacts.require("XENFT");

require('dotenv').config();

const extraPrint = process.env.EXTRA_PRINT;

// const { bn2hexStr, toBigInt, maxBigInt, etherToWei } = require('../src/utils.js')

contract("XENFT --- Standard Edition", async accounts => {

    let token;
    let xeNFT;
    let xenCryptoAddress;
    let virtualMinters = [];
    let genesisTs = 0;
    let tokenId;
    const term = 10;
    const term2= 100;
    const countLimited = 10;
    const tokenIdRegular = 10_001n;
    // const countRegular = 90;


    before(async () => {
        try {
            token = await XENCrypto.deployed();
            xeNFT = await XENFT.deployed();
            xenCryptoAddress = token.address;
        } catch (e) {
            console.error(e)
        }
    })

    it("Should read XENFT symbol and name", async () => {
        assert.ok(await xeNFT.name() === 'XEN Torrent');
        assert.ok(await xeNFT.symbol() === 'XENT');
    })

    it("Should read XEN Crypto Address params", async () => {
        assert.ok(await xeNFT.xenCrypto() === xenCryptoAddress)
    })

    it("Should read XEN Crypto genesisTs", async () => {
        genesisTs = await token.genesisTs().then(_ => _.toNumber());
        assert.ok(genesisTs > 0);
    })

    it("Should verify that XEN Crypto has initial Global Rank === 1", async () => {
        const expectedInitialGlobalRank = 1;
        assert.ok(await token.globalRank().then(_ => _.toNumber()) === expectedInitialGlobalRank);
        const expectedCurrentMaxTerm = 100 * 24 * 3600;
        assert.ok(await token.getCurrentMaxTerm().then(_ => _.toNumber()) === expectedCurrentMaxTerm);
    })

    it("Should reject bulkClaimRank transaction with incorrect count OR term", async () => {
        assert.rejects(() => xeNFT.bulkClaimRank(0, term, { from: accounts[0] }));
        assert.rejects(() => xeNFT.bulkClaimRank(countLimited, 0, { from: accounts[0] }));
    })

    it("Should perform bulkClaimRank operation", async () => {
        const res = await xeNFT.bulkClaimRank(countLimited, term, { from: accounts[0] });
        assert.ok(res.receipt.rawLogs.length === countLimited + 2);
        extraPrint && console.log('      gas used', res.receipt.gasUsed.toLocaleString());
        res.receipt.rawLogs.slice(0, countLimited).forEach(log => {
            virtualMinters.push(log.topics[1].replace('000000000000000000000000', ''))
        })
        tokenId = BigInt(res.receipt.rawLogs[countLimited]?.topics[3]);
        assert.ok(tokenId === tokenIdRegular);
        assert.ok(virtualMinters.length === countLimited);
    })

    it("Should verify that XEN Crypto has increased Global Rank by the number of virtual minters", async () => {
        assert.ok(await token.activeMinters().then(_ => _.toNumber()) === countLimited);
        //console.log(await token.activeMinters().then(_ => _.toNumber()));
    })

    it("Should not be able to access minters' transactional interface directly", async () => {
        const provider = new Web3Provider(web3.currentProvider);
        const vmu0 = new Contract(virtualMinters[0], xeNFT.abi, provider.getSigner(4));
        assert.ok(vmu0.address === virtualMinters[0]);
        assert.ok(await vmu0.xenCrypto() === xenCryptoAddress);
        assert.ok(await vmu0.name() === '');
        assert.ok(await vmu0.symbol() === '');
        assert.ok(await vmu0.genesisTs().then(_ => _.toNumber()) > genesisTs);
        await assert.rejects(() => vmu0.callClaimRank(1, { gasLimit: 200_000 }).then(_ => _.wait()));
        await assert.rejects(() => vmu0.callClaimMintReward(accounts[3], { gasLimit: 100_000 }).then(_ => _.wait()));
        await assert.rejects(() => vmu0.powerDown().then(_ => _.wait()));
        await assert.rejects(() => vmu0.bulkClaimRank(1, 1, { gasLimit: 500_000 }).then(_ => _.wait()));
    })

    it("Should not allow burn transaction from EOA", async () => {
        await assert.rejects(() => xeNFT.burn(accounts[0], tokenId));
    });

    it("Should not allow using `onTokenBurned` callback directly", async () => {
        await assert.rejects(
            () => xeNFT.onTokenBurned(accounts[0], tokenId),
            'XENFT: illegal callback state'
        );
    });

    it("Should verify that mint initiator possesses NFT by its tokenId", async () => {
        assert.ok(await xeNFT.ownerOf(tokenId) === accounts[0]);
        assert.ok(await xeNFT.balanceOf(accounts[0]).then(_ => _.toNumber()) === 1);
        const ownedTokens = await xeNFT.ownedTokens();
        assert.ok(ownedTokens.length === 1);
        assert.ok(BigInt(ownedTokens[0].toNumber()) === tokenId);
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

    it("Should be able to return minters", async () => {
        assert.ok(await xeNFT.vmuCount(tokenId).then(_ => _.toNumber()) === countLimited)
    })

    it("Should perform bulkClaimMintReward operation for eligible NFT owner", async () => {
        await timeMachine.advanceTime(term * 24 * 3600 + 3600);
        await timeMachine.advanceBlock();
        await assert.rejects(() => xeNFT.bulkClaimMintReward(tokenId, accounts[1], { from: accounts[1] }));
        const res = await xeNFT.bulkClaimMintReward(tokenId, accounts[0], { from: accounts[0] });
        extraPrint && console.log('      gas used', res.receipt.gasUsed.toLocaleString());
        assert.ok(await token.activeMinters().then(_ => _.toNumber()) === 0);
        assert.ok(await token.balanceOf(accounts[0]).then(toBigInt) > 0n);
    })

    it("Should verify that post-mint NFT has been redeemed and cannot be reused", async () => {
        // await assert.rejects(() => xeNFT.ownerOf(tokenId));
        assert.ok(await xeNFT.balanceOf(accounts[0]).then(_ => _.toNumber()) === 1);
    })

    it("Should generate SVG of a redeemed NFT", async () => {
        //extraPrint && console.log(await xeNFT.genSVG(1));
    })

    it("Should perform another bulkClaimRank operation with regular count", async () => {
        const newVirtualMinters = [];
       const countRegular = 110;
        const res = await xeNFT.bulkClaimRank(countRegular, term2, { from: accounts[1] });
        assert.ok(res.receipt.rawLogs.length === countRegular + 2);
        extraPrint && console.log('      gas used', res.receipt.gasUsed.toLocaleString());
        res.receipt.rawLogs.slice(0, countRegular).forEach(log => {
            newVirtualMinters.push(log.topics[1].replace('000000000000000000000000', ''))
        })
        tokenId = BigInt(res.receipt.rawLogs[countRegular]?.topics[3]);
        assert.ok(tokenId === tokenIdRegular + 1n);
        assert.ok(newVirtualMinters.length === countRegular);
        for (let i = 0; i < countRegular; i++) {
            assert.ok(virtualMinters[i] !== newVirtualMinters[i]);
        }
    })

    it("Should retrieve metadata of regular NFT", async () => {
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

    it("NFT non-owner should NOT be able to transfer NFT ownership to another account", async () => {
        await assert.rejects(() => xeNFT.transferFrom(accounts[0], accounts[1], tokenId, { from: accounts[1] }));
        await assert.rejects(() => xeNFT.transferFrom(accounts[1], accounts[0], tokenId, { from: accounts[0] }));
    })

    it("NFT owner should be able to transfer NFT ownership to another account", async () => {
        let ownedTokens1 = await xeNFT.ownedTokens({ from: accounts[1] });
        assert.ok(ownedTokens1.length === 1);
        assert.ok(BigInt(ownedTokens1[0].toNumber()) === tokenId);
        await assert.doesNotReject(() => xeNFT.transferFrom(accounts[1], accounts[0], tokenId, { from: accounts[1] }));
        assert.ok(await xeNFT.ownerOf(tokenId, { from: accounts[0] }) === accounts[0]);
        ownedTokens1 = await xeNFT.ownedTokens({ from: accounts[1] });
        assert.ok(ownedTokens1.length === 0);
        assert.ok(await xeNFT.ownerOf(tokenId, { from: accounts[0] }) === accounts[0]);
        const ownedTokens0 = await xeNFT.ownedTokens({ from: accounts[0] });
        assert.ok(ownedTokens0.length === 2);
    })

    it("Should perform bulkClaimMintReward operation for (new) eligible NFT owner", async () => {
        await timeMachine.advanceTime((term2 + 20) * 24 * 3600 + 3600);
        await timeMachine.advanceBlock();
        await assert.rejects(() => xeNFT.bulkClaimMintReward(tokenId, accounts[3], { from: accounts[1] }));
        await assert.rejects(() => xeNFT.bulkClaimMintReward(tokenId + 2n, accounts[3], { from: accounts[0] }));
        const res = await xeNFT.bulkClaimMintReward(tokenId, accounts[3], { from: accounts[0] });
        extraPrint && console.log('      gas used', res.receipt.gasUsed.toLocaleString());
        assert.ok(await token.activeMinters().then(_ => _.toNumber()) === 0);
        assert.ok(await token.balanceOf(accounts[3]).then(toBigInt) > 0n);
    })

})
