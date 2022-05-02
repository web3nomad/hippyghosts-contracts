const { task } = require('hardhat/config');
require('@nomiclabs/hardhat-ethers');
require('hardhat-deploy');
const dotenv = require('dotenv');

// Load environment variables.
dotenv.config();
const NULL_PRIVATE_KEY = '0x0000000000000000000000000000000000000000000000000000000000000000';

module.exports = {
  solidity: {
    version: '0.8.11',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      live: false,
      saveDeployments: true, // hardhat 默认是 false
      hardfork: 'london',
      chainId: 31337,
      forking: {
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
        // blockNumber: 13965000
      },
      initialBaseFeePerGas: 0,
      accounts: [{
        // HARDHAT_DEPLOYER
        balance: '100000000000000000000000',  // 100000eth
        address: '0x8626f6940e2eb28930efb4cef49b2d1f2c9c1199',
        privateKey: '0xdf57089febbacf7ba0bc227dafbffa9fc08a93fdc68e1e42411a14efcf23656e',
      }, {
        // TEST_WALLET
        balance: '100000000000000000000',  // 100eth
        address: '0x85981B5db760B73FA8A6AA790c27a2C9e1BaB475',
        privateKey: '0x02ee76f5967730d26d5adda9a38d8bd6308a68d87cfef12fa0752fc209aae310',
      }],
    },
    localhost: {
      url: 'http://127.0.0.1:8545',
      // gasPrice: 30000000000,  // gwei
      timeout: 20 * 60 * 1000,
    },
    mainnet: {
      url: 'https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161',
      gasPrice: 30000000000,  // gwei
      accounts: [
        process.env.MAINNET_DEPLOYER_PRIVATEKEY || NULL_PRIVATE_KEY,
      ],
    },
    rinkeby: {
       url: 'https://rinkeby.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161',
      // url: `https://eth-rinkeby.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
      // gasPrice: 30000000000,  // gwei
      accounts: [
        process.env.TESTNET_DEPLOYER_PRIVATEKEY || NULL_PRIVATE_KEY,
      ],
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    whitelistVerificationAddress: {
      default: '0x944FC9Ba95a85b47cA79a147c988dF25494566ec',  // 0x000000000000000000000000000000000000000000000000000000000000FFFF
      1: '0x976f61940624C8EeA0F7D2E8852F3F7E32d25E26',  // NFT_WHITELIST_VERIFICATION_PRIVATE_KEY
      4: '0x976f61940624C8EeA0F7D2E8852F3F7E32d25E26',  // NFT_WHITELIST_VERIFICATION_PRIVATE_KEY
    },
  },
  paths: {
    sources: './src',
  },
};
