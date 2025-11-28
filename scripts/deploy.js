const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

// --- Helper function to save deployment addresses and data ---
function saveDeploymentData(data) {
    const deploymentsDir = path.join(__dirname, "..", "deployments");
    
    // Create the deployments directory if it doesn't exist
    if (!fs.existsSync(deploymentsDir)) {
        fs.mkdirSync(deploymentsDir);
    }
    
    // Save the data to a JSON file
    const filePath = path.join(deploymentsDir, "deployment_output.json");
    try {
        fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
        console.log(`\nDeployment data successfully saved to ${filePath}`);
    } catch (error) {
        console.error("Failed to save deployment data:", error);
    }
}

async function main() {
    const [deployer] = await ethers.getSigners();
    const network = hre.network.name;

    console.log("-------------------------------------------------");
    console.log(`Deployment starting on network: ${network}`);
    console.log(`Deploying contracts with the account: ${deployer.address}`);
    // Optional: Log deployer balance to show gas cost awareness
    // console.log("Account balance:", (await deployer.getBalance()).toString());
    console.log("-------------------------------------------------");


    // 1. FETCH CONTRACT FACTORIES
    console.log("Fetching contract factories...");
    const NftCertificationFactory = await ethers.getContractFactory("RiverovaNftCertification_Draft");
    const DaoGovernanceFactory = await ethers.getContractFactory("RiverovaDaoGovernance_Draft");

    // 2. DEPLOY NFT CERTIFICATION CONTRACT
    console.log("Deploying RiverovaNftCertification_Draft...");
    const nftCertification = await NftCertificationFactory.deploy();
    await nftCertification.deployed();

    console.log(
        `✅ NFT Contract deployed to: ${nftCertification.address}`
    );

    // 3. DEPLOY DAO GOVERNANCE CONTRACT (Passing NFT address as dependency)
    console.log("Deploying RiverovaDaoGovernance_Draft...");
    const daoGovernance = await DaoGovernanceFactory.deploy(nftCertification.address);
    await daoGovernance.deployed();

    console.log(
        `✅ DAO Contract deployed to: ${daoGovernance.address}`
    );

    // 4. SAVE DEPLOYMENT DATA FOR FRONTEND INTEGRATION
    const deploymentData = {
        network: network,
        timestamp: new Date().toISOString(),
        daoContract: {
            address: daoGovernance.address,
            // In a real project, the ABI would be pulled from artifacts here
            // abi: artifacts.readArtifactSync("RiverovaDaoGovernance_Draft").abi,
        },
        nftContract: {
            address: nftCertification.address,
        }
    };
    
    saveDeploymentData(deploymentData);

    console.log("\nDeployment process finished successfully.");
}

// Execute the main function and handle errors
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});