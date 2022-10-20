const XENMinter = artifacts.require("XENMinter");
const XENCrypto = artifacts.require("XENCrypto");

require("dotenv").config();

const xenContractAddress = process.env.XEN_CONTRACT_ADDRESS;

module.exports = async function (deployer, network) {
  if (xenContractAddress && network !== 'test') {
    await deployer.deploy(XENMinter, xenContractAddress);
  } else {
    const xenContract = await XENCrypto.deployed();
    // console.log(network, xenContract?.address)
    await deployer.deploy(XENMinter, xenContract.address);
  }
};
