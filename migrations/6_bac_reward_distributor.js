const { bacPools, INITIAL_BSD_FOR_POOLS } = require('./pools');

// Pools
// deployed first
const Dollar = artifacts.require('Dollar')
const InitialDollarDistributor = artifacts.require('InitialDollarDistributor');

// ============ Main Migration ============

module.exports = async (deployer, network, accounts) => {
  const unit = web3.utils.toBN(10 ** 18);
  const initialCashAmount = unit.muln(INITIAL_BSD_FOR_POOLS).toString();

  const dollar = await Dollar.deployed();
  const pools = bacPools.map(({contractName}) => artifacts.require(contractName));

  await deployer.deploy(
    InitialDollarDistributor,
    dollar.address,
    pools.map(p => p.address),
    initialCashAmount,
  );
  const distributor = await InitialDollarDistributor.deployed();

  console.log(`Setting distributor to InitialDollarDistributor (${distributor.address})`);
  for await (const poolInfo of pools) {
    const pool = await poolInfo.deployed()
    await pool.setRewardDistribution(distributor.address);
  }

  await dollar.mint(distributor.address, initialCashAmount);
  console.log(`Deposited ${INITIAL_BSD_FOR_POOLS} BSD to InitialDollarDistributor.`);

  await distributor.distribute();
}
