# DistributeTokens Contract: Technical Documentation

## Contract Overview

The `DistributeTokens` contract is designed to automatically distribute ERC20 tokens according to predefined allocation percentages. The contract ensures transparency, immutability of distribution rules, and proper tracking of all token distributions.

## Key Features

1. **Immutable Allocations**: All recipient wallets and their percentage allocations are set during contract deployment and cannot be modified afterward.

2. **Automatic Distribution**: Any ERC20 tokens sent to the contract can be distributed with a single function call, dividing them among recipients according to the predefined percentages.

3. **Distribution Tracking**: The contract maintains a record of all distributions, allowing anyone to verify the amounts distributed to each recipient.

4. **Transparent Operation**: The contract exposes view functions that allow anyone to check the allocation percentages and distribution history.

5. **Secure Token Transfers**: Uses OpenZeppelin's SafeERC20 library to ensure secure token transfers and prevent certain types of attacks.

## Contract Structure

### State Variables

- `allocations`: An array of `Allocation` structs, each containing a wallet address and its percentage allocation.
- `distributedTokens`: A nested mapping that tracks how many tokens of each type have been distributed to each recipient.
- `TOTAL_PERCENTAGE`: A constant equal to 10000, representing 100% in basis points (100.00%).

### Structs

- `Allocation`: Contains two fields:
  - `wallet`: The recipient address
  - `percentage`: The allocation percentage in basis points (e.g., 3000 = 30%)

### Events

- `TokensDistributed`: Emitted when tokens are distributed, includes the token address and total amount.
- `AllocationDistributed`: Emitted for each individual allocation distribution, includes the token address, recipient address, and amount.

### Custom Errors

- `InvalidPercentages`: Thrown if the allocation percentages don't add up to 100%.
- `NoTokensToDistribute`: Thrown if there are no tokens to distribute.
- `ZeroAddress`: Thrown if the token address is zero.

## Function Details

### Constructor

```solidity
constructor()
```

The constructor sets up the initial allocation percentages and recipient wallets. It performs a validation check to ensure that all percentages add up to exactly 100% (10000 basis points).

The allocations established in the constructor are:
- Marketing wallet: 30% (3000 basis points)
- Charity for Breast Cancer: 20% (2000 basis points)
- Team & Advisors: 20% (2000 basis points)
- Community wallet: 10% (1000 basis points)
- Developer wallet: 10% (1000 basis points)
- Burn address (tokens permanently removed from circulation): 10% (1000 basis points)

### distributeTokens

```solidity
function distributeTokens(address token) external
```

This function distributes all tokens of the specified type currently held by the contract according to the allocation percentages:

1. Validates that the token address is not zero
2. Checks the contract's balance of the specified token
3. Verifies that the balance is greater than zero
4. For each allocation:
   - Calculates the amount to distribute based on the percentage
   - Updates the distribution tracking record
   - Transfers the tokens to the recipient
   - Emits an `AllocationDistributed` event
5. Emits a `TokensDistributed` event for the total distribution

### getAllocations

```solidity
function getAllocations() external view returns (Allocation[] memory)
```

This view function returns the complete array of allocations, allowing anyone to see all recipient wallets and their percentage allocations.

### getDistributedAmount

```solidity
function getDistributedAmount(address token, address recipient) external view returns (uint256)
```

This view function returns the total amount of a specific token that has been distributed to a specific recipient address, allowing anyone to verify past distributions.

## Security Considerations

1. **Immutable Allocations**: Once deployed, the allocation percentages and recipient wallets cannot be modified, preventing any manipulation of the distribution rules.

2. **No Manual Withdrawals**: The contract does not include any function that allows manual withdrawal of tokens to arbitrary addresses. Tokens can only be distributed according to the predefined percentages.

3. **Safe Token Transfers**: The contract uses OpenZeppelin's SafeERC20 library to prevent certain types of attacks during token transfers.

4. **Input Validation**: All inputs are validated to prevent common errors:
   - Token address is checked to ensure it's not the zero address
   - Token balance is verified before attempting distribution

## Usage Examples

### Distributing Tokens

To trigger the distribution of a specific token:

```solidity
// Example: Distributing TOKEN tokens
distributeTokens(0x1234567890123456789012345678901234567890);
```

### Checking Allocations

To view all allocation percentages and recipient wallets:

```solidity
// Returns the complete allocation array
getAllocations();
```

### Verifying Distributions

To check how many tokens have been distributed to a specific recipient:

```solidity
// Example: Checking how many TOKEN tokens have been distributed to a specific wallet
getDistributedAmount(0x1234567890123456789012345678901234567890, 0x0987654321098765432109876543210987654321);
``` 