const XENFT = artifacts.require("XENFT");
const XENCrypto = artifacts.require("XENCrypto");
const DateTime = artifacts.require("DateTime");
const StringData = artifacts.require("StringData");
const MintInfo = artifacts.require("MintInfo");
const Metadata = artifacts.require("Metadata");
const TestBulkMinter = artifacts.require("TestBulkMinter");

require("dotenv").config();

module.exports = async function (deployer, network) {

    const xenContractAddress = process.env[`${network.toUpperCase()}_CONTRACT_ADDRESS`];

    await deployer.deploy(DateTime);
    await deployer.link(DateTime, Metadata);

    await deployer.deploy(StringData);
    await deployer.link(StringData, Metadata);

    await deployer.deploy(MintInfo);
    await deployer.link(MintInfo, Metadata);
    await deployer.link(MintInfo, XENFT);

    await deployer.deploy(Metadata);
    await deployer.link(Metadata, XENFT);

    const { burnRates, rareLimits } = (network === 'test' || network === 'ganache')
        ? require('../config/specialNFTs.test.js')
        : require('../config/specialNFTs.js');

    const ether = 10n ** 18n;
    const burnRatesParam = burnRates.map(r => r * ether);

    if (xenContractAddress) {
        await deployer.deploy(XENFT, xenContractAddress, burnRatesParam, rareLimits);
    } else {
        const xenContract = await XENCrypto.deployed();
        // console.log(network, xenContract?.address)
        await deployer.deploy(XENFT, xenContract.address, burnRatesParam, rareLimits);
    }
    if (network === 'test') {
        const xenftAddress = XENFT.address;
        const xenCryptoAddress = XENCrypto.address;
        // console.log(xenftAddress);
        await deployer.deploy(TestBulkMinter, xenCryptoAddress, xenftAddress);
    }
};
