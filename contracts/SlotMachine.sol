// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title SlotMachine
 * @dev A simple 3x3 slot machine contract that works with ERC20 tokens
 */
contract SlotMachine is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Constants
    uint8 public constant REELS = 3;
    uint8 public constant ROWS = 3;
    uint8 public constant NUM_SYMBOLS = 6;

    // Token used for betting
    IERC20 public gameToken;

    // Game state
    uint256 public minBet;
    uint256 public maxBet;
    uint256 public houseEdgePercent; // In basis points (100 = 1%)
    uint256 public totalSpins;
    uint256 public totalWinAmount;
    uint256 public totalBetAmount;

    // Symbol configuration - packed into a single array for gas optimization
    // [0] = Cherry, [1] = Lemon, [2] = Orange, [3] = Plum, [4] = Bell, [5] = Seven
    uint16[NUM_SYMBOLS] public symbolWeights;
    uint16[NUM_SYMBOLS] public symbolPayouts; // Multipliers (in basis points - 100 = 1x)

    // Symbol names mapping
    mapping(uint8 => string) public symbolNames;
    
    // Player stats
    mapping(address => uint256) public playerSpins;
    mapping(address => uint256) public playerWinAmount;
    mapping(address => uint256) public playerBetAmount;
    
    // For hybrid randomness
    mapping(address => uint256) public playerNonce;

    // Events
    event SlotMachineDeployed(address owner, address token, uint256 minBet, uint256 maxBet, uint256 houseEdgePercent);
    event ConfigUpdated(uint256 minBet, uint256 maxBet, uint256 houseEdgePercent);
    event SymbolsConfigured(uint8 symbolId, string name, uint16 weight, uint16 payout);
    event Spin(
        address indexed player, 
        uint256 betAmount, 
        uint256 winAmount,
        uint8[REELS][ROWS] result,
        string userSeed
    );
    event Withdrawal(address indexed owner, uint256 amount);
    event TokenChanged(address oldToken, address newToken);

    // Custom errors
    error InvalidBetAmount(uint256 provided, uint256 min, uint256 max);
    error InsufficientContractBalance(uint256 required, uint256 available);
    error EmptySeedNotAllowed();
    error InvalidSymbolId(uint8 provided, uint8 max);
    error ZeroAddressNotAllowed();
    error InvalidPercentage(uint256 provided, uint256 max);
    error ZeroValueNotAllowed();
    error InsufficientAllowance(uint256 required, uint256 provided);

    /**
     * @dev Constructor
     * @param tokenAddress Address of the ERC20 token used for betting
     * @param initialMinBet Minimum bet amount
     * @param initialMaxBet Maximum bet amount
     * @param initialHouseEdgePercent House edge percentage (in basis points, 100 = 1%)
     */
    constructor(
        address tokenAddress,
        uint256 initialMinBet,
        uint256 initialMaxBet,
        uint256 initialHouseEdgePercent
    ) Ownable(msg.sender) {
        if (tokenAddress == address(0)) revert ZeroAddressNotAllowed();
        if (initialMinBet == 0) revert ZeroValueNotAllowed();
        if (initialMaxBet < initialMinBet) revert InvalidBetAmount(initialMaxBet, initialMinBet, type(uint256).max);
        if (initialHouseEdgePercent > 5000) revert InvalidPercentage(initialHouseEdgePercent, 5000); // Max 50%

        gameToken = IERC20(tokenAddress);
        minBet = initialMinBet;
        maxBet = initialMaxBet;
        houseEdgePercent = initialHouseEdgePercent;
        
        // Set default symbol configuration
        _configureDefaultSymbols();
        
        emit SlotMachineDeployed(msg.sender, tokenAddress, minBet, maxBet, houseEdgePercent);
    }

    /**
     * @dev Setup default symbols and payouts
     */
    function _configureDefaultSymbols() internal {
        // Define symbol weights (probabilities)
        symbolWeights[0] = 40;  // Cherry - 40% chance
        symbolWeights[1] = 30;  // Lemon - 30% chance
        symbolWeights[2] = 15;  // Orange - 15% chance
        symbolWeights[3] = 10;  // Plum - 10% chance
        symbolWeights[4] = 4;   // Bell - 4% chance
        symbolWeights[5] = 1;   // Seven - 1% chance

        // Define symbol payouts (as multipliers in basis points, 100 = 1x)
        symbolPayouts[0] = 110;   // Cherry - 1.1x
        symbolPayouts[1] = 120;   // Lemon - 1.2x
        symbolPayouts[2] = 250;   // Orange - 2.5x
        symbolPayouts[3] = 500;   // Plum - 5x
        symbolPayouts[4] = 1000;  // Bell - 10x
        symbolPayouts[5] = 5000;  // Seven - 50x

        // Set symbol names
        symbolNames[0] = "Cherry";
        symbolNames[1] = "Lemon";
        symbolNames[2] = "Orange";
        symbolNames[3] = "Plum";
        symbolNames[4] = "Bell";
        symbolNames[5] = "Seven";
        
        // Emit events for each symbol configuration
        for (uint8 i = 0; i < NUM_SYMBOLS; i++) {
            emit SymbolsConfigured(i, symbolNames[i], symbolWeights[i], symbolPayouts[i]);
        }
    }

    /**
     * @dev Function to play the slot machine
     * @param betAmount The amount to bet
     * @param userSeed Additional random seed provided by user
     */
    function spin(uint256 betAmount, string calldata userSeed) external nonReentrant {
        // Check if bet amount is valid
        if (betAmount < minBet || betAmount > maxBet) {
            revert InvalidBetAmount(betAmount, minBet, maxBet);
        }
        
        // Check if user seed is provided
        if (bytes(userSeed).length == 0) {
            revert EmptySeedNotAllowed();
        }
        
        // Transfer tokens from player to contract
        uint256 allowance = gameToken.allowance(msg.sender, address(this));
        if (allowance < betAmount) {
            revert InsufficientAllowance(betAmount, allowance);
        }
        gameToken.safeTransferFrom(msg.sender, address(this), betAmount);
        
        // Update player's nonce
        playerNonce[msg.sender]++;
        
        // Generate random result
        uint8[REELS][ROWS] memory result = generateRandomResult(userSeed);
        
        // Calculate winnings
        uint256 winMultiplier = calculateWinMultiplier(result);
        uint256 winAmount = (betAmount * winMultiplier) / 10000;
        
        // Apply house edge if player won
        if (winAmount > 0) {
            winAmount = (winAmount * (10000 - houseEdgePercent)) / 10000;
        }
        
        // Update statistics
        totalSpins++;
        totalBetAmount += betAmount;
        playerSpins[msg.sender]++;
        playerBetAmount[msg.sender] += betAmount;
        
        if (winAmount > 0) {
            totalWinAmount += winAmount;
            playerWinAmount[msg.sender] += winAmount;
            
            // Check contract balance
            uint256 contractBalance = gameToken.balanceOf(address(this));
            if (winAmount > contractBalance) {
                revert InsufficientContractBalance(winAmount, contractBalance);
            }
            
            // Send winnings to player
            gameToken.safeTransfer(msg.sender, winAmount);
        }
        
        // Emit event
        emit Spin(msg.sender, betAmount, winAmount, result, userSeed);
    }

    /**
     * @dev Generate random slot result
     * @param userSeed User provided seed for additional randomness
     * @return result A 3x3 array of symbols
     */
    function generateRandomResult(string calldata userSeed) internal view returns (uint8[REELS][ROWS] memory) {
        uint8[REELS][ROWS] memory result;
        
        // Mix multiple sources of entropy
        bytes32 randomSeed = keccak256(abi.encodePacked(
            blockhash(block.number - 1),
            block.timestamp,
            block.prevrandao,
            msg.sender,
            playerNonce[msg.sender],
            userSeed
        ));
        
        // Generate each position's random symbol
        for (uint8 row = 0; row < ROWS; row++) {
            for (uint8 reel = 0; reel < REELS; reel++) {
                // Use a different segment of randomSeed for each position
                randomSeed = keccak256(abi.encodePacked(randomSeed, row, reel));
                
                // Generate a random number and convert to symbol
                uint256 randValue = uint256(randomSeed);
                result[row][reel] = getWeightedRandomSymbol(randValue);
            }
        }
        
        return result;
    }
    
    /**
     * @dev Get a random symbol based on weights
     * @param seed Random seed value
     * @return symbol The selected symbol ID
     */
    function getWeightedRandomSymbol(uint256 seed) internal view returns (uint8) {
        // Calculate total weight
        uint16 totalWeight = 0;
        for (uint8 i = 0; i < NUM_SYMBOLS; i++) {
            totalWeight += symbolWeights[i];
        }
        
        // Get a random value between 0 and totalWeight
        uint16 randomWeight = uint16(seed % totalWeight);
        
        // Find which symbol this weight corresponds to
        uint16 weightSum = 0;
        for (uint8 i = 0; i < NUM_SYMBOLS; i++) {
            weightSum += symbolWeights[i];
            if (randomWeight < weightSum) {
                return i;
            }
        }
        
        // Fallback (should never happen)
        return 0;
    }
    
    /**
     * @dev Calculate win multiplier based on the result
     * @param result The 3x3 array of symbols
     * @return multiplier The win multiplier in basis points (100 = 1x)
     */
    function calculateWinMultiplier(uint8[REELS][ROWS] memory result) internal view returns (uint256) {
        uint256 multiplier = 0;
        
        // Check horizontal lines (3 rows)
        for (uint8 row = 0; row < ROWS; row++) {
            if (result[row][0] == result[row][1] && result[row][1] == result[row][2]) {
                multiplier += symbolPayouts[result[row][0]];
            }
        }
        
        // Check vertical lines (3 columns)
        for (uint8 col = 0; col < REELS; col++) {
            if (result[0][col] == result[1][col] && result[1][col] == result[2][col]) {
                multiplier += symbolPayouts[result[0][col]];
            }
        }
        
        // Check diagonal lines (2 diagonals)
        // Diagonal from top-left to bottom-right
        if (result[0][0] == result[1][1] && result[1][1] == result[2][2]) {
            multiplier += symbolPayouts[result[0][0]];
        }
        
        // Diagonal from top-right to bottom-left
        if (result[0][2] == result[1][1] && result[1][1] == result[2][0]) {
            multiplier += symbolPayouts[result[0][2]];
        }
        
        return multiplier;
    }

    /**
     * @dev Configure a symbol's properties
     * @param symbolId The symbol ID to configure
     * @param name The symbol name
     * @param weight The weight of the symbol (probability)
     * @param payout The payout multiplier in basis points (100 = 1x)
     */
    function configureSymbol(
        uint8 symbolId, 
        string calldata name, 
        uint16 weight, 
        uint16 payout
    ) external onlyOwner {
        if (symbolId >= NUM_SYMBOLS) revert InvalidSymbolId(symbolId, NUM_SYMBOLS - 1);
        
        symbolWeights[symbolId] = weight;
        symbolPayouts[symbolId] = payout;
        symbolNames[symbolId] = name;
        
        emit SymbolsConfigured(symbolId, name, weight, payout);
    }
    
    /**
     * @dev Update game configuration parameters
     * @param newMinBet New minimum bet amount
     * @param newMaxBet New maximum bet amount
     * @param newHouseEdgePercent New house edge percentage (basis points, 100 = 1%)
     */
    function updateGameConfig(
        uint256 newMinBet,
        uint256 newMaxBet,
        uint256 newHouseEdgePercent
    ) external onlyOwner {
        if (newMinBet == 0) revert ZeroValueNotAllowed();
        if (newMaxBet < newMinBet) revert InvalidBetAmount(newMaxBet, newMinBet, type(uint256).max);
        if (newHouseEdgePercent > 5000) revert InvalidPercentage(newHouseEdgePercent, 5000); // Max 50%
        
        minBet = newMinBet;
        maxBet = newMaxBet;
        houseEdgePercent = newHouseEdgePercent;
        
        emit ConfigUpdated(minBet, maxBet, houseEdgePercent);
    }
    
    /**
     * @dev Update the token used for the game
     * @param newTokenAddress The address of the new token
     */
    function updateGameToken(address newTokenAddress) external onlyOwner {
        if (newTokenAddress == address(0)) revert ZeroAddressNotAllowed();
        
        address oldToken = address(gameToken);
        gameToken = IERC20(newTokenAddress);
        
        emit TokenChanged(oldToken, newTokenAddress);
    }
    
    /**
     * @dev Withdraw tokens from the contract (owner only)
     * @param amount The amount to withdraw (0 for all)
     */
    function withdraw(uint256 amount) external onlyOwner {
        uint256 withdrawAmount = amount;
        uint256 contractBalance = gameToken.balanceOf(address(this));
        
        // If amount is 0, withdraw all
        if (withdrawAmount == 0) {
            withdrawAmount = contractBalance;
        }
        
        // Check contract balance
        if (withdrawAmount > contractBalance) {
            revert InsufficientContractBalance(withdrawAmount, contractBalance);
        }
        
        // Send tokens to owner
        gameToken.safeTransfer(owner(), withdrawAmount);
        
        emit Withdrawal(owner(), withdrawAmount);
    }
    
    /**
     * @dev Get contract token balance
     * @return The contract token balance
     */
    function getContractBalance() external view returns (uint256) {
        return gameToken.balanceOf(address(this));
    }
    
    /**
     * @dev Get player statistics
     * @param player The player address
     * @return spins Number of spins
     * @return betAmount Total bet amount
     * @return winAmount Total win amount
     */
    function getPlayerStats(address player) external view returns (
        uint256 spins,
        uint256 betAmount,
        uint256 winAmount
    ) {
        return (
            playerSpins[player],
            playerBetAmount[player],
            playerWinAmount[player]
        );
    }
    
    /**
     * @dev Get game configuration
     * @return token Token address
     * @return minBetAmount Minimum bet amount
     * @return maxBetAmount Maximum bet amount
     * @return edge House edge percentage (basis points)
     * @return balance Contract token balance
     */
    function getGameConfig() external view returns (
        address token,
        uint256 minBetAmount,
        uint256 maxBetAmount,
        uint256 edge,
        uint256 balance
    ) {
        return (
            address(gameToken),
            minBet,
            maxBet,
            houseEdgePercent,
            gameToken.balanceOf(address(this))
        );
    }
    
    /**
     * @dev Get game statistics
     * @return totalSpinCount Total number of spins
     * @return totalBet Total bet amount
     * @return totalWin Total win amount
     */
    function getGameStats() external view returns (
        uint256 totalSpinCount,
        uint256 totalBet,
        uint256 totalWin
    ) {
        return (
            totalSpins,
            totalBetAmount,
            totalWinAmount
        );
    }
}
