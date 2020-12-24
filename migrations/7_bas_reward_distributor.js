const {basPools, INITIAL_BSDS_FOR_DAI_BSD, INITIAL_BSDS_FOR_DAI_BSDS} = require('./pools');

// Pools
// deployed first
const Share = artifacts.require('Share');
const InitialShareDistributor = artifacts.require('InitialShareDistributor');

// ============ Main Migration ============

async function migration(deployer, network, accounts) {
    const unit = web3.utils.toBN(10 ** 18);
    const totalBalanceForDAIBSD = unit.muln(INITIAL_BSDS_FOR_DAI_BSD);
    const totalBalanceForDAIBSDS = unit.muln(INITIAL_BSDS_FOR_DAI_BSDS);
    const totalBalance = totalBalanceForDAIBSD.add(totalBalanceForDAIBSDS);

    const share = await Share.deployed();

    const lpPoolDAIBSD = artifacts.require(basPools.DAIBSD.contractName);
    const lpPoolDAIBSDS = artifacts.require(basPools.DAIBSDS.contractName);

    await deployer.deploy(
        InitialShareDistributor,
        share.address,
        lpPoolDAIBSD.address,
        totalBalanceForDAIBSD.toString(),
        lpPoolDAIBSDS.address,
        totalBalanceForDAIBSDS.toString()
    );
    const distributor = await InitialShareDistributor.deployed();

    await share.mint(distributor.address, totalBalance.toString());
    console.log(`Deposited ${INITIAL_BSDS_FOR_DAI_BSD} BSDS to InitialShareDistributor.`);

    console.log(`Setting distributor to InitialShareDistributor (${distributor.address})`);
    await lpPoolDAIBSD.deployed().then((pool) => pool.setRewardDistribution(distributor.address));
    await lpPoolDAIBSDS.deployed().then((pool) => pool.setRewardDistribution(distributor.address));

    await distributor.distribute();
}

module.exports = migration;
