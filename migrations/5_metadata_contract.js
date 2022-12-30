const XENTorrent = artifacts.require("XENTorrent");
const Metadata = artifacts.require("Metadata");

require("dotenv").config();

module.exports = async function (deployer, network) {

    const metadataAddress = process.env[`${network.toUpperCase()}_METADATA_ADDRESS`];

    if (metadataAddress) {
        const metadata = await Metadata.new(metadataAddress);
        await deployer.link(metadata, XENTorrent);
    } else {
        await deployer.deploy(Metadata);
        await deployer.link(Metadata, XENTorrent);
    }
};
