// SPDX-License-Identifier: MIT

const assert = require('assert')
require('dotenv').config()

const StringData = artifacts.require("StringData")

contract("StringData library", async () => {

    let stringData;

    before(async () => {
        try {
            stringData = await StringData.deployed();
        } catch (e) {
            console.error(e)
        }
    });

    it("Should extract quotes by id, each of the same fixed length", async () => {
        const QUOTES = await stringData.QUOTES();
        assert.ok(await stringData.getQuote(QUOTES, 0) !== await stringData.getQuote(QUOTES, 11));
        assert.ok(await stringData.getQuote(QUOTES, 0).length === await stringData.getQuote(QUOTES, 11).length);
    });

})
