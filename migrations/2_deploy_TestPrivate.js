const TestPrivate = artifacts.require("TestPrivate");

module.exports = function (deployer, network, accounts) {
  const secretUse =
    "0x0000000000000000000000000000000000007365637265742069732068657265"; //secret is here
  deployer.deploy(TestPrivate, secretUse);
};
