// SPDX-License-Identifier: MIT

const assert = require('assert')
require('dotenv').config()

const Quotes = artifacts.require("Quotes")

// const { bn2hexStr, toBigInt, maxBigInt, etherToWei } = require('../src/utils.js')

contract("XENFT (Quotes library)", async () => {

    let quotes;

    before(async () => {
        try {
            quotes = await Quotes.deployed();
        } catch (e) {
            console.error(e)
        }
    })

    it("Should extract quotes by id, each of the same fixed length", async () => {
        const QUOTES = await quotes.QUOTES();
        assert.ok(await quotes.getQuote(QUOTES, 0) !== await quotes.getQuote(QUOTES, 11));
        assert.ok(await quotes.getQuote(QUOTES, 0).length === await quotes.getQuote(QUOTES, 11).length);
    })

})
