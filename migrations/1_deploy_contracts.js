const fs = require("fs");

const Chip = artifacts.require("Chip");
const Fish = artifacts.require("Fish");
const Mpea = artifacts.require("Mpea");
const ChipRewardPool = artifacts.require("ChipRewardPool");
const FishRewardPool = artifacts.require("FishRewardPool");
const Boardroom = artifacts.require("Boardroom");
const ChipSwapMechanism = artifacts.require("ChipSwapMechanism");
const Oracle = artifacts.require("Oracle");
const Treasury = artifacts.require("Treasury");

const startBlockNumber = 30000000;

module.exports = function(deployer) {
  deployer.deploy(Chip).then(() => {
    console.log(`Chip Address: ${ Chip.address }`);
    deployer.deploy(ChipRewardPool, Chip.address, startBlockNumber).then(() => {
      console.log(`ChipRewardPool Address: ${ ChipRewardPool.address }`);
    });
    deployer.deploy(Fish).then(() => {
      console.log(`Fish Address: ${ Fish.address }`);
      deployer.deploy(FishRewardPool, Fish.address, startBlockNumber).then(() => {
        console.log(`FishRewardPool Address: ${ FishRewardPool.address }`);
      });
      deployer.deploy(ChipSwapMechanism, Chip.address, Fish.address).then(() => {
        console.log(`ChipSwapMechanism Address: ${ ChipSwapMechanism.address }`);
      });
    });
  });

  deployer.deploy(Boardroom).then(() => {
    console.log(`Boardroom Address: ${ Boardroom.address }`);
  });
  deployer.deploy(Oracle).then(() => {
    console.log(`Oracle Address: ${ Oracle.address }`);
  });
  deployer.deploy(Treasury).then(() => {
    console.log(`Treasury Address: ${ Treasury.address }`);
  });
  deployer.deploy(Mpea).then(() => {
    console.log(`Mpea Address: ${ Mpea.address }`);
  });
};
