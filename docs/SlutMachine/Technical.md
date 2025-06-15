# SlutMachine Technical Documentation

## Contract Overview

`SlutMachine.sol` is a Solidity smart contract that implements a 3x3 slot machine game using ERC20 tokens. The contract inherits from three OpenZeppelin contracts:

- `Ownable` - Provides access control functionality
- `ReentrancyGuard` - Prevents reentrancy attacks
- `Pausable` - Allows the contract to be paused/unpaused

## Constants and State Variables

### Game Constants

```solidity
uint8 public constant REELS = 3;
uint8 public constant ROWS = 3;
uint8 public constant NUM_SYMBOLS = 6;
```

### Game Configuration

```solidity
IERC20 public gameToken;           // ERC20 token used for betting
uint256 public minBet;             // Minimum bet amount
uint256 public maxBet;             // Maximum bet amount
uint256 public houseEdgePercent;   // In basis points (100 = 1%)
uint256 public maxHistoryPerPlayer; // Maximum spin results to store per player
```

### Game Statistics

```solidity
uint256 public totalSpins;         // Total number of spins across all players
uint256 public totalWinAmount;     // Total amount won by all players
uint256 public totalBetAmount;     // Total amount bet by all players
```

### Symbol Configuration

```solidity
uint16[NUM_SYMBOLS] public symbolWeights;  // Probability weights for each symbol
uint16[NUM_SYMBOLS] public symbolPayouts;  // Multipliers in basis points (100 = 1x)
mapping(uint8 => string) public symbolNames; // Names for each symbol
```

### Player Data

```solidity
mapping(address => uint256) public playerSpins;      // Number of spins by player
mapping(address => uint256) public playerWinAmount;  // Amount won by player
mapping(address => uint256) public playerBetAmount;  // Amount bet by player
mapping(address => SpinResult[]) private playerSpinHistory; // Spin history by player
mapping(address => uint256) public playerNonce;      // Player nonce for randomness
```

### Data Structures

```solidity
struct SpinResult {
    uint256 timestamp;      // When the spin occurred
    uint256 betAmount;      // Amount bet
    uint256 winAmount;      // Amount won
    uint8[REELS][ROWS] symbols; // The 3x3 grid of symbols
    string userSeed;        // User-provided randomness seed
}
```

## Key Functions

### Constructor

```solidity
constructor(
    address tokenAddress,
    uint256 initialMinBet,
    uint256 initialMaxBet,
    uint256 initialHouseEdgePercent
)
```

Initializes the contract with the specified token and game parameters. Also sets up default symbol configuration.

### Player-Facing Functions

#### `spin`

```solidity
function spin(uint256 betAmount, string calldata userSeed) external nonReentrant whenNotPaused
```

The main function for playing the game. It:
1. Validates the bet amount and user seed
2. Transfers tokens from player to contract
3. Generates random result using hybrid randomness
4. Calculates winnings based on matching symbols
5. Applies the house edge to any winnings
6. Updates game and player statistics
7. Transfers winnings to player (if any)
8. Stores the spin result in player history
9. Emits a `Spin` event

#### `getPlayerStats`

```solidity
function getPlayerStats(address player) external view returns (uint256 spins, uint256 betAmount, uint256 winAmount)
```

Returns a player's statistics: number of spins, total bet amount, and total win amount.

#### `getPlayerSpinHistoryLength`

```solidity
function getPlayerSpinHistoryLength(address player) external view returns (uint256)
```

Returns the number of stored spin results for a player.

#### `getPlayerSpinResult`

```solidity
function getPlayerSpinResult(address player, uint256 index) external view returns (...)
```

Returns a specific spin result for a player by index.

#### `getPlayerSpinResults`

```solidity
function getPlayerSpinResults(address player, uint256 startIndex, uint256 count) external view returns (SpinResult[] memory)
```

Returns multiple spin results for a player with pagination support.

### Owner-Only Functions

#### `configureSymbol`

```solidity
function configureSymbol(uint8 symbolId, string calldata name, uint16 weight, uint16 payout) external onlyOwner
```

Allows the owner to configure a symbol's name, weight (probability), and payout multiplier.

#### `updateGameConfig`

```solidity
function updateGameConfig(uint256 newMinBet, uint256 newMaxBet, uint256 newHouseEdgePercent) external onlyOwner
```

Updates the game's minimum bet, maximum bet, and house edge percentage.

#### `updateGameToken`

```solidity
function updateGameToken(address newTokenAddress) external onlyOwner
```

Changes the ERC20 token used for betting.

#### `withdraw`

```solidity
function withdraw(uint256 amount) external onlyOwner
```

Allows the owner to withdraw tokens from the contract. If amount is 0, withdraws all tokens.

