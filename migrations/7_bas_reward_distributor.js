const {
  basPools,
  INITIAL_BSS_FOR_DAI_BSD,
  INITIAL_BSS_FOR_DAI_BSS,
} = require('./pools');

// Pools
// deployed first
const Share = artifacts.require('Share');
const InitialShareDistributor = artifacts.require('InitialShareDistributor');

// ============ Main Migration ============

async function migration(deployer, network, accounts) {
  const unit = web3.utils.toBN(10 ** 18);
  const totalBalanceForDAIBSD = unit.muln(INITIAL_BSS_FOR_DAI_BSD)
  const totalBalanceForDAIBSS = unit.muln(INITIAL_BSS_FOR_DAI_BSS)
  const totalBalance = totalBalanceForDAIBSD.add(totalBalanceForDAIBSS);

  const share = await Share.deployed();

  const lpPoolDAIBSD = artifacts.require(basPools.DAIBSD.contractName);
  const lpPoolDAIBSS = artifacts.require(basPools.DAIBSS.contractName);

  await deployer.deploy(
    InitialShareDistributor,
    share.address,
    lpPoolDAIBSD.address,
    totalBalanceForDAIBSD.toString(),
    lpPoolDAIBSS.address,
    totalBalanceForDAIBSS.toString(),
  );
  const distributor = await InitialShareDistributor.deployed();

  await share.mint(distributor.address, totalBalance.toString());
  console.log(`Deposited ${INITIAL_BSS_FOR_DAI_BSD} BSS to InitialShareDistributor.`);

  console.log(`Setting distributor to InitialShareDistributor (${distributor.address})`);
  await lpPoolDAIBSD.deployed().then(pool => pool.setRewardDistribution(distributor.address));
  await lpPoolDAIBSS.deployed().then(pool => pool.setRewardDistribution(distributor.address));

  await distributor.distribute();
}

module.exports = migration;
