const XENFT = artifacts.require("XENFT");
const XENCrypto = artifacts.require("XENCrypto");
const DateTime = artifacts.require("DateTime");
const StringData = artifacts.require("StringData");
const MintInfo = artifacts.require("MintInfo");
const Metadata = artifacts.require("Metadata");

const { burnRates, rareCounts } = require('../config/specialNFTs.js');

require("dotenv").config();

const xenContractAddress = process.env.XEN_CONTRACT_ADDRESS;

module.exports = async function (deployer, network) {
    await deployer.deploy(DateTime);
    await deployer.link(DateTime, Metadata);

    await deployer.deploy(StringData);
    await deployer.link(StringData, Metadata);

    await deployer.deploy(MintInfo);
    await deployer.link(MintInfo, Metadata);
    await deployer.link(MintInfo, XENFT);

    await deployer.deploy(Metadata);
    await deployer.link(Metadata, XENFT);


  if (xenContractAddress && network !== 'test') {
    await deployer.deploy(XENFT, xenContractAddress);
  } else {
    const xenContract = await XENCrypto.deployed();
    // console.log(network, xenContract?.address)
    const ether = 10n ** 18n;
    const burnRatesParam = burnRates.map(r => r * ether);
    await deployer.deploy(XENFT, xenContract.address, burnRatesParam, rareCounts);
  }
};
