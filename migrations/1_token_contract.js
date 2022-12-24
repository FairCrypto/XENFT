const XENCrypto = artifacts.require("XENCrypto");
const Math = artifacts.require("Math");

require("dotenv").config();

module.exports = async function (deployer, network) {

  const xenContractAddress = process.env[`${network.toUpperCase()}_CONTRACT_ADDRESS`];
  console.log();

  if (xenContractAddress) {
    console.log('    using existing XEN Crypto contract at', xenContractAddress)
  } else {
    console.log('    deploying new XEN Crypto contract')
    await deployer.deploy(Math);
    await deployer.link(Math, XENCrypto);
    await deployer.deploy(XENCrypto);
  }
};
