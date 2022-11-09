// SPDX-License-Identifier: MIT

const assert = require('assert')
require('dotenv').config()

const Metadata = artifacts.require("Metadata")

// const { bn2hexStr, toBigInt, maxBigInt, etherToWei } = require('../src/utils.js')

const extraPrint = process.env.EXTRA_PRINT;

contract("FormattedStrings library", async () => {

    let metaData;
    let test = 0;

    before(async () => {
        try {
            metaData = await Metadata.deployed();
        } catch (e) {
            console.error(e)
        }
    })

    it("Format 0", async () => {
        const formattedString = await metaData.formattedString(test);
        assert.ok(formattedString === (test).toLocaleString(['en-us']));
        extraPrint && console.log('     ', formattedString)
    })

    it("Format 999", async () => {
        test = 999;
        const formattedString = await metaData.formattedString(test);
        assert.ok(formattedString === (test).toLocaleString(['en-us']));
        extraPrint && console.log('     ', formattedString)
    })

    it("Format 1,000", async () => {
        test = 1_000;
        const formattedString = await metaData.formattedString(test);
        extraPrint && console.log('     ', formattedString)
        assert.ok(formattedString === (test).toLocaleString(['en-us']));
    })

    it("Format 999,999", async () => {
        test = 999_999;
        const formattedString = await metaData.formattedString(test);
        extraPrint && console.log('     ', formattedString)
        assert.ok(formattedString === (test).toLocaleString(['en-us']));
    })

    it("Format 1,999,000", async () => {
        test = 1_999_000;
        const formattedString = await metaData.formattedString(test);
        extraPrint && console.log('     ', formattedString)
        assert.ok(formattedString === (test).toLocaleString(['en-us']));
    })

})
