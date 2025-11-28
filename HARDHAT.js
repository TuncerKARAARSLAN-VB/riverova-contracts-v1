require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();
require('hardhat-gas-reporter');      // Gas usage reporting (for optimization)
require('solidity-coverage');         // Code coverage reporting (for testing maturity)

// Environment variables from .env file
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY;
const ALCHEMY_MUMBAI_URL = process.env.ALCHEMY_MUMBAI_URL;
const ALCHEMY_MAINNET_URL = process.env.ALCHEMY_MAINNET_URL;


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  // --- 1. SOLDIITY COMPILER CONFIGURATION ---
  solidity: {
    version: "0.8.19", // Stable and secure version
    settings: {
      optimizer: {
        enabled: true,
        runs: 200, // Standard optimization cycle count
      },
    },
  },
  
  // --- 2. NETWORK CONFIGURATION (POLYGON FOCUS) ---
  networks: {
    // Local test network setup
    hardhat: {
      chainId: 31337,
    },
    
    // Polygon Mumbai Testnet (Primary focus for V1 grant deployment/testing)
    mumbai: {
      url: ALCHEMY_MUMBAI_URL,
      // Check if PRIVATE_KEY exists before adding accounts
      accounts: PRIVATE_KEY ? [`0x${PRIVATE_KEY}`] : [],
      chainId: 80001,
      // Setting a fixed gas price (optional, but shows control)
      gasPrice: 20000000000, // 20 Gwei 
    },
    
    // Polygon Mainnet (Production environment)
    polygon: {
      url: ALCHEMY_MAINNET_URL,
      accounts: PRIVATE_KEY ? [`0x${PRIVATE_KEY}`] : [],
      chainId: 137,
    },
  },
  
  // --- 3. CONTRACT VERIFICATION ---
  etherscan: {
    apiKey: {
      polygonMumbai: POLYGONSCAN_API_KEY,
      polygon: POLYGONSCAN_API_KEY
    },
  },
  
  // --- 4. GAS REPORTER CONFIGURATION (NEW) ---
  gasReporter: {
    enabled: (process.env.REPORT_GAS) ? true : false, // Only runs if REPORT_GAS=true in .env
    currency: 'USD',
    coinmarketcap: process.env.COINMARKETCAP_API_KEY, // Optional: Uses a key for real-time price conversion
    token: 'MATIC', // Targets MATIC/Polygon for accurate cost reporting
    gasPrice: 20, // Gas price to use for cost estimation (in Gwei)
    outputFile: 'gas-report.txt',
  },
  
  // --- 5. DEVELOPER DIRECTORIES ---
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
};