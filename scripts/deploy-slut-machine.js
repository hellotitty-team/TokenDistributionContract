// Deploy script for SlutMachine.sol
const hre = require("hardhat");

async function main() {
  console.log("Deploying SlutMachine contract...");

  // Get the contract factory
  const SlutMachine = await hre.ethers.getContractFactory("SlutMachine");

  // Define constructor parameters
  // You'll need to replace these values with your desired configuration
  const tokenAddress = "0x..."; // Replace with actual token address
  const initialMinBet = hre.ethers.parseEther("0.01"); // Min bet - 0.01 tokens
  const initialMaxBet = hre.ethers.parseEther("1.0"); // Max bet - 1 token
  const initialHouseEdgePercent = 300; // 3% house edge (300 basis points)

  console.log(`Deploying with parameters:
  - Token Address: ${tokenAddress}
  - Min Bet: ${hre.ethers.formatEther(initialMinBet)} tokens
  - Max Bet: ${hre.ethers.formatEther(initialMaxBet)} tokens
  - House Edge: ${initialHouseEdgePercent/100}%`);

  // Deploy the contract
  const slutMachine = await SlutMachine.deploy(
    tokenAddress,
    initialMinBet,
    initialMaxBet,
    initialHouseEdgePercent
  );

  // Wait for deployment to finish
  await slutMachine.waitForDeployment();

  // Get the deployed contract address
  const slutMachineAddress = await slutMachine.getAddress();

  console.log(`SlutMachine deployed to: ${slutMachineAddress}`);
  console.log("Deployment transaction:", slutMachine.deploymentTransaction().hash);
  
  // Log default symbols configuration
  console.log("\nDefault Symbol Configuration:");
  const symbolCount = await slutMachine.NUM_SYMBOLS();
  
  for (let i = 0; i < symbolCount; i++) {
    const name = await slutMachine.symbolNames(i);
    const weight = await slutMachine.symbolWeights(i);
    const payout = await slutMachine.symbolPayouts(i) / 100; // Convert basis points to multiplier
    
    console.log(`- ${name}: Weight ${weight}%, Payout ${payout}x`);
  }
}

// Execute the deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 