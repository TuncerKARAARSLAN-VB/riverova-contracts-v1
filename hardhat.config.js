require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();

// Environment variables from .env file
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY;
const ALCHEMY_MUMBAI_URL = process.env.ALCHEMY_MUMBAI_URL;
const ALCHEMY_MAINNET_URL = process.env.ALCHEMY_MAINNET_URL;


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.19", 
    settings: {
      optimizer: {
        enabled: true,
        runs: 200, 
      },
    },
  },
  
  // Network configurations focusing on Polygon L2
  networks: {
    hardhat: {
      chainId: 31337,
    },
    
    // Polygon Mumbai Testnet (Recommended testing environment for L2)
    mumbai: {
      url: ALCHEMY_MUMBAI_URL,
      accounts: PRIVATE_KEY ? [`0x${PRIVATE_KEY}`] : [],
      chainId: 80001,
      gasPrice: 20000000000, 
    },
    
    // Polygon Mainnet (Live Deployment)
    polygon: {
      url: ALCHEMY_MAINNET_URL,
      accounts: PRIVATE_KEY ? [`0x${PRIVATE_KEY}`] : [],
      chainId: 137,
    },
  },
  
  // Contract verification settings (for Polygonscan)
  etherscan: {
    apiKey: {
      polygonMumbai: POLYGONSCAN_API_KEY,
      polygon: POLYGONSCAN_API_KEY
    },
  },
  
  // Developer directories
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
};
