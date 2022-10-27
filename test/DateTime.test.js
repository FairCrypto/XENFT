// SPDX-License-Identifier: MIT

const assert = require('assert')
require('dotenv').config()

const DateTime = artifacts.require("DateTime")

// const { bn2hexStr, toBigInt, maxBigInt, etherToWei } = require('../src/utils.js')

contract("XENFT (DateTime library)", async accounts => {

    let dateTime;

    before(async () => {
        try {
            dateTime = await DateTime.deployed();
        } catch (e) {
            console.error(e)
        }
    })

    it("DateTime.asString should convert unix timestamp to Date-Time string", async () => {
        const dateTimeStr = await dateTime.asString(Math.floor((Date.now()  / 1_000)) + 20*60);
        assert.ok(new Date(dateTimeStr))
        console.log(dateTimeStr, new Date(dateTimeStr))
    })

})
