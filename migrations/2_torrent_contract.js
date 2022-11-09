const XENFT = artifacts.require("XENFT");
const XENCrypto = artifacts.require("XENCrypto");
// const XENCryptoPreminted = artifacts.require("XENCryptoPreminted");
const DateTime = artifacts.require("DateTime");
const StringData = artifacts.require("StringData");
const MintInfo = artifacts.require("MintInfo");
const Metadata = artifacts.require("Metadata");

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
    // const xenContract = await XENCryptoPreminted.deployed();
    // console.log(network, xenContract?.address)
    const ether = 10n ** 18n;
    const burnRates = [
        1_000_000n * ether,
        500_000n * ether,
        200_000n * ether,
        100_000n * ether,
        50_000n * ether,
        1_000n * ether
    ];
    const rareCounts = [
        100,
        1_000,
        3_000,
        6_000,
        10_000
    ];
    await deployer.deploy(XENFT, xenContract.address, burnRates, rareCounts);
  }
};
