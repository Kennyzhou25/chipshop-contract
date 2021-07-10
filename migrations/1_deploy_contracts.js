const fs = require("fs");

const Chip = artifacts.require("Chip");
const Fish = artifacts.require("Fish");
const Mpea = artifacts.require("Mpea");
// const ChipRewardPool = artifacts.require("ChipRewardPool");
const FishRewardPool = artifacts.require("FishRewardPool");
const Boardroom = artifacts.require("Boardroom");
const ChipSwapMechanism = artifacts.require("ChipSwapMechanism");
const Oracle = artifacts.require("Oracle");
const Treasury = artifacts.require("Treasury");
const TokenMigration = artifacts.require("TokenMigration");

// const chipAddress = "0xedDD4bB8Fa49A815bb0B7F15875117308393d76b";
// const fishAddress = "0xbAA0eE13b1371a0Ce9B631AB06A2BFBB4B667bE8";

const chipStartBlock = 8009960;
const fishStartBlock = 10464233;

module.exports = function(deployer) {
  // deployer.deploy(Chip).then(() => {
  //   console.log(`Chip Address: ${ Chip.address }`);
  //   // deployer.deploy(ChipRewardPool, Chip.address, chipStartBlock).then(() => {
  //   //   console.log(`ChipRewardPool Address: ${ ChipRewardPool.address }`);
  //   // });
  //   deployer.deploy(Fish).then(() => {
  //     console.log(`Fish Address: ${ Fish.address }`);
  //     deployer.deploy(FishRewardPool, Fish.address, fishStartBlock).then(() => {
  //       console.log(`FishRewardPool Address: ${ FishRewardPool.address }`);
  //     });
  //     deployer.deploy(ChipSwapMechanism, Chip.address, Fish.address).then(() => {
  //       console.log(`ChipSwapMechanism Address: ${ ChipSwapMechanism.address }`);
  //     });
  //     deployer.deploy(Mpea).then(() => {
  //       console.log(`Mpea Address: ${ Mpea.address }`);
  //       deployer.deploy(TokenMigration, Chip.address, Fish.address, Mpea.address).then(() =>{
  //         console.log(`TokenMigration Address: ${ TokenMigration.address }`);
  //       });
  //     });
  //   });
  // });

  // deployer.deploy(Boardroom).then(() => {
  //   console.log(`Boardroom Address: ${ Boardroom.address }`);
  // });
  // deployer.deploy(Oracle).then(() => {
  //   console.log(`Oracle Address: ${ Oracle.address }`);
  // });
  deployer.deploy(Treasury).then(() => {
    console.log(`Treasury Address: ${ Treasury.address }`);
  });

  // deployer.deploy(Chip).then(() => {
  //   console.log(`Chip Address: ${ Chip.address }`);
  // });
};
