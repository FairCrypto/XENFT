const StringData = artifacts.require("StringData");
const Metadata = artifacts.require("Metadata");

require("dotenv").config();

module.exports = async function (deployer, network) {

    const stringDataAddress = process.env[`${network.toUpperCase()}_STRINGDATA_ADDRESS`];

    if (stringDataAddress) {
        console.log('using existing stringDataAddress', stringDataAddress);
        const stringData = await StringData.at(stringDataAddress);
        await deployer.link(stringData, Metadata);
    } else {
        await deployer.deploy(StringData);
        await deployer.link(StringData, Metadata);
    }
};
