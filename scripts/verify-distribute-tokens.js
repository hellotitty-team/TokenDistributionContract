// Verification script for DistributeTokens.sol
const hre = require("hardhat");

async function main() {
  // Replace with the address of your deployed contract
  const contractAddress = "YOUR_DEPLOYED_CONTRACT_ADDRESS";
  
  console.log(`Verifying contract at address: ${contractAddress}`);
  
  try {
    // Verify the contract on the blockchain explorer
    // Note: The constructor doesn't have any arguments
    await hre.run("verify:verify", {
      address: contractAddress,
      constructorArguments: [],
    });
    
    console.log("Contract verified successfully!");
  } catch (error) {
    console.error("Error during verification:", error);
  }
}

// Execute the verification
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 