const Party = artifacts.require("Party");
const PaySC = artifacts.require("PaySC");

module.exports = function(deployer) {
  deployer.deploy(Party)
        // Wait until the storage contract is deployed
        .then(() => Party.deployed())
        // Deploy the InfoManager contract, while passing the address of the
        // Storage contract
        .then(() => deployer.deploy(PaySC, Party.address));

};
