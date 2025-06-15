# SlutMachine Standard Tests

This document provides detailed information about the standard tests implemented in `SlutMachine.test.js`. These tests verify the core functionality of the SlutMachine contract under normal operating conditions.

## Test Environment Setup

Each test runs with a fresh contract instance and the following configuration:

- **Token Supply**: 1,000,000 tokens
- **Minimum Bet**: 1 token
- **Maximum Bet**: 100 tokens
- **House Edge**: 5% (500 basis points)
- **Player Accounts**: 
  - Owner (contract deployer)
  - Player 1 (regular player)
  - Player 2 (second player for multi-user tests)
- **Initial Funding**: 
  - Players receive 10,000 tokens each
  - Contract receives 50,000 tokens for payouts

## Test Categories

### 1. Deployment Tests

These tests verify that the contract deploys correctly and initializes with the expected values.

| Test Name | Description | What It Verifies |
|-----------|-------------|-----------------|
| Should deploy with correct initial values | Checks all initial parameters are set correctly | Contract initializes properly with provided parameters |
| Should have initialized default symbols | Verifies all symbols are configured | Symbol names, weights, and payouts are properly set |
| Should revert deployment with invalid parameters | Attempts to deploy with invalid inputs | Contract correctly rejects zero address, zero min bet, max < min bet, and excessive house edge |

### 2. Game Configuration Tests

These tests verify that game settings can be updated correctly by the owner.

| Test Name | Description | What It Verifies |
|-----------|-------------|-----------------|
| Should allow owner to update game configuration | Updates min/max bets and house edge | Configuration parameters are updated correctly |
| Should emit ConfigUpdated event | Checks event emission on config update | Events are emitted with correct parameters |
| Should revert when non-owner tries to update config | Tests access control | Only owner can update configuration |
| Should allow owner to configure symbols | Updates a symbol's properties | Symbol configuration is updated correctly |
| Should emit SymbolsConfigured event | Checks event emission on symbol update | Events are emitted with correct parameters |
| Should revert when trying to configure invalid symbol | Tests invalid symbol ID | Contract rejects updates to non-existent symbols |
| Should allow owner to change game token | Changes the token address | Contract can be reconfigured to use a different token |

### 3. Spin Functionality Tests

These tests verify the core spinning functionality of the slot machine.

| Test Name | Description | What It Verifies |
|-----------|-------------|-----------------|
| Should allow player to spin with valid bet | Tests basic spin functionality | Players can spin, stats are updated correctly |
| Should increment player nonce on each spin | Checks nonce incrementation | Nonce increases with each spin for randomness |
| Should revert when bet amount is below minimum | Tests minimum bet enforcement | Contract rejects bets below minimum |
| Should revert when bet amount exceeds maximum | Tests maximum bet enforcement | Contract rejects bets above maximum |
| Should revert when user seed is empty | Tests seed validation | Contract requires a user-provided random seed |
| Should revert when token allowance is insufficient | Tests allowance check | Contract verifies token approval before spin |
| Should store spin result in player history | Verifies history recording | Spin results are properly stored in player history |
| Should limit spin history when maxHistoryPerPlayer is set | Tests history limitation | Old history entries are removed when limit is reached |

### 4. Winnings and Payouts Tests

These tests verify that winnings are calculated and paid out correctly.

| Test Name | Description | What It Verifies |
|-----------|-------------|-----------------|
| Should correctly pay out winnings when player wins | Tests winning scenario | Players receive correct winnings based on combinations |
| Should apply house edge to winnings | Tests house edge deduction | House edge percentage is correctly applied to winnings |
| Should revert when contract has insufficient balance for payout | Tests balance protection | Contract prevents paying more than it holds |

### 5. Admin Functions Tests

These tests verify administrative functions that are restricted to the contract owner.

| Test Name | Description | What It Verifies |
|-----------|-------------|-----------------|
| Should allow owner to withdraw tokens | Tests withdrawal | Owner can withdraw specific token amounts |
| Should allow owner to withdraw all tokens when amount is 0 | Tests full withdrawal | Zero amount withdraws all tokens |
| Should revert when non-owner tries to withdraw | Tests access control | Only owner can withdraw tokens |
| Should revert when trying to withdraw more than available | Tests balance check | Cannot withdraw more than contract balance |
| Should allow owner to update max history per player | Tests history config | Max history setting is updated correctly |

### 6. View Functions Tests

