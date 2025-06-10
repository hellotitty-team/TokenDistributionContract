// Deploy script for DistributeTokens.sol
const hre = require("hardhat");

async function main() {
  console.log("Deploying DistributeTokens contract...");

  // Get the contract factory
  const DistributeTokens = await hre.ethers.getContractFactory("DistributeTokens");
  
  // Deploy the contract
  const distributeTokens = await DistributeTokens.deploy();
  
  // Wait for deployment to finish
  await distributeTokens.waitForDeployment();
  
  // Get the deployed contract address
  const distributeTokensAddress = await distributeTokens.getAddress();
  
  console.log(`DistributeTokens deployed to: ${distributeTokensAddress}`);
  console.log("Deployment transaction:", distributeTokens.deploymentTransaction().hash);
  
  console.log("\nAllocations:");
  const allocations = await distributeTokens.getAllocations();
  
  // Display all allocations
  for (let i = 0; i < allocations.length; i++) {
    const allocation = allocations[i];
    const percentage = (allocation.percentage / 100).toFixed(2);
    console.log(`- ${allocation.wallet}: ${percentage}%`);
  }
}

// Execute the deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 