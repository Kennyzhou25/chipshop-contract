const Web3 = require('web3');
const BigNumber = require('bignumber.js');

const Chip = artifacts.require("Chip");
const Fish = artifacts.require("Fish");
const Mpea = artifacts.require("Mpea");
const FishRewardPool = artifacts.require("FishRewardPool");
const Boardroom = artifacts.require("Boardroom");
const ChipSwapMechanism = artifacts.require("ChipSwapMechanism");
const Oracle = artifacts.require("Oracle");
const Treasury = artifacts.require("Treasury");
const TokenMigration = artifacts.require("TokenMigration");

const MaxUint256 = (/*#__PURE__*/BigNumber("0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"));
const averageBlockTime = 3;
const beginRewardsAfter = 20 * 60;
const migrationDuration = 48 * 60 * 60;
const beginEpochAfter = 20 * 60;
const chipAllocationAmount = 0.01;
const fishAllocationAmount = 0.02;
const ethUnit = new BigNumber(1000000000000000000);

async function beforeMigration(deployer, network) {
  await deployer.deploy(Chip);
  await deployer.deploy(Fish);
  await deployer.deploy(Mpea);
  let oldChipAddress = '';
  let oldFishAddress = '';
  let oldMpeaAddress = '';
  switch (network) {
    case 'bscTestNet': {
      oldChipAddress = '0x8d5728fe016A07743e18B54fBbE07E853BCa491c';
      oldFishAddress = '0x4FAB296f67fBaC741D4A1b884a5cAb96974C7cd8';
      oldMpeaAddress = '0x117cC1e6C64C0830C587990b975612E2fcb9Ed22';
      break;
    }
    case 'bsc': {
      oldChipAddress = '0x7a4Feb21b86281F7D345dEDE500c9C51881b948B';
      oldFishAddress = '0xD47c524ae4Cf0f941D0Dd03b44CD9C80dd4238d6';
      oldMpeaAddress = '0x23A47619f784F109582f07C01D8a72512ba9D0E1';
      break;
    }
    default: {
      console.log('Error - Unregistered network type');
      return;
    }
  }
  const migrationEndTime = (Math.floor(new Date().getTime() / 1000) + migrationDuration).toString();
  await deployer.deploy(TokenMigration, oldChipAddress, oldFishAddress, oldMpeaAddress, Chip.address, Fish.address, migrationEndTime);
  console.log('Token Migration is finished');
  const chipContract = await Chip.deployed();
  const fishContract = await Fish.deployed();
  await chipContract.mint(TokenMigration.address, ethUnit.times(chipAllocationAmount));
  await fishContract.mint(TokenMigration.address, ethUnit.times(fishAllocationAmount));
}

async function afterMigration(deployer, network, accounts) {
  const daoAddresss = '0x1C3dF661182c1f9cc8afE226915e5f91E93d1A6f';
  let provider = '';
  let chipAddress = '';
  let fishAddress = '';
  let mpeaAdress = '';
  let busdAddres = '';
  let ethAddress = '';
  let chipBusdLpAddress = '';
  let chipEthLpAddress = '';
  let fishEthLpAddress = '';
  let fishBusdLpAddress = '';
  let mpeaChipLpAddress = '';
  let ethBusdLpAddress = '';
  let expansionDuration = 5 * 60;
  let contractionDuration = 5 * 60;

  switch (network) {
    case 'bscTestNet': {
      provider = 'https://data-seed-prebsc-1-s1.binance.org:8545';
      busdAddres = '0xb82b5086df3bC61D019457B9De2FF4124368CFFF';
      ethAddress = '0xEb8250680Fd67c0C9FE2C015AC702C8EdF02F335';
      chipAddress = '0xC741e51e65a582d10dc632c33AC3fB7D661320EC';
      fishAddress = '0xFF89A1882cA0037B5b0B40C976a945D98b23AD30';
      mpeaAdress = '0x2fE1ab3Ad4446F7d1a75ca500f052686ae0567DA';
      chipBusdLpAddress = '0xaf4528018d6351490c6303bbfb352ffd8d1bcb05';
      chipEthLpAddress = '0xaB5a4bFe8E7a5A2628cC690519bcC3481D66e9e0';
      fishEthLpAddress = '0x3715340BC619E5aDbca158Ab459F2EfFDa545675';
      fishBusdLpAddress = '0xcd489eac7137463b2757c4dc2cb03f679f9cad31';
      mpeaChipLpAddress = '0x18aeeca391db2913feb5659cc46d1f0bd906f2aa';
      ethBusdLpAddress = '0xD14eA0A4beF5aeD665eB26447Aaa7100193994cf';
      expansionDuration = 15 * 60;
      contractionDuration = 10 * 60;
      break;
    }
    case 'bsc': {
      provider = 'https://bsc-dataseed1.binance.org';
      busdAddres = '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56';
      ethAddress = '0x2170Ed0880ac9A755fd29B2688956BD959F933F8';
      chipAddress = '0xEEf106c1910720533ad28fa34751B95dDC8D262F';
      fishAddress = '0x32bd7d3CaBd7422DE15a9e5FB53541d637DC0E83';
      mpeaAdress = '0xa736D652A4cF3cf8548fA944a238f34c2Aa3EBc4';
      chipBusdLpAddress = '0xe97eeab6bdf49b479b9109c3ad8eb8e2e3e98cd3';
      chipEthLpAddress = '0x015addd0bd0d415559f68d6e4624209594796aa9';
      fishEthLpAddress = '0x8b18c0d1c33307b488cc4f1253b3b92c5fc3638d';
      fishBusdLpAddress = '0x8982037A9e4dcD5Efec53F2E35057ddD6a18C4f8';
      mpeaChipLpAddress = '0x5a5e9e7d8b47774aefb60496e49e0f634b52090c';
      ethBusdLpAddress = '0x7213a321F1855CF1779f42c0CD85d3D95291D34C';
      expansionDuration = 5 * 60;
      contractionDuration = 5 * 60;
      break;
    }
    default: {
      console.log('Error - Unregistered network type');
      return;
    }
  }

  const web3 = new Web3(provider);
  const currentBlock = await web3.eth.getBlockNumber();
  //
  const fishStartBlock = currentBlock +  Math.floor(beginRewardsAfter / averageBlockTime);

  await deployer.deploy(FishRewardPool, fishAddress, fishStartBlock);
  await deployer.deploy(ChipSwapMechanism, chipAddress, fishAddress);

  const fishContract = await Fish.at(fishAddress);
  await fishContract.distributeReward(FishRewardPool.address);
  await fishContract.distributeChipSwapFund(ChipSwapMechanism.address);
  console.log('fish operation is finished.');

  const fishRewardPoolContract = await FishRewardPool.deployed();
  await fishRewardPoolContract.add(3000, chipBusdLpAddress, true, 0);
  await fishRewardPoolContract.add(3000, chipEthLpAddress, true, 0);
  await fishRewardPoolContract.add(4000, fishEthLpAddress, true, 0);
  await fishRewardPoolContract.add(4000, fishBusdLpAddress, true, 0);
  await fishRewardPoolContract.add(0, mpeaChipLpAddress, true, 0);
  console.log('fishRewardPool operation is finished.');

  await deployer.deploy(Boardroom);
  await deployer.deploy(Oracle);
  await deployer.deploy(Treasury);

  const boardroomContract = await Boardroom.deployed();
  await boardroomContract.initialize(chipAddress, fishAddress, Treasury.address);
  await fishContract.mint(accounts[0], 100000);
  await fishContract.approve(Boardroom.address, MaxUint256);
  await boardroomContract.stake(10000);
  console.log('boardroom operation is finished.');

  const oracleContract = await Oracle.deployed();
  await oracleContract.initialize(chipEthLpAddress, chipBusdLpAddress, ethBusdLpAddress);
  await oracleContract.setAddress(chipAddress, ethAddress, busdAddres);
  await oracleContract.setPriceAppreciation(10000);
  await oracleContract.setTreasury(Treasury.address);
  await oracleContract.update();
  console.log('oracle operation is finished.');

  const treasuryContract = await Treasury.deployed();
  const epochStartTime = (Math.floor(new Date().getTime() / 1000) + beginEpochAfter).toString();
  await treasuryContract.initialize(chipAddress, mpeaAdress, fishAddress, ethAddress, chipEthLpAddress, fishEthLpAddress, expansionDuration, contractionDuration, epochStartTime);
  await treasuryContract.setExtraContract(FishRewardPool.address, ChipSwapMechanism.address, Oracle.address, Boardroom.address);
  await treasuryContract.setExtraFunds(daoAddresss, 3500, daoAddresss, 0, daoAddresss, 0);
  console.log('treasury operation is finished.');

  const chipContract = await Chip.at(chipAddress);
  const mpeaContract = await Mpea.at(mpeaAdress);
  const chipSwapMechanismContract = await ChipSwapMechanism.deployed();

  await chipContract.transferOperator(Treasury.address);
  await mpeaContract.transferOperator(Treasury.address);
  await fishContract.transferOperator(Treasury.address);
  await fishRewardPoolContract.transferOperator(Treasury.address);
  await chipSwapMechanismContract.transferOperator(Treasury.address);
  await boardroomContract.transferOperator(Treasury.address);
  await oracleContract.transferOperator(Treasury.address);

  console.log('transferOperators are finished.');
}

async function test(deployer, network) {
  const daoAddresss = '0x1C3dF661182c1f9cc8afE226915e5f91E93d1A6f';
  let provider = '';
  let chipAddress = '';
  let fishAddress = '';
  let mpeaAdress = '';
  let busdAddres = '';
  let ethAddress = '';
  let chipBusdLpAddress = '';
  let chipEthLpAddress = '';
  let fishEthLpAddress = '';
  let fishBusdLpAddress = '';
  let mpeaChipLpAddress = '';
  let ethBusdLpAddress = '';
  let expansionDuration = 5 * 60;
  let contractionDuration = 5 * 60;

  switch (network) {
    case 'bscTestNet': {
      provider = 'https://data-seed-prebsc-1-s1.binance.org:8545';
      busdAddres = '0xb82b5086df3bC61D019457B9De2FF4124368CFFF';
      ethAddress = '0xEb8250680Fd67c0C9FE2C015AC702C8EdF02F335';
      chipAddress = '0xC741e51e65a582d10dc632c33AC3fB7D661320EC';
      fishAddress = '0xFF89A1882cA0037B5b0B40C976a945D98b23AD30';
      mpeaAdress = '0x2fE1ab3Ad4446F7d1a75ca500f052686ae0567DA';
      chipBusdLpAddress = '0xaf4528018d6351490c6303bbfb352ffd8d1bcb05';
      chipEthLpAddress = '0xaB5a4bFe8E7a5A2628cC690519bcC3481D66e9e0';
      fishEthLpAddress = '0x3715340BC619E5aDbca158Ab459F2EfFDa545675';
      fishBusdLpAddress = '0xcd489eac7137463b2757c4dc2cb03f679f9cad31';
      mpeaChipLpAddress = '0x18aeeca391db2913feb5659cc46d1f0bd906f2aa';
      ethBusdLpAddress = '0xD14eA0A4beF5aeD665eB26447Aaa7100193994cf';
      expansionDuration = 15 * 60;
      contractionDuration = 10 * 60;
      break;
    }
    case 'bsc': {
      provider = 'https://bsc-dataseed1.binance.org';
      busdAddres = '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56';
      ethAddress = '0x2170Ed0880ac9A755fd29B2688956BD959F933F8';
      chipAddress = '0xEEf106c1910720533ad28fa34751B95dDC8D262F';
      fishAddress = '0x32bd7d3CaBd7422DE15a9e5FB53541d637DC0E83';
      mpeaAdress = '0xa736D652A4cF3cf8548fA944a238f34c2Aa3EBc4';
      chipBusdLpAddress = '0xe97eeab6bdf49b479b9109c3ad8eb8e2e3e98cd3';
      chipEthLpAddress = '0x015addd0bd0d415559f68d6e4624209594796aa9';
      fishEthLpAddress = '0x8b18c0d1c33307b488cc4f1253b3b92c5fc3638d';
      fishBusdLpAddress = '0x8982037A9e4dcD5Efec53F2E35057ddD6a18C4f8';
      mpeaChipLpAddress = '0x5a5e9e7d8b47774aefb60496e49e0f634b52090c';
      ethBusdLpAddress = '0x7213a321F1855CF1779f42c0CD85d3D95291D34C';
      expansionDuration = 5 * 60;
      contractionDuration = 5 * 60;
      break;
    }
    default: {
      console.log('Error - Unregistered network type');
      return;
    }
  }
  await deployer.deploy(Boardroom);
  await deployer.deploy(Oracle);
  await deployer.deploy(Treasury);

  const boardroomContract = await Boardroom.deployed();
  await boardroomContract.initialize(chipAddress, fishAddress, Treasury.address);
  const fishContract = await Fish.at(fishAddress);
  await fishContract.approve(Boardroom.address, MaxUint256);
  await boardroomContract.stake(10000);
  console.log('boardroom operation is finished.');

  const oracleContract = await Oracle.deployed();
  await oracleContract.initialize(chipEthLpAddress, chipBusdLpAddress, ethBusdLpAddress);
  await oracleContract.setAddress(chipAddress, ethAddress, busdAddres);
  await oracleContract.setPriceAppreciation(10000);
  await oracleContract.setTreasury(Treasury.address);
  await oracleContract.update();
  console.log('oracle operation is finished.');

  await deployer.deploy(ChipSwapMechanism, chipAddress, fishAddress);
  const chipSwapMechanismContract = await ChipSwapMechanism.deployed();
  const chipSwapMechanismAddress = ChipSwapMechanism.address;


  const web3 = new Web3(provider);
  const currentBlock = await web3.eth.getBlockNumber();
  const fishStartBlock = currentBlock +  Math.floor(beginRewardsAfter / averageBlockTime);
  await deployer.deploy(FishRewardPool, fishAddress, fishStartBlock);
  const fishRewardPoolAddress = FishRewardPool.address;

  const treasuryContract = await Treasury.deployed();
  const epochStartTime = (Math.floor(new Date().getTime() / 1000) + beginEpochAfter).toString();
  await treasuryContract.initialize(chipAddress, mpeaAdress, fishAddress, ethAddress, chipEthLpAddress, fishEthLpAddress, expansionDuration, contractionDuration, epochStartTime);
  await treasuryContract.setExtraContract(fishRewardPoolAddress, chipSwapMechanismAddress, Oracle.address, Boardroom.address);
  await treasuryContract.setExtraFunds(daoAddresss, 3500, daoAddresss, 0, daoAddresss, 0);
  console.log('treasury operation is finished.');

  const chipContract = await Chip.at(chipAddress);
  const mpeaContract = await Mpea.at(mpeaAdress);

  const fishRewardPoolContract = await FishRewardPool.at(fishRewardPoolAddress);

  await chipContract.transferOperator(Treasury.address);
  await mpeaContract.transferOperator(Treasury.address);
  await fishContract.transferOperator(Treasury.address);
  await fishRewardPoolContract.transferOperator(Treasury.address);
  await chipSwapMechanismContract.transferOperator(Treasury.address);
  await boardroomContract.transferOperator(Treasury.address);
  await oracleContract.transferOperator(Treasury.address);

  console.log('transferOperators are finished.');
}

module.exports = async function(deployer, network) {
  // await beforeMigration(deployer, network);
  await afterMigration(deployer, network);
  // await test(deployer, network);
};
