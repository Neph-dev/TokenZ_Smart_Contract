// Import Hardhat and ethers
const { ethers } = require("hardhat");

async function main() {
    // Set up the contract factory
    const SocialX = await ethers.getContractFactory("SocialX");
    const [deployer] = await ethers.getSigners();

    // Deploy the contract
    const socialX = await SocialX.deploy();
    await socialX.waitForDeployment();

    console.log("SocialX contract deployed to:", socialX.getAddress());
    console.log("Deployed by:", deployer.getAddress());
}

// Execute the deployment
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });