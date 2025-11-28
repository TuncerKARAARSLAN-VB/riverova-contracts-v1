const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying Riverova contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.provider.getBalance(deployer.address)).toString());

  // Deploy RiverovaCertificate
  console.log("\n1. Deploying RiverovaCertificate...");
  const RiverovaCertificate = await hre.ethers.getContractFactory("RiverovaCertificate");
  const certificate = await RiverovaCertificate.deploy(deployer.address);
  await certificate.waitForDeployment();
  const certificateAddress = await certificate.getAddress();
  console.log("RiverovaCertificate deployed to:", certificateAddress);

  // Deploy RiverovaDAO
  console.log("\n2. Deploying RiverovaDAO...");
  const RiverovaDAO = await hre.ethers.getContractFactory("RiverovaDAO");
  const dao = await RiverovaDAO.deploy(deployer.address);
  await dao.waitForDeployment();
  const daoAddress = await dao.getAddress();
  console.log("RiverovaDAO deployed to:", daoAddress);

  // Deploy RiverovaEducation
  console.log("\n3. Deploying RiverovaEducation...");
  const RiverovaEducation = await hre.ethers.getContractFactory("RiverovaEducation");
  const education = await RiverovaEducation.deploy(deployer.address);
  await education.waitForDeployment();
  const educationAddress = await education.getAddress();
  console.log("RiverovaEducation deployed to:", educationAddress);

  // Configure contract references
  console.log("\n4. Configuring contract references...");
  await education.setCertificateContract(certificateAddress);
  console.log("Certificate contract set in Education registry");
  await education.setDAOContract(daoAddress);
  console.log("DAO contract set in Education registry");

  // Grant DAO_ROLE on Certificate contract to DAO
  const DAO_ROLE = await certificate.DAO_ROLE();
  await certificate.grantRole(DAO_ROLE, daoAddress);
  console.log("DAO_ROLE granted to DAO contract on Certificate");

  console.log("\n========================================");
  console.log("Deployment Complete!");
  console.log("========================================");
  console.log("Contract Addresses:");
  console.log("- RiverovaCertificate:", certificateAddress);
  console.log("- RiverovaDAO:", daoAddress);
  console.log("- RiverovaEducation:", educationAddress);
  console.log("========================================");

  return {
    certificate: certificateAddress,
    dao: daoAddress,
    education: educationAddress
  };
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