These tests verify read-only functions that provide information about the game and players.

| Test Name | Description | What It Verifies |
|-----------|-------------|-----------------|
| Should return correct player stats | Tests player statistics | Player stats are tracked and returned correctly |
| Should return correct game configuration | Tests game config view | Game configuration is returned correctly |
| Should return correct game stats | Tests game statistics | Game-wide statistics are tracked and returned correctly |
| Should return correct contract balance | Tests balance view | Contract balance is reported accurately |

### 7. Player Spin History Tests

These tests verify the tracking and retrieval of player spin history.

| Test Name | Description | What It Verifies |
|-----------|-------------|-----------------|
| Should retrieve correct spin results with pagination | Tests history pagination | Multiple spin results can be retrieved with pagination |
| Should revert when requesting invalid spin history index | Tests index validation | Invalid indices are rejected |

### 8. Pausable Functionality Tests

These tests verify that the game can be paused and unpaused by the owner.

| Test Name | Description | What It Verifies |
|-----------|-------------|-----------------|
| Should allow owner to pause the game | Tests pause functionality | Owner can pause the game |
| Should allow owner to unpause the game | Tests unpause functionality | Owner can unpause the game |
| Should revert spin when game is paused | Tests paused state | Spins are rejected when game is paused |
| Should allow spinning when game is unpaused | Tests unpaused state | Spins are accepted after unpause |
| Should revert when non-owner tries to pause | Tests access control | Only owner can pause the game |
| Should revert when non-owner tries to unpause | Tests access control | Only owner can unpause the game |

### 9. Mock Token Tests

These tests verify the proper functioning of the mock ERC20 token used for testing.

| Test Name | Description | What It Verifies |
|-----------|-------------|-----------------|
| Should deploy with correct initial values | Tests token deployment | Mock token initializes correctly |
| Should allow minting new tokens | Tests token minting | Token supply can be increased |

## Key Test Patterns

### Helper Functions

The tests use the following helper functions for common operations:

```javascript
// Helper function to spin with proper approvals
async function spinWithApproval(player, betAmount, userSeed) {
  // Approve token spending
  await gameToken.connect(player).approve(slutMachine.target, betAmount);
  
  // Spin
  return slutMachine.connect(player).spin(betAmount, userSeed);
}
```

### Test Structure

Each test follows a consistent pattern:

1. **Arrange**: Set up the test conditions
2. **Act**: Perform the action being tested
3. **Assert**: Verify the results match expectations

Example:
```javascript
it("Should increment player nonce on each spin", async function () {
  // Arrange - Initially nonce should be 0
  expect(await slutMachine.playerNonce(player1.address)).to.equal(0);
  
  // Act - First spin
  await spinWithApproval(player1, BET_AMOUNT, USER_SEED);
  
  // Assert - Check nonce increased
  expect(await slutMachine.playerNonce(player1.address)).to.equal(1);
  
  // Act - Second spin
  await spinWithApproval(player1, BET_AMOUNT, USER_SEED + "2");
  
  // Assert - Check nonce increased again
  expect(await slutMachine.playerNonce(player1.address)).to.equal(2);
});
```

## Event Testing

Many tests verify that events are emitted with correct parameters:

```javascript
await expect(slutMachine.updateGameConfig(newMinBet, newMaxBet, newHouseEdge))
  .to.emit(slutMachine, "ConfigUpdated")
  .withArgs(newMinBet, newMaxBet, newHouseEdge);
```

## Error Testing

Tests for error conditions verify that the correct error is thrown:

```javascript
await expect(
  slutMachine.connect(player1).withdraw(ethers.parseEther("1000"))
).to.be.revertedWithCustomError(slutMachine, "OwnableUnauthorizedAccount");
```

## Rigged Testing for Deterministic Outcomes

Several tests manipulate symbol weights to create deterministic outcomes for testing specific scenarios:

```javascript
// Set the first symbol to 100% chance and a 2x payout
await slutMachine.configureSymbol(0, "AllWin", 100, 200);

// Set all other symbols to 0% chance
for (let i = 1; i < SYMBOLS; i++) {
  await slutMachine.configureSymbol(i, `Symbol${i}`, 0, 100);
}
```

## Conclusion

The standard test suite provides comprehensive coverage of SlutMachine's expected behavior under normal conditions. These tests ensure that the contract's core functionality works correctly and safely, providing a solid foundation for the more extreme scenarios tested in the edge case suite. 