// SPDX-License-Identifier: MIT

const assert = require('assert')
require('dotenv').config()
// const truffleAssert = require('truffle-assertions')
const timeMachine = require('ganache-time-traveler');

const DateTime = artifacts.require("DateTime")
const XENTorrent = artifacts.require("XENTorrent")

// const { bn2hexStr, toBigInt, maxBigInt, etherToWei } = require('../src/utils.js')

contract("XEN Torrent (DateTime library)", async accounts => {

    let dateTime;
    let minter;

    before(async () => {
        try {
            dateTime = await DateTime.deployed();
            minter = await XENTorrent.deployed();
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
