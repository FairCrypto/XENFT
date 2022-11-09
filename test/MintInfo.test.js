const {toBigInt} = require("../src/utils");
const assert = require("assert");
const MintInfo = artifacts.require("MintInfo");

let mintInfo
const r = 0b1000_0000;
const l = 0b0100_0000;

contract("MintInfo Library", async () => {

    before(async () => {
        try {
            mintInfo = await MintInfo.deployed();
        } catch (e) {
            console.error(e)
        }
    })

    it("Should test mintInfo encoding/decoding 1", async () => {
        const s = 0b0000_0110;
        const encodedMintInfo = await mintInfo.encodeMintInfo(1,2,3,4,5,(s | l) | r,false).then(toBigInt);
        // console.log(BigInt(mintInfo).toString(2))
        const { term, maturityTs, rank, amp, eaa, series, rare, limited, redeemed } =  await mintInfo.decodeMintInfo(encodedMintInfo);
        assert.ok(term.toNumber() === 1);
        assert.ok(maturityTs.toNumber() === 2);
        assert.ok(rank.toNumber() === 3);
        assert.ok(amp.toNumber() === 4);
        assert.ok(eaa.toNumber() === 5);
        assert.ok(series.toNumber() === 6);
        assert.ok(rare === true);
        assert.ok(limited === true);
        assert.ok(redeemed === false);
    })

    it("Should test mintInfo encoding/decoding 2", async () => {
        const s = 0b0000_0110;
        const encodedMintInfo = await mintInfo.encodeMintInfo(1,2,3,4,5,s,false).then(toBigInt);
        // console.log(BigInt(mintInfo).toString(2))
        const { term, maturityTs, rank, amp, eaa, series, rare, limited, redeemed } =  await mintInfo.decodeMintInfo(encodedMintInfo);
        assert.ok(term.toNumber() === 1);
        assert.ok(maturityTs.toNumber() === 2);
        assert.ok(rank.toNumber() === 3);
        assert.ok(amp.toNumber() === 4);
        assert.ok(eaa.toNumber() === 5);
        assert.ok(series.toNumber() === 6);
        assert.ok(rare === false);
        assert.ok(limited === false);
        assert.ok(redeemed === false);
    })

})
