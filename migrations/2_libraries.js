const DateTime = artifacts.require("DateTime");
const StringData = artifacts.require("StringData");
// const MintInfo = artifacts.require("MintInfo");
const Metadata = artifacts.require("Metadata");

require("dotenv").config();

module.exports = async function (deployer, network) {
    const dateTimeAddress = process.env[`${network.toUpperCase()}_DATETIME_ADDRESS`];
    const stringDataAddress = process.env[`${network.toUpperCase()}_STRINGDATA_ADDRESS`];

    if (!dateTimeAddress) {
        await deployer.deploy(DateTime);
        await deployer.link(DateTime, Metadata);
    } else {
        console.log('    using existing DateTime contract at', dateTimeAddress)
        const existingDateTime = await DateTime.at(dateTimeAddress);
        await deployer.link(existingDateTime, Metadata);
    }

    if (!stringDataAddress) {
        await deployer.deploy(StringData);
        await deployer.link(StringData, Metadata);
    } else {
        console.log('    using existing StringData contract at', stringDataAddress)
        const existingStringData= await StringData.at(stringDataAddress);
        await deployer.link(existingStringData, Metadata);
    }
};
