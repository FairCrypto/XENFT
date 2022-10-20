const XENCrypto = artifacts.require("XENCrypto");
const Math = artifacts.require("Math");

require("dotenv").config();

module.exports = async function (deployer, network) {
  if (process.env.XEN_CONTRACT_ADDRESS && network !== 'test') {
    console.log('using existing XEN at', process.env.XEN_CONTRACT_ADDRESS)
  } else {
    await deployer.deploy(Math);
    await deployer.link(Math, XENCrypto);
    await deployer.deploy(XENCrypto);
  }
};
