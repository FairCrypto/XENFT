const StringData = artifacts.require("StringData");
const Metadata = artifacts.require("Metadata");

require("dotenv").config();

module.exports = async function (deployer, network) {

    const stringDataAddress = process.env[`${network.toUpperCase()}_STRINGDATA_ADDRESS`];

    if (stringDataAddress) {
        const stringData = await StringData.new(stringDataAddress);
        await deployer.link(stringData, Metadata);
    } else {
        await deployer.deploy(StringData);
        await deployer.link(StringData, Metadata);
    }
};
