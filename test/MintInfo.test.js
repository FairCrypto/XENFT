const {toBigInt} = require("../src/utils");
const assert = require("assert");
const MintInfo = artifacts.require("MintInfo");

let mintInfo
const r = 0b1000_0000;
const l = 0b0100_0000;

// const maxUint8 = 2n ** 8n - 1n;
const maxUint16 = 2n ** 16n - 1n;
const maxUint64 = 2n ** 64n - 1n;
const maxUint128 = 2n ** 128n - 1n;
const maxUint256 = 2n ** 256n - 1n;

/*
    term (uint16)
    | maturityTs (uint64)
    | rank (uint128)
    | amp (uint16)
    | eaa (uint16)
    | category/series (uint8):
      [7] isAPex
      [6] isLimited
      [0-5] powerGroupIdx
    | redeemed (uint8)
 */
contract("MintInfo Library", async () => {

    before(async () => {
        try {
            mintInfo = await MintInfo.deployed();
        } catch (e) {
            console.error(e)
        }
    });

    it("Should perform mintInfo encoding/decoding 1", async () => {
        const s = 0b0000_0110;
        const encodedMintInfo = await mintInfo.encodeMintInfo(1,2,3,4,5,(s | l) | r,false).then(toBigInt);
        // console.log(BigInt(mintInfo).toString(2))
        const { term, maturityTs, rank, amp, eaa, class: class_, apex, limited, redeemed } =  await mintInfo.decodeMintInfo(encodedMintInfo);
        assert.ok(term.toNumber() === 1);
        assert.ok(maturityTs.toNumber() === 2);
        assert.ok(rank.toNumber() === 3);
        assert.ok(amp.toNumber() === 4);
        assert.ok(eaa.toNumber() === 5);
        assert.ok(class_.toNumber() === 6);
        assert.ok(apex === true);
        assert.ok(limited === true);
        assert.ok(redeemed === false);
    })

    it("Should perform mintInfo encoding/decoding 2", async () => {
        const s = 0b0000_0110;
        const encodedMintInfo = await mintInfo.encodeMintInfo(1 ,2, 3, 4, 5, s, false).then(toBigInt);
        const { term, maturityTs, rank, amp, eaa, class: class_, apex, limited, redeemed } =  await mintInfo.decodeMintInfo(encodedMintInfo);
        assert.ok(term.toNumber() === 1);
        assert.ok(maturityTs.toNumber() === 2);
        assert.ok(rank.toNumber() === 3);
        assert.ok(amp.toNumber() === 4);
        assert.ok(eaa.toNumber() === 5);
        assert.ok(class_.toNumber() === 6);
        assert.ok(apex === false);
        assert.ok(limited === false);
        assert.ok(redeemed === false);
    });

    it("Should encode correctly in overflow conditions (term)", async () => {
        const s = 0b0000_0110;
        const encodedMintInfo = await mintInfo.encodeMintInfo(
            maxUint256,
            2,
            3,
            4,
            5,
            s,
            false
        ).then(toBigInt);
        const { term, maturityTs } =  await mintInfo.decodeMintInfo(encodedMintInfo);
        assert.ok(toBigInt(term) === maxUint16);
        assert.ok(maturityTs.toNumber() === 2);
    });

    it("Should encode correctly in overflow conditions (maturityTs)", async () => {
        const s = 0b0000_0110;
        const encodedMintInfo = await mintInfo.encodeMintInfo(
            1,
            maxUint256,
            3,
            4,
            5,
            s,
            false
        ).then(toBigInt);
        const { term, maturityTs, rank } =  await mintInfo.decodeMintInfo(encodedMintInfo);
        assert.ok(term.toNumber() === 1);
        assert.ok(toBigInt(maturityTs) === maxUint64);
        assert.ok(rank.toNumber() === 3);
    });

    it("Should encode correctly in overflow conditions (rank)", async () => {
        const s = 0b0000_0110;
        const encodedMintInfo = await mintInfo.encodeMintInfo(
            1,
            2,
            maxUint256,
            4,
            5,
            s,
            false
        ).then(toBigInt);
        const { term, maturityTs, rank, amp } =  await mintInfo.decodeMintInfo(encodedMintInfo);
        assert.ok(term.toNumber() === 1);
        assert.ok(maturityTs.toNumber() === 2);
        assert.ok(toBigInt(rank) === maxUint128);
        assert.ok(amp.toNumber() === 4);
    });

    it("Should encode correctly in overflow conditions (amp)", async () => {
        const s = 0b0000_0110;
        const encodedMintInfo = await mintInfo.encodeMintInfo(
            1,
            2,
            3,
            maxUint256,
            5,
            s,
            false
        ).then(toBigInt);
        const { term, maturityTs, rank, amp, eaa } =  await mintInfo.decodeMintInfo(encodedMintInfo);
        assert.ok(term.toNumber() === 1);
        assert.ok(maturityTs.toNumber() === 2);
        assert.ok(rank.toNumber() === 3);
        assert.ok(toBigInt(amp) === maxUint16);
        assert.ok(eaa.toNumber() === 5);
    });

    it("Should encode correctly in overflow conditions (eaa)", async () => {
        const s = 0b0000_0110;
        const encodedMintInfo = await mintInfo.encodeMintInfo(
            1,
            2,
            3,
            4,
            maxUint256,
            s,
            false
        ).then(toBigInt);
        const { term, maturityTs, rank, amp, eaa, class: class_ } =  await mintInfo.decodeMintInfo(encodedMintInfo);
        assert.ok(term.toNumber() === 1);
        assert.ok(maturityTs.toNumber() === 2);
        assert.ok(rank.toNumber() === 3);
        assert.ok(amp.toNumber() === 4);
        assert.ok(toBigInt(eaa) === maxUint16);
        assert.ok(class_.toNumber() === 6);
    });

    it("Should encode correctly in overflow conditions (class/rare/limited)", async () => {
        // const s = 0b0000_0110;
        const encodedMintInfo = await mintInfo.encodeMintInfo(
            1,
            2,
            3,
            4,
            5,
            maxUint256,
            false
        ).then(toBigInt);
        const { term, maturityTs, rank, amp, eaa, class: class_, apex, limited, redeemed } =  await mintInfo.decodeMintInfo(encodedMintInfo);
        assert.ok(term.toNumber() === 1);
        assert.ok(maturityTs.toNumber() === 2);
        assert.ok(rank.toNumber() === 3);
        assert.ok(amp.toNumber() === 4);
        assert.ok(eaa.toNumber() === 5);
        assert.ok(toBigInt(class_) === BigInt(0x3F));
        assert.ok(apex === true);
        assert.ok(limited === true);
        assert.ok(redeemed === false);
    });

    it("Should encode correctly in overflow conditions (redeemed)", async () => {
        const s = 0b0000_0110;
        const encodedMintInfo = await mintInfo.encodeMintInfo(
            1,
            2,
            3,
            4,
            5,
            s,
            maxUint256
        ).then(toBigInt);
        const { term, maturityTs, rank, amp, eaa, class: class_, apex, limited, redeemed } =  await mintInfo.decodeMintInfo(encodedMintInfo);
        assert.ok(term.toNumber() === 1);
        assert.ok(maturityTs.toNumber() === 2);
        assert.ok(rank.toNumber() === 3);
        assert.ok(amp.toNumber() === 4);
        assert.ok(eaa.toNumber() === 5);
        assert.ok(class_.toNumber() === 6);
        assert.ok(apex === false);
        assert.ok(limited === false);
        assert.ok(redeemed === true);
    });

})
