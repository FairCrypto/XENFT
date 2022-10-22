const XENTorrent = artifacts.require("XENTorrent");
const XENCrypto = artifacts.require("XENCrypto");
const DateTime = artifacts.require("DateTime");

require("dotenv").config();

const xenContractAddress = process.env.XEN_CONTRACT_ADDRESS;

module.exports = async function (deployer, network) {
  await deployer.deploy(DateTime);
  await deployer.link(DateTime, XENTorrent);
  if (xenContractAddress && network !== 'test') {
    await deployer.deploy(XENTorrent, xenContractAddress);
  } else {
    const xenContract = await XENCrypto.deployed();
    // console.log(network, xenContract?.address)
    await deployer.deploy(XENTorrent, xenContract.address);
  }
};
