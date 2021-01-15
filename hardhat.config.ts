import '@nomiclabs/hardhat-truffle5';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import 'hardhat-typechain';
import 'hardhat-deploy';
import 'hardhat-deploy-ethers';
import 'hardhat-contract-sizer';
import 'hardhat-gas-reporter';
import 'solidity-coverage';

export default {
  default: 'hardhat',
  networks: {
    hardhat: {}
  },
  solidity: {
    version: '0.6.12',
    settings: {
      optimizer: {
        enabled: true,
        runs: 9999
      }
    }
  },
  paths: {
    sources: './contracts',
    tests: './test',
    cache: './build/cache',
    artifacts: './build/artifacts'
  },
  gasReporter: {
    currency: 'USD',
    enabled: true
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: '<api-key>'
  }
};
