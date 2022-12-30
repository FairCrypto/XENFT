const XENTorrent = artifacts.require("XENTorrent");
const MintInfo = artifacts.require("MintInfo");
const Metadata = artifacts.require("Metadata");

require("dotenv").config();

module.exports = async function (deployer, network) {

    const mintInfoAddress = process.env[`${network.toUpperCase()}_MINTINFO_ADDRESS`];

    if (mintInfoAddress) {
        console.log('using existing mintInfoAddress', mintInfoAddress);
        const mintInfo = await MintInfo.at(mintInfoAddress);
        await deployer.link(mintInfo, Metadata);
        await deployer.link(mintInfo, XENTorrent);
    } else {
        await deployer.deploy(MintInfo);
        await deployer.link(MintInfo, Metadata);
        await deployer.link(MintInfo, XENTorrent);
    }
};
