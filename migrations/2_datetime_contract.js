const DateTime = artifacts.require("DateTime");
const Metadata = artifacts.require("Metadata");

require("dotenv").config();

module.exports = async function (deployer, network) {

    const dateTimeAddress = process.env[`${network.toUpperCase()}_DATETIME_ADDRESS`];

    if (dateTimeAddress) {
        console.log('using existing dateTimeAddress', dateTimeAddress);
        const dateTime = await DateTime.at(dateTimeAddress);
        await deployer.link(dateTime, Metadata);
    } else {
        await deployer.deploy(DateTime);
        await deployer.link(DateTime, Metadata);
    }
};
