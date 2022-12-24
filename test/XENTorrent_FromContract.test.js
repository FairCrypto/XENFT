// SPDX-License-Identifier: MIT

const assert = require('assert');
const timeMachine = require('ganache-time-traveler');
const truffleAssert = require('truffle-assertions');

const XENCrypto = artifacts.require("XENCrypto");
const XENTorrent = artifacts.require("XENTorrent");

const ERC721Holder = artifacts.require("ERC721Holder");
const ERC721NonHolder = artifacts.require("ERC721NonHolder");
const ERC721BadHolder = artifacts.require("ERC721BadHolder");
const ERC721ReentrantHolder = artifacts.require("ERC721ReentrantHolder");

const { startBlock, burnRates, Series} = require('../config/genesisParams.test');

require('dotenv').config();

// const extraPrint = process.env.EXTRA_PRINT;

contract("XENFTs --- Minting by ERC721Holder", async accounts => {

    let token;
    let xeNFT;
    let holder;
    let nonHolder;
    let badHolder;
    let reentrantHolder;
    let currentBlock;

    const ether = 10n ** 18n;

    before(async () => {
        try {
            token = await XENCrypto.deployed();
            xeNFT = await XENTorrent.deployed();

            holder = await ERC721Holder.new(token.address, xeNFT.address);
            nonHolder = await ERC721NonHolder.new(xeNFT.address);
            badHolder = await ERC721BadHolder.new(xeNFT.address);
            reentrantHolder = await ERC721ReentrantHolder.new(xeNFT.address);

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

    it("Should obtain initial XEN balance via regular bulk minting", async () => {
        const c0 = 100;
        const t0days = 100;
        await assert.doesNotReject(() => xeNFT.bulkClaimRank(c0, t0days, { from: accounts[2] }));
        const tokens = await xeNFT.ownedTokens({ from: accounts[2] });
        assert.ok(tokens.length === 1);
        await timeMachine.advanceTime(t0days * 24 * 3600 + 3600);
        await timeMachine.advanceBlock();
        await assert.doesNotReject(() => xeNFT.bulkClaimMintReward(tokens[0], accounts[2], { from: accounts[2] }));
    });

    it('Shall NOT allow minting Apex XENFT from smart contract', async () => {
        const burningRare =  (burnRates[Series.RARE]) * ether;
        const burningLimited =  (burnRates[Series.LIMITED]) * ether;
        await assert.doesNotReject(() => token.transfer(holder.address, burningRare + burningLimited, {from: accounts[2]}));
        await truffleAssert.fails(
            holder.claimXENSpecial(100, 100, burningRare),
            'XENFT: only EOA allowed for this category'
        );
    })

    it('Shall allow minting XENFT from contract supporting IERC721Receiver', async () => {
        const burningLimited =  (burnRates[Series.LIMITED]) * ether;
        await assert.doesNotReject(() => holder.claimXENSpecial(100, 100, burningLimited));
        await assert.doesNotReject(() => holder.claimXENCommon(1, 100, { from: accounts[2] }));
        const _xenBalance = await xeNFT.balanceOf(holder.address, {from: accounts[2]}).then(_ => _.toNumber())
        assert.ok(_xenBalance === 2);
    })

    it('Shall NOT allow minting XENFT from contract NOT supporting IERC721Receiver', async () => {
        await truffleAssert.fails(
            nonHolder.claimXENCommon(1, 100, { from: accounts[2] }),
            'ERC721: transfer to non ERC721Receiver implementer'
        );
    })

   it('Shall NOT allow minting XENFT from contract which reverts on IERC721Receiver callback', async () => {
        await truffleAssert.fails(
            badHolder.claimXENCommon(1, 100, { from: accounts[2] }),
            'ERC721: transfer to non ERC721Receiver implementer'
        );
    })

   it('Shall NOT allow minting XENFT from contract which tries re-entrance on IERC721Receiver callback', async () => {
        await truffleAssert.fails(
            reentrantHolder.claimXENCommon(1, 1, { from: accounts[2] }),
            'XENFT: Reentrancy detected'
        );
    })

})
