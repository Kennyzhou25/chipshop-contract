const knownContracts = require('./known-contracts');
const {POOL_START_DATE} = require('./pools');

const Dollar = artifacts.require('Dollar');
const Share = artifacts.require('Share');
const Oracle = artifacts.require('Oracle');
const MockDai = artifacts.require('MockDai');

const DAIBSDLPToken_BSDSPool = artifacts.require('DAIBSDLPTokenSharePool');
const DAIBSDSLPToken_BSDSPool = artifacts.require('DAIBSDSLPTokenSharePool');

const UniswapV2Factory = artifacts.require('UniswapV2Factory');

module.exports = async (deployer, network, accounts) => {
    const uniswapFactory = ['dev'].includes(network) ? await UniswapV2Factory.deployed() : await UniswapV2Factory.at(knownContracts.UniswapV2Factory[network]);
    const dai = network === 'mainnet' ? await IERC20.at(knownContracts.DAI[network]) : await MockDai.deployed();

    const oracle = await Oracle.deployed();

    const dai_bac_lpt = await oracle.pairFor(uniswapFactory.address, Dollar.address, dai.address);
    const dai_bas_lpt = await oracle.pairFor(uniswapFactory.address, Share.address, dai.address);

    await deployer.deploy(DAIBSDLPToken_BSDSPool, Share.address, dai_bac_lpt, POOL_START_DATE);
    await deployer.deploy(DAIBSDSLPToken_BSDSPool, Share.address, dai_bas_lpt, POOL_START_DATE);
};
