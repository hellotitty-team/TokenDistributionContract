const hre = require("hardhat");
const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log(`Running on network: ${hre.network.name}`);
  
  // Get contract address from .env
  const SLUT_MACHINE_CONTRACT_ADDRESS = process.env.SLUT_MACHINE_CONTRACT_ADDRESS;
  
  if (!SLUT_MACHINE_CONTRACT_ADDRESS) {
    console.error("Please set SLUT_MACHINE_CONTRACT_ADDRESS in your .env file");
    process.exit(1);
  }
  
  try {
    // Get the signer (your account)
    const [signer] = await ethers.getSigners();
    console.log("Interacting with SlutMachine using account:", signer.address);
    
    // Get contract instance
    const slutMachineABI = require("../artifacts/contracts/SlutMachine.sol/SlutMachine.json").abi;
    const slutMachine = new ethers.Contract(SLUT_MACHINE_CONTRACT_ADDRESS, slutMachineABI, signer);
    
    // Get game configuration - config is returned as a tuple, not an object with named properties
    const config = await slutMachine.getGameConfig();
    console.log("\nSlut Machine Configuration:");
    console.log(`Game Token: ${config[0]}`); // token
    console.log(`Min Bet: ${ethers.formatEther(config[1].toString())} tokens`); // minBetAmount
    console.log(`Max Bet: ${ethers.formatEther(config[2].toString())} tokens`); // maxBetAmount
    console.log(`House Edge: ${config[3]}%`); // edge
    console.log(`Developer Profit: ${config[4]}%`); // devProfit
    console.log(`Developer Address: ${config[5]}`); // devAddress
    console.log(`Contract Balance: ${ethers.formatEther(config[6].toString())} tokens`); // balance
    
    // Get the game token to approve it
    const gameToken = new ethers.Contract(
      config[0], // token address is the first item in the config tuple
      ["function approve(address spender, uint256 amount) external returns (bool)",
       "function balanceOf(address account) external view returns (uint256)"],
      signer
    );
    
    // Check user balance
    const userBalance = await gameToken.balanceOf(signer.address);
    console.log(`\nYour token balance: ${ethers.formatEther(userBalance)}`);
    
    // Set bet amount (using minimum bet for safety)
    const betAmount = config[1]; // minBetAmount
    
    // Generate a random seed for the spin
    const userSeed = `seed-${Math.floor(Math.random() * 1000000)}`;
    
    console.log(`\nPreparing to spin with bet amount: ${ethers.formatEther(betAmount)} tokens`);
    
    // Approve tokens for the contract to use
    console.log("Approving tokens...");
    const approveTx = await gameToken.approve(SLUT_MACHINE_CONTRACT_ADDRESS, betAmount);
    await approveTx.wait();
    console.log("Tokens approved successfully");
    
    // Estimate gas for the spin transaction
    console.log("\nEstimating gas for spin transaction...");
    const gasEstimate = await slutMachine.spin.estimateGas(betAmount, userSeed);
    const gasPrice = await ethers.provider.getFeeData();
    const gasCost = gasEstimate * gasPrice.gasPrice;
    
    console.log(`Estimated gas units: ${gasEstimate.toString()}`);
    console.log(`Gas price: ${ethers.formatUnits(gasPrice.gasPrice, 'gwei')} gwei`);
    console.log(`Estimated gas cost: ${ethers.formatEther(gasCost)} ETH`);
    
    // Ask for confirmation before proceeding
    console.log("\nProceeding with the spin transaction...");
    
    // Spin the slot machine
    console.log("\nSpinning the SlutMachine...");
    const spinTx = await slutMachine.spin(betAmount, userSeed);
    
    // Wait for the transaction to be mined
    console.log("Waiting for transaction confirmation...");
    const receipt = await spinTx.wait();
    
    // Find the Spin event in the transaction logs
    const spinEvent = receipt.logs.find(log => {
      try {
        const parsed = slutMachine.interface.parseLog(log);
        return parsed?.name === "Spin";
      } catch (e) {
        return false;
      }
    });
    
    if (spinEvent) {
      const parsedEvent = slutMachine.interface.parseLog(spinEvent);
      const { player, betAmount, winAmount, result, userSeed } = parsedEvent.args;
      
      console.log("\n🎰 Spin Result 🎰");
      console.log(`Player: ${player}`);
      console.log(`Bet Amount: ${ethers.formatEther(betAmount)} tokens`);
      console.log(`Win Amount: ${ethers.formatEther(winAmount)} tokens`);
      
      // Display the 3x3 grid of symbols
      console.log("\nSymbols Grid:");
      for (let row = 0; row < 3; row++) {
        let rowStr = "";
        for (let col = 0; col < 3; col++) {
          const symbolId = result[row][col];
          // Get symbol name if available, otherwise show symbol ID
          let symbolDisplay;
          try {
            symbolDisplay = await slutMachine.symbolNames(symbolId);
          } catch (error) {
            symbolDisplay = `Symbol ${symbolId}`;
          }
          rowStr += symbolDisplay.padEnd(10);
        }
        console.log(rowStr);
      }
      
      if (winAmount > 0) {
        console.log("\n🎉 Congratulations! You won! 🎉");
      } else {
        console.log("\nBetter luck next time!");
      }
    } else {
      console.log("Couldn't find spin result in transaction logs");
    }
    
  } catch (error) {
    console.error("Error occurred:", error.message);
    
    if (error.message.includes("invalid project id")) {
      console.error("\n❌ Network Connection Error: Invalid project ID or API key");
      console.error("Please try one of the following solutions:");
      console.error("1. Run on the local Hardhat network: npx hardhat run scripts/spinSlutMachine.js --network localhost");
      console.error("2. Make sure you have a local node running: npx hardhat node");
      console.error("3. If using external networks like Ronin, configure API keys in your .env file");
    }
    
    if (error.data) {
      // Try to decode the error using the ABI
      try {
        const decodedError = ethers.utils.defaultAbiCoder.decode(
          ["string"], 
          ethers.utils.hexDataSlice(error.data, 4)
        );
        console.error("Decoded error:", decodedError);
      } catch (e) {
        console.error("Raw error data:", error.data);
      }
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 