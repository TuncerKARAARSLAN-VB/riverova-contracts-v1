const { ethers } = require("hardhat");

async function main() {
  // 1. FETCH CONTRACT FACTORIES
  console.log("Fetching contract factories...");
  
  // Get the factory for the Riverova NFT Certification Contract
  const NftCertificationFactory = await ethers.getContractFactory("RiverovaNftCertification_Draft");
  
  // Get the factory for the Riverova DAO Governance Contract
  const DaoGovernanceFactory = await ethers.getContractFactory("RiverovaDaoGovernance_Draft");

  // 2. DEPLOY NFT CERTIFICATION CONTRACT
  // This is deployed first as it is a dependency for the DAO.
  console.log("Deploying RiverovaNftCertification_Draft...");
  const nftCertification = await NftCertificationFactory.deploy();
  await nftCertification.deployed();

  console.log(
    `RiverovaNftCertification_Draft deployed to: ${nftCertification.address}`
  );

  // 3. DEPLOY DAO GOVERNANCE CONTRACT
  // The DAO contract constructor requires the address of the NFT contract 
  // to verify Level 5+ voting eligibility, proving the system integration.
  console.log("Deploying RiverovaDaoGovernance_Draft...");
  const daoGovernance = await DaoGovernanceFactory.deploy(nftCertification.address);
  await daoGovernance.deployed();

  console.log(
    `RiverovaDaoGovernance_Draft deployed to: ${daoGovernance.address}`
  );

  // 4. DEPLOYMENT SUMMARY
  console.log("\nDeployment complete.");
  console.log("-----------------------------------------");
  console.log(`NFT Contract Address: ${nftCertification.address}`);
  console.log(`DAO Contract Address: ${daoGovernance.address}`);
  console.log("-----------------------------------------");

  // Optional: Add logic here to save the addresses to a JSON file for front-end access.
}

// Execute the main function and handle errors
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});