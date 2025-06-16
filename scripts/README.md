# SlutMachine Spin Script

This script allows you to interact with the SlutMachine contract by spinning the virtual slot machine.

## Setup

1. Create a `.env` file in the root directory with the following variables:

```
# Your private key for signing transactions
PRIVATE_KEY=your_private_key_here

# SlutMachine contract address
SLUT_MACHINE_CONTRACT_ADDRESS=0x1234567890123456789012345678901234567890
```

2. Make sure you have compiled the contract:

```bash
npx hardhat compile
```

## Running the Script

### Option 1: Use a Local Hardhat Network (Recommended for Testing)

First, start a local node in a separate terminal:

```bash
npx hardhat node
```

Then run the script on the localhost network:

```bash
npx hardhat run scripts/spinSlutMachine.js --network localhost
```

### Option 2: Use Public Networks

To run on a specific network (e.g., ronin):

```bash
npx hardhat run scripts/spinSlutMachine.js --network ronin
```

> **Note:** For public networks like Ronin, make sure you have proper API keys configured if required.

## What the Script Does

1. Connects to the SlutMachine contract using the address from your `.env` file
2. Gets the contract configuration and displays it
3. Approves the minimum bet amount of tokens for spending
4. Spins the slot machine with a random seed
5. Displays the result of the spin including:
   - The bet amount
   - The win amount (if any)
   - The 3x3 grid of symbols
   
## Troubleshooting

### Common Errors

- **"Invalid JSON-RPC response received: invalid project id"**
  - This happens when you're trying to connect to a network that requires an API key but don't have one configured
  - Solution: Use the local Hardhat network or properly configure API keys

- **"Please set SLUT_MACHINE_CONTRACT_ADDRESS in your .env file"** 
  - Make sure you've created a `.env` file with the correct variable

- **"Error: insufficient funds"** 
  - Make sure your wallet has enough tokens and native currency (ETH/RON) for gas

- **"TypeError: Cannot read property 'token' of null"** 
  - Make sure the contract address is correct and the contract is deployed on the network you're using

### For Local Testing

If you're testing locally and need to deploy a test version of the contract:

1. Deploy the SlutMachine contract to your local network:
   ```bash
   npx hardhat run scripts/deploy.js --network localhost
   ```

2. Update your `.env` file with the deployed contract address

3. Make sure you have test tokens in your wallet to interact with the contract 