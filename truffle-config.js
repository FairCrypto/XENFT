const HDWalletProvider = require('@truffle/hdwallet-provider')
const dotenv = require("dotenv")

dotenv.config()
const infuraKey = process.env.INFURA_KEY || ''
const infuraSecret = process.env.INFURA_SECRET || ''
const liveNetworkPK = process.env.LIVE_PK || ''
const privKeysRinkeby = [ liveNetworkPK ]
const etherscanApiKey = process.env.ETHERS_SCAN_API_KEY || ''
const polygonApiKey = process.env.POLYGON_SCAN_API_KEY || ''
const bscApiKey = process.env.BSC_SCAN_API_KEY || ''
const snowtraceApiKey = process.env.SNOWTRACE_API_KEY || ''

module.exports = {
  networks: {
    test: {
      gasLimit: 30_000_000_000,
    },
    ganache: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "222222222",
      websocket: true,
      gasLimit: 15_000_000_000,
      //from: '0x0E4F1eB5c6c1ae7D6B7B2A8FcbCB4627644ad51E'
    },
    goerli: {
      provider: () => new HDWalletProvider({
        privateKeys: privKeysRinkeby,
        providerOrUrl: `https://:${infuraSecret}@goerli.infura.io/v3/${infuraKey}`,
        //providerOrUrl: `wss://:${infuraSecret}@goerli.infura.io/ws/v3/${infuraKey}`,
        pollingInterval: 56000
      }),
      network_id: 5,
      confirmations: 2,
      timeoutBlocks: 100,
      gas: 12_000_000,
      maxPriorityFeePerGas: 2_000_000_000,
      maxFeePerGas: 30_000_000_000,
      skipDryRun: true,
      // from: '0x6B889Dcfad1a6ddf7dE3bC9417F5F51128efc964',
      networkCheckTimeout: 999999
    },
    bsc_testnet: {
      provider: () => new HDWalletProvider({
        privateKeys: privKeysRinkeby,
        providerOrUrl: `https://data-seed-prebsc-1-s1.binance.org:8545`,
        pollingInterval: 56000
      }),
      network_id: 97,
      confirmations: 2,
      timeoutBlocks: 100,
      from: '0x6B889Dcfad1a6ddf7dE3bC9417F5F51128efc964',
      skipDryRun: true,
      networkCheckTimeout: 999999
    },
    pulsechain_testnet: {
      provider: () => new HDWalletProvider({
        privateKeys: privKeysRinkeby,
        providerOrUrl: `https://rpc.v3.testnet.pulsechain.com`,
        pollingInterval: 56000
      }),
      network_id: 942,
      confirmations: 2,
      timeoutBlocks: 100,
      skipDryRun: true,
      from: '0x6B889Dcfad1a6ddf7dE3bC9417F5F51128efc964',
      networkCheckTimeout: 999999
    },
    ethw_testnet: {
      provider: () => new HDWalletProvider({
        privateKeys: privKeysRinkeby,
        providerOrUrl: `https://iceberg.ethereumpow.org/`,
        pollingInterval: 56000
      }),
      network_id: 10002,
      confirmations: 2,
      timeoutBlocks: 100,
      skipDryRun: true,
      from: '0x6B889Dcfad1a6ddf7dE3bC9417F5F51128efc964',
      networkCheckTimeout: 999999
    },
    mumbai: {
      provider: () => new HDWalletProvider({
        privateKeys: privKeysRinkeby,
        providerOrUrl: `https://rpc.ankr.com/polygon_mumbai`,
        //providerOrUrl: `https://rpc.ankr.com/polygon_mumbai`,
        pollingInterval: 56000
      }),
      network_id: 80001, //
      confirmations: 2,
      timeoutBlocks: 200,
      pollingInterval: 1000,
      skipDryRun: true,
      from: '0x6B889Dcfad1a6ddf7dE3bC9417F5F51128efc964',
      networkCheckTimeout: 999999
      //websockets: true
    },
    polygon: {
      provider: () => new HDWalletProvider({
        privateKeys: privKeysRinkeby,
        providerOrUrl: `https://rpc.ankr.com/polygon`,
        //providerOrUrl: `https://rpc.ankr.com/polygon_mumbai`,
        pollingInterval: 56000
      }),
      network_id: 137, //
      confirmations: 2,
      timeoutBlocks: 200,
      pollingInterval: 1000,
      skipDryRun: true,
      from: '0x6B889Dcfad1a6ddf7dE3bC9417F5F51128efc964',
      networkCheckTimeout: 999999
      //websockets: true
    },
    optimism: {
      provider: () => new HDWalletProvider({
        privateKeys: privKeysRinkeby,
        providerOrUrl: `https://optimism-mainnet.infura.io/v3/3e8615a3d89b49f381108b46b52f9712`,
        pollingInterval: 56000
      }),
      network_id: 10,
      confirmations: 2,
      timeoutBlocks: 200,
      pollingInterval: 1000,
      skipDryRun: true,
      from: '0x6B889Dcfad1a6ddf7dE3bC9417F5F51128efc964',
      networkCheckTimeout: 999999
      //websockets: true
    },
    optimism_goerli: {
      provider: () => new HDWalletProvider({
        privateKeys: privKeysRinkeby,
        providerOrUrl: `https://optimism-goerli.infura.io/v3/3e8615a3d89b49f381108b46b52f9712`,
        pollingInterval: 56000
      }),
      network_id: 420,
      confirmations: 2,
      timeoutBlocks: 200,
      pollingInterval: 1000,
      skipDryRun: true,
      from: '0x6B889Dcfad1a6ddf7dE3bC9417F5F51128efc964',
      networkCheckTimeout: 999999
      //websockets: true
    },
    arbitrum_goerli: {
      provider: () => new HDWalletProvider({
        privateKeys: privKeysRinkeby,
        providerOrUrl: `https://arbitrum-goerli.infura.io/v3/0c4485eb5a0f416d9beb05cd14efd01a`,
        pollingInterval: 56000
      }),
      network_id: 421613,
      confirmations: 2,
      timeoutBlocks: 200,
      pollingInterval: 1000,
      skipDryRun: true,
      from: '0x6B889Dcfad1a6ddf7dE3bC9417F5F51128efc964',
      networkCheckTimeout: 999999
      //websockets: true
    },
    dashboard: {
      networkCheckTimeout: 30000,
      confirmations: 2,
      timeoutBlocks: 200,
      pollingInterval: 1000
    }
  },
  mocha: {
    timeout: 100_000
  },
  compilers: {
    solc: {
      version: "0.8.17",
      settings: {
        optimizer: {
          enabled: true,
          runs: 20
        },
        evmVersion: "london"
      }
    }
  },
  db: {
    enabled: false
  },
  dashboard: {
    port: 24012,
  },
  plugins: ['truffle-plugin-verify'],
  api_keys: {
    etherscan: etherscanApiKey,
    bscscan: bscApiKey,
    polygonscan: polygonApiKey,
    snowtrace: snowtraceApiKey
  }
};
