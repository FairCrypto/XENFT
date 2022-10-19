const XENCrypto = artifacts.require("XENCrypto");
const Math = artifacts.require("Math");

require("dotenv").config();

module.exports = async function (deployer) {
  await deployer.deploy(Math);
  await deployer.link(Math, XENCrypto);
  await deployer.deploy(XENCrypto);
};
