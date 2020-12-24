// https://docs.basisdollar.fi/mechanisms/yield-farming
const INITIAL_BSD_FOR_POOLS = 50000;
const INITIAL_BSDS_FOR_DAI_BSD = 750000;
const INITIAL_BSDS_FOR_DAI_BSDS = 250000;

const POOL_START_DATE = Date.parse('2020-11-30T00:00:00Z') / 1000;

const bacPools = [
    {contractName: 'BSDDAIPool', token: 'DAI'},
    {contractName: 'BSDSUSDPool', token: 'SUSD'},
    {contractName: 'BSDUSDCPool', token: 'USDC'},
    {contractName: 'BSDUSDTPool', token: 'USDT'},
    {contractName: 'BSDyCRVPool', token: 'yCRV'},
];

const basPools = {
    DAIBSD: {contractName: 'DAIBSDLPTokenSharePool', token: 'DAI_BSD-LPv2'},
    DAIBSDS: {contractName: 'DAIBSDSLPTokenSharePool', token: 'DAI_BSDS-LPv2'},
};

module.exports = {
    POOL_START_DATE,
    INITIAL_BSD_FOR_POOLS,
    INITIAL_BSDS_FOR_DAI_BSD,
    INITIAL_BSDS_FOR_DAI_BSDS,
    bacPools,
    basPools,
};
