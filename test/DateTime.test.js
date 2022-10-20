// SPDX-License-Identifier: MIT

const assert = require('assert')
require('dotenv').config()
// const truffleAssert = require('truffle-assertions')
const timeMachine = require('ganache-time-traveler');

const XENCrypto = artifacts.require("XENCrypto")
const XENMinter = artifacts.require("XENMinter")

// const { bn2hexStr, toBigInt, maxBigInt, etherToWei } = require('../src/utils.js')

contract("XEN Minter", async accounts => {

    let token;
    let minter;

    before(async () => {
        try {
            token = await XENCrypto.deployed();
            minter = await XENMinter.deployed();
        } catch (e) {
            console.error(e)
        }
    })

    it("Date Time", async () => {
        // console.log(await minter.month(2))
    })

})