#### `setMaxHistoryPerPlayer`

```solidity
function setMaxHistoryPerPlayer(uint256 maxHistory) external onlyOwner
```

Sets the maximum number of spin results to store per player (0 = unlimited).

#### `pause` and `unpause`

```solidity
function pause() external onlyOwner
function unpause() external onlyOwner
```

Allow the owner to pause and unpause the game.

### Internal Functions

#### `generateRandomResult`

```solidity
function generateRandomResult(string calldata userSeed) internal view returns (uint8[REELS][ROWS] memory)
```

Generates the random 3x3 grid of symbols using multiple entropy sources:
- Previous block hash
- Block timestamp
- Block prevrandao value (block difficulty)
- Player address
- Player nonce
- User-provided seed

#### `getWeightedRandomSymbol`

```solidity
function getWeightedRandomSymbol(uint256 seed) internal view returns (uint8)
```

Selects a random symbol based on the configured weights.

#### `calculateWinMultiplier`

```solidity
function calculateWinMultiplier(uint8[REELS][ROWS] memory result) internal view returns (uint256)
```

Calculates the win multiplier by checking for matching symbols in:
- 3 horizontal lines
- 3 vertical lines
- 2 diagonal lines

Each winning line adds its symbol's payout multiplier to the total.

#### `_storeSpinResult`

```solidity
function _storeSpinResult(address player, uint256 betAmount, uint256 winAmount, uint8[REELS][ROWS] memory result, string calldata userSeed) internal
```

Stores a spin result in the player's history, respecting the maximum history limit.

## Events

```solidity
event SlotMachineDeployed(address owner, address token, uint256 minBet, uint256 maxBet, uint256 houseEdgePercent);
event ConfigUpdated(uint256 minBet, uint256 maxBet, uint256 houseEdgePercent);
event SymbolsConfigured(uint8 symbolId, string name, uint16 weight, uint16 payout);
event Spin(address indexed player, uint256 betAmount, uint256 winAmount, uint8[REELS][ROWS] result, string userSeed);
event Withdrawal(address indexed owner, uint256 amount);
event TokenChanged(address oldToken, address newToken);
event MaxHistoryUpdated(uint256 oldValue, uint256 newValue);
event GamePaused(address owner);
event GameUnpaused(address owner);
```

## Custom Errors

```solidity
error InvalidBetAmount(uint256 provided, uint256 min, uint256 max);
error InsufficientContractBalance(uint256 required, uint256 available);
error EmptySeedNotAllowed();
error InvalidSymbolId(uint8 provided, uint8 max);
error ZeroAddressNotAllowed();
error InvalidPercentage(uint256 provided, uint256 max);
error ZeroValueNotAllowed();
error InsufficientAllowance(uint256 required, uint256 provided);
error InvalidIndex(uint256 provided, uint256 max);
```

## Integration Guide

### Deployment

To deploy the SlutMachine contract:

1. Deploy the contract with the following parameters:
   - `tokenAddress`: Address of the ERC20 token to be used for betting
   - `initialMinBet`: Minimum bet amount (in token's smallest unit)
   - `initialMaxBet`: Maximum bet amount (in token's smallest unit)
   - `initialHouseEdgePercent`: House edge percentage in basis points (e.g., 500 = 5%)

2. Fund the contract with enough tokens to cover potential payouts.

### Player Interaction

For players to interact with the contract:

1. Approve the SlutMachine contract to spend the player's tokens:
   ```solidity
   gameToken.approve(slutMachineAddress, amount);
   ```

2. Call the spin function:
   ```solidity
   slutMachine.spin(betAmount, "userProvidedSeed");
   ```

3. Listen for the `Spin` event to get the result.

### Admin Operations

For contract owners/admins:

1. Configure symbols as needed:
   ```solidity
   slutMachine.configureSymbol(symbolId, "SymbolName", weight, payout);
   ```

2. Update game parameters if required:
   ```solidity
   slutMachine.updateGameConfig(newMinBet, newMaxBet, newHouseEdgePercent);
   ```

3. Withdraw accumulated house edge:
   ```solidity
   slutMachine.withdraw(0); // 0 means withdraw all
   ```

## Security Considerations

1. The contract uses OpenZeppelin's `ReentrancyGuard` to prevent reentrancy attacks.

2. The contract follows the checks-effects-interactions pattern for secure token transfers.

3. Random number generation uses multiple entropy sources to improve unpredictability:
   - Previous block hash
   - Block timestamp
   - Block prevrandao value
   - Player address
   - Player nonce
   - User-provided seed

4. Custom errors provide clear feedback for failed transactions.

5. Access control via `Ownable` ensures only authorized users can modify game parameters.

6. `Pausable` functionality allows for emergency stops if issues are detected. 