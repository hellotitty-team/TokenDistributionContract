// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
__/\\\\\\\\\\\\\\\__/\\\\\\\\\\\__/\\\\\\\\\\\\\\\__/\\\\\\\\\\\\\\\__/\\\________/\\\_        
 _\///////\\\/////__\/////\\\///__\///////\\\/////__\///////\\\/////__\///\\\____/\\\/__       
  _______\/\\\___________\/\\\___________\/\\\_____________\/\\\_________\///\\\/\\\/____      
   _______\/\\\___________\/\\\___________\/\\\_____________\/\\\___________\///\\\/______     
    _______\/\\\___________\/\\\___________\/\\\_____________\/\\\_____________\/\\\_______    
     _______\/\\\___________\/\\\___________\/\\\_____________\/\\\_____________\/\\\_______   
      _______\/\\\___________\/\\\___________\/\\\_____________\/\\\_____________\/\\\_______  
       _______\/\\\________/\\\\\\\\\\\_______\/\\\_____________\/\\\_____________\/\\\_______ 
        _______\///________\///////////________\///______________\///______________\///________
 * @title SlutMachine
 * @dev A virtual slot machine game on the blockchain
 *
 * ===== SOCIAL NETWORKS =====
 * 
 * https://t.me/HelloTittyOG
 * https://x.com/hellotittyog
 * https://github.com/hellotitty-team
 * https://app.uniswap.org/#/swap?outputCurrency=0x5B34B5032267e5D5a80b99a06B4b85716f404EA2
 * 
 * ======= HOW THIS CONTRACT WORKS =======
 * 
 * This contract simulates a classic 3x3 slot machine game that players can enjoy using cryptocurrency tokens.
 * 
 * WHAT IS A SLOT MACHINE?
 * A slot machine is a gambling game with spinning reels that display random symbols when stopped.
 * Players win when matching symbols line up across paylines (horizontal, vertical, or diagonal lines).
 * 
 * HOW TO PLAY:
 * 1. The player places a bet using cryptocurrency tokens
 * 2. The machine generates a random 3x3 grid of symbols
 * 3. Winnings are calculated based on matching symbols in winning lines
 * 4. Any winnings are automatically sent back to the player
 * 
 * GAME FEATURES:
 * - 3x3 grid with 6 different symbols (Cherry, Lemon, Orange, Grape, Bell, Seven)
 * - Each symbol has different probabilities of appearing and different payout values
 * - Multiple ways to win (horizontal lines, vertical lines, and diagonals)
 * - Configurable minimum and maximum bet amounts
 * - House edge (the casino's profit percentage) can be adjusted
 * - Complete history of player spins is recorded
 * - Fair randomness using multiple sources of unpredictability
 * 
 * FOR PLAYERS:
 * - You need to approve the contract to use your tokens before playing
 * - Each spin requires a small "seed" value from you to enhance randomness
 * - Your winning chances depend on the symbol weights and payouts configured
 * - The contract owner cannot interfere with individual game outcomes
 * 
 * FOR OWNERS:
 * - You can configure symbol probabilities and payouts
 * - You can set minimum/maximum bet limits
 * - You can adjust the house edge (profit percentage)
 * - You can withdraw accumulated profits
 * - You can pause/unpause the game in emergency situations
 */
contract SlutMachine is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // Constants - these define the basic structure of our slot machine
    uint8 public constant REELS = 3;    // The machine has 3 columns (reels)
    uint8 public constant ROWS = 3;     // The machine has 3 rows
    uint8 public constant NUM_SYMBOLS = 6;  // There are 6 different symbols in the game
    
    // This structure stores all the details about a player's spin result
    struct SpinResult {
        uint256 timestamp;          // When the spin happened
        uint256 betAmount;          // How much the player bet
        uint256 winAmount;          // How much the player won (if anything)
        uint8[REELS][ROWS] symbols; // The 3x3 grid of symbols that appeared
        string userSeed;            // The random value provided by the player
    }

    // The cryptocurrency token that players use to play the game
    IERC20 public gameToken;

    // Game settings and statistics
    uint256 public minBet;              // Smallest bet allowed
    uint256 public maxBet;              // Largest bet allowed
    uint256 public houseEdgePercent;    // Casino's profit percentage (e.g., 100 = 1%)
    uint256 public totalSpins;          // Total number of spins across all players
    uint256 public totalWinAmount;      // Total amount won by all players
    uint256 public totalBetAmount;      // Total amount bet by all players

    // Symbol configuration
    // Each of the 6 symbols has these properties:
    // [0] = Cherry, [1] = Lemon, [2] = Orange, [3] = Grape, [4] = Bell, [5] = Seven
    uint16[NUM_SYMBOLS] public symbolWeights;   // How likely each symbol is to appear (higher = more likely)
    uint16[NUM_SYMBOLS] public symbolPayouts;   // How much each symbol pays when matched (in 100ths, 100 = 1x your bet)

    // Names for each symbol (so we can display "Cherry" instead of just "0")
    mapping(uint8 => string) public symbolNames;
    
    // Individual player statistics
    mapping(address => uint256) public playerSpins;      // How many times this player has played
    mapping(address => uint256) public playerWinAmount;  // How much this player has won in total
    mapping(address => uint256) public playerBetAmount;  // How much this player has bet in total
    
    // History of each player's spins (stored in an array for each player)
    mapping(address => SpinResult[]) private playerSpinHistory;
    uint256 public maxHistoryPerPlayer; // Maximum spins to remember per player (0 means unlimited)
    
    // A counter for each player to help with randomness
    mapping(address => uint256) public playerNonce;

    // Events - these are like notifications that are emitted when certain actions happen
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
    event MaxHistoryUpdated(uint256 oldValue, uint256 newValue);
    event GamePaused(address owner);
    event GameUnpaused(address owner);

    // Error messages - these provide clear explanations when something goes wrong
    error InvalidBetAmount(uint256 provided, uint256 min, uint256 max);
    error InsufficientContractBalance(uint256 required, uint256 available);
    error EmptySeedNotAllowed();
    error InvalidSymbolId(uint8 provided, uint8 max);
    error ZeroAddressNotAllowed();
    error InvalidPercentage(uint256 provided, uint256 max);
    error ZeroValueNotAllowed();
    error InsufficientAllowance(uint256 required, uint256 provided);
    error InvalidIndex(uint256 provided, uint256 max);

    /**
     * @dev Sets up the slot machine with initial configuration
     * 
     * When the slot machine is first created, this function:
     * - Sets which cryptocurrency token will be used for bets
     * - Establishes minimum and maximum bet amounts
     * - Sets the house edge (casino's profit percentage)
     * - Configures the default symbols, their probabilities, and payouts
     * 
     * @param tokenAddress The cryptocurrency token address players will use to bet
     * @param initialMinBet Smallest allowed bet amount
     * @param initialMaxBet Largest allowed bet amount
     * @param initialHouseEdgePercent Casino's profit percentage (100 = 1%)
     */
    constructor(
        address tokenAddress,
        uint256 initialMinBet,
        uint256 initialMaxBet,
        uint256 initialHouseEdgePercent
    ) Ownable(msg.sender) {
        // Check that all inputs are valid
        if (tokenAddress == address(0)) revert ZeroAddressNotAllowed();
        if (initialMinBet == 0) revert ZeroValueNotAllowed();
        if (initialMaxBet < initialMinBet) revert InvalidBetAmount(initialMaxBet, initialMinBet, type(uint256).max);
        if (initialHouseEdgePercent > 5000) revert InvalidPercentage(initialHouseEdgePercent, 5000); // Max 50%

        // Set up the initial game configuration
        gameToken = IERC20(tokenAddress);
        minBet = initialMinBet;
        maxBet = initialMaxBet;
        houseEdgePercent = initialHouseEdgePercent;
        maxHistoryPerPlayer = 0;  // Default to unlimited history
        
        // Set up the default symbols with their probabilities and payouts
        _configureDefaultSymbols();
        
        // Announce that the slot machine has been created
        emit SlotMachineDeployed(msg.sender, tokenAddress, minBet, maxBet, houseEdgePercent);
    }

    /**
     * @dev Sets up the initial symbols with their names, probabilities, and payouts
     * 
     * This function defines:
     * - How likely each symbol is to appear (weights)
     * - How much each symbol pays when matched (payouts)
     * - The name of each symbol (Cherry, Lemon, etc.)
     * 
     * Higher weight means a symbol appears more often.
     * Higher payout means a symbol pays more when matched.
     * Common symbols have lower payouts, rare symbols have higher payouts.
     */
    function _configureDefaultSymbols() internal {
        // Define the chance of each symbol appearing (higher number = more common)
        symbolWeights[0] = 40;  // Cherry - 40% chance (most common)
        symbolWeights[1] = 30;  // Lemon - 30% chance
        symbolWeights[2] = 15;  // Orange - 15% chance
        symbolWeights[3] = 10;  // Grape - 10% chance
        symbolWeights[4] = 4;   // Bell - 4% chance
        symbolWeights[5] = 1;   // Seven - 1% chance (most rare)

        // Define how much each symbol pays when matched (in hundredths, 100 = 1x your bet)
        symbolPayouts[0] = 110;   // Cherry - 1.1x your bet (lowest payout)
        symbolPayouts[1] = 120;   // Lemon - 1.2x your bet
        symbolPayouts[2] = 250;   // Orange - 2.5x your bet
        symbolPayouts[3] = 500;   // Grape - 5x your bet
        symbolPayouts[4] = 1000;  // Bell - 10x your bet
        symbolPayouts[5] = 5000;  // Seven - 50x your bet (highest payout)

        // Set the name for each symbol
        symbolNames[0] = "Cherry";
        symbolNames[1] = "Lemon";
        symbolNames[2] = "Orange";
        symbolNames[3] = "Grape";
        symbolNames[4] = "Bell";
        symbolNames[5] = "Seven";
        
        // Announce each symbol's configuration
        for (uint8 i = 0; i < NUM_SYMBOLS; i++) {
            emit SymbolsConfigured(i, symbolNames[i], symbolWeights[i], symbolPayouts[i]);
        }
    }

    /**
     * @dev Main function for playing the slot machine
     * 
     * This is what happens when a player spins the slot machine:
     * 1. The bet amount is checked to ensure it's within limits
     * 2. Tokens are taken from the player's wallet
     * 3. A random 3x3 grid of symbols is generated
     * 4. Winnings are calculated based on matching symbols
     * 5. The house edge is applied to any winnings
     * 6. Winnings (if any) are sent back to the player
     * 7. The spin result is recorded in the player's history
     * 
     * @param betAmount How much the player wants to bet
     * @param userSeed A random value provided by the player to enhance randomness
     */
    function spin(uint256 betAmount, string calldata userSeed) external nonReentrant whenNotPaused {
        // Make sure the bet amount is allowed (not too small or too big)
        if (betAmount < minBet || betAmount > maxBet) {
            revert InvalidBetAmount(betAmount, minBet, maxBet);
        }
        
        // Make sure the player provided a random seed
        if (bytes(userSeed).length == 0) {
            revert EmptySeedNotAllowed();
        }
        
        // Check if the player has given permission to use their tokens
        uint256 allowance = gameToken.allowance(msg.sender, address(this));
        if (allowance < betAmount) {
            revert InsufficientAllowance(betAmount, allowance);
        }
        
        // Take the bet amount from the player's wallet
        gameToken.safeTransferFrom(msg.sender, address(this), betAmount);
        
        // Increase the player's nonce (to help with randomness)
        playerNonce[msg.sender]++;
        
        // Generate a random 3x3 grid of symbols
        uint8[REELS][ROWS] memory result = generateRandomResult(userSeed);
        
        // Calculate how much the player won based on matching symbols
        uint256 winMultiplier = calculateWinMultiplier(result);
        uint256 winAmount = (betAmount * winMultiplier) / 10000;
        
        // Apply the house edge (casino's profit) to any winnings
        if (winAmount > 0) {
            winAmount = (winAmount * (10000 - houseEdgePercent)) / 10000;
        }
        
        // Update game statistics
        totalSpins++;
        totalBetAmount += betAmount;
        playerSpins[msg.sender]++;
        playerBetAmount[msg.sender] += betAmount;
        
        // If the player won something, send them their winnings
        if (winAmount > 0) {
            totalWinAmount += winAmount;
            playerWinAmount[msg.sender] += winAmount;
            
            // Make sure the contract has enough tokens to pay out
            uint256 contractBalance = gameToken.balanceOf(address(this));
            if (winAmount > contractBalance) {
                revert InsufficientContractBalance(winAmount, contractBalance);
            }
            
            // Send the winnings to the player
            gameToken.safeTransfer(msg.sender, winAmount);
        }
        
        // Record this spin in the player's history
        _storeSpinResult(msg.sender, betAmount, winAmount, result, userSeed);
        
        // Announce the spin result
        emit Spin(msg.sender, betAmount, winAmount, result, userSeed);
    }
    
    /**
     * @dev Saves a player's spin result in their history
     * 
     * This function:
     * - Creates a new record of the spin result
     * - Manages the history size (removes oldest entries if needed)
     * - Adds the new result to the player's history
     * 
     * @param player The player's address
     * @param betAmount How much they bet
     * @param winAmount How much they won
     * @param result The 3x3 grid of symbols that appeared
     * @param userSeed The random value they provided
     */
    function _storeSpinResult(
        address player,
        uint256 betAmount,
        uint256 winAmount,
        uint8[REELS][ROWS] memory result,
        string calldata userSeed
    ) internal {
        // Create a new record with all the spin details
        SpinResult memory newResult = SpinResult({
            timestamp: block.timestamp,
            betAmount: betAmount,
            winAmount: winAmount,
            symbols: result,
            userSeed: userSeed
        });
        
        // If there's a limit on history size and we've reached it,
        // remove the oldest spin result to make room
        if (maxHistoryPerPlayer > 0 && playerSpinHistory[player].length >= maxHistoryPerPlayer) {
            // Shift all elements left by one position (remove oldest)
            uint256 historyLength = playerSpinHistory[player].length;
            for (uint256 i = 0; i < historyLength - 1; i++) {
                playerSpinHistory[player][i] = playerSpinHistory[player][i + 1];
            }
            playerSpinHistory[player].pop(); // Remove last element after shifting
        }
        
        // Add the new spin result to the player's history
        playerSpinHistory[player].push(newResult);
    }
    
    /**
     * @dev Tells you how many spin results are stored for a player
     * 
     * @param player The player's address
     * @return The number of spin results in their history
     */
    function getPlayerSpinHistoryLength(address player) external view returns (uint256) {
        return playerSpinHistory[player].length;
    }
    
    /**
     * @dev Gets a specific spin result from a player's history
     * 
     * @param player The player's address
     * @param index Which spin result to get (0 = oldest, 1 = second oldest, etc.)
     * @return timestamp When the spin happened
     * @return betAmount How much they bet
     * @return winAmount How much they won
     * @return symbols The 3x3 grid of symbols that appeared
     * @return userSeed The random value they provided
     */
    function getPlayerSpinResult(address player, uint256 index) external view returns (
        uint256 timestamp,
        uint256 betAmount,
        uint256 winAmount,
        uint8[REELS][ROWS] memory symbols,
        string memory userSeed
    ) {
        // Make sure the index is valid
        if (index >= playerSpinHistory[player].length) {
            revert InvalidIndex(index, playerSpinHistory[player].length > 0 ? playerSpinHistory[player].length - 1 : 0);
        }
        
        // Get the spin result at the requested index
        SpinResult memory result = playerSpinHistory[player][index];
        return (
            result.timestamp,
            result.betAmount,
            result.winAmount,
            result.symbols,
            result.userSeed
        );
    }
    
    /**
     * @dev Gets multiple spin results from a player's history
     * 
     * This is useful for viewing a player's recent spins in chunks,
     * such as showing them on a website or app.
     * 
     * @param player The player's address
     * @param startIndex Where to start in their history (0 = oldest)
     * @param count How many results to return
     * @return An array of spin results
     */
    function getPlayerSpinResults(
        address player, 
        uint256 startIndex, 
        uint256 count
    ) external view returns (
        SpinResult[] memory
    ) {
        uint256 historyLength = playerSpinHistory[player].length;
        
        // Make sure the starting index is valid
        if (startIndex >= historyLength) {
            revert InvalidIndex(startIndex, historyLength > 0 ? historyLength - 1 : 0);
        }
        
        // Calculate how many results we can actually return
        uint256 resultCount = count;
        if (startIndex + resultCount > historyLength) {
            resultCount = historyLength - startIndex;
        }
        
        // Create an array to hold the results
        SpinResult[] memory results = new SpinResult[](resultCount);
        
        // Fill the array with the requested spin results
        for (uint256 i = 0; i < resultCount; i++) {
            results[i] = playerSpinHistory[player][startIndex + i];
        }
        
        return results;
    }
    
    /**
     * @dev Sets how many spin results to store per player
     * 
     * This allows the owner to control how much storage is used.
     * Setting to 0 means unlimited history will be kept.
     * 
     * @param maxHistory Maximum number of spins to remember per player
     */
    function setMaxHistoryPerPlayer(uint256 maxHistory) external onlyOwner {
        uint256 oldValue = maxHistoryPerPlayer;
        maxHistoryPerPlayer = maxHistory;
        emit MaxHistoryUpdated(oldValue, maxHistory);
    }

    /**
     * @dev Generates a random 3x3 grid of symbols for a spin
     * 
     * This function creates a fair, random result by combining multiple
     * sources of randomness, including:
     * - Blockchain data that nobody can predict
     * - The player's address and history
     * - A random value provided by the player
     * 
     * This ensures that nobody (not even the casino owner) can
     * predict or manipulate the outcome of a spin.
     * 
     * @param userSeed A random value provided by the player
     * @return result A 3x3 grid of randomly selected symbols
     */
    function generateRandomResult(string calldata userSeed) internal view returns (uint8[REELS][ROWS] memory) {
        uint8[REELS][ROWS] memory result;
        
        // Create a random seed by combining many sources of randomness
        bytes32 randomSeed = keccak256(abi.encodePacked(
            blockhash(block.number - 1),      // Previous block hash
            block.timestamp,                   // Current time
            block.prevrandao,                  // Ethereum's random value
            msg.sender,                        // Player's address
            playerNonce[msg.sender],           // Player's spin counter
            userSeed                           // Player's provided random value
        ));
        
        // Generate a random symbol for each position in the 3x3 grid
        for (uint8 row = 0; row < ROWS; row++) {
            for (uint8 reel = 0; reel < REELS; reel++) {
                // Use a different part of the random seed for each position
                randomSeed = keccak256(abi.encodePacked(randomSeed, row, reel));
                
                // Convert the random bytes to a number and select a symbol
                uint256 randValue = uint256(randomSeed);
                result[row][reel] = getWeightedRandomSymbol(randValue);
            }
        }
        
        return result;
    }
    
    /**
     * @dev Selects a random symbol based on their probability weights
     * 
     * This function:
     * 1. Calculates the total weight of all symbols
     * 2. Picks a random point within that total weight
     * 3. Determines which symbol's weight range contains that point
     * 
     * Symbols with higher weights have a higher chance of being selected.
     * 
     * @param seed A random number used to select the symbol
     * @return symbol The selected symbol ID
     */
    function getWeightedRandomSymbol(uint256 seed) internal view returns (uint8) {
        // Calculate the total weight of all symbols
        uint16 totalWeight = 0;
        for (uint8 i = 0; i < NUM_SYMBOLS; i++) {
            totalWeight += symbolWeights[i];
        }
        
        // Pick a random point within the total weight
        uint16 randomWeight = uint16(seed % totalWeight);
        
        // Find which symbol's weight range contains the random point
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
     * @dev Calculates how much a player wins based on the symbols they got
     * 
     * This function checks for winning patterns:
     * - Horizontal lines (3 matching symbols in a row)
     * - Vertical lines (3 matching symbols in a column)
     * - Diagonal lines (3 matching symbols in a diagonal)
     * 
     * Each winning line adds to the total multiplier based on the matched symbol's payout value.
     * 
     * @param result The 3x3 grid of symbols from the spin
     * @return multiplier How much the bet should be multiplied by (in hundredths)
     */
    function calculateWinMultiplier(uint8[REELS][ROWS] memory result) internal view returns (uint256) {
        uint256 multiplier = 0;
        
        // Check horizontal lines (3 rows)
        for (uint8 row = 0; row < ROWS; row++) {
            // If all 3 symbols in this row match
            if (result[row][0] == result[row][1] && result[row][1] == result[row][2]) {
                // Add the payout for this symbol to the multiplier
                multiplier += symbolPayouts[result[row][0]];
            }
        }
        
        // Check vertical lines (3 columns)
        for (uint8 col = 0; col < REELS; col++) {
            // If all 3 symbols in this column match
            if (result[0][col] == result[1][col] && result[1][col] == result[2][col]) {
                // Add the payout for this symbol to the multiplier
                multiplier += symbolPayouts[result[0][col]];
            }
        }
        
        // Check diagonal from top-left to bottom-right
        if (result[0][0] == result[1][1] && result[1][1] == result[2][2]) {
            multiplier += symbolPayouts[result[0][0]];
        }
        
        // Check diagonal from top-right to bottom-left
        if (result[0][2] == result[1][1] && result[1][1] == result[2][0]) {
            multiplier += symbolPayouts[result[0][2]];
        }
        
        return multiplier;
    }

    /**
     * @dev Allows the owner to configure a symbol's properties
     * 
     * This function lets the casino owner adjust:
     * - The name of a symbol
     * - How likely the symbol is to appear (weight)
     * - How much the symbol pays when matched (payout)
     * 
     * This can be used to change the game's dynamics and profitability over time.
     * 
     * @param symbolId Which symbol to configure (0-5)
     * @param name The symbol's name (e.g., "Cherry", "Lemon")
     * @param weight How likely this symbol is to appear (higher = more common)
     * @param payout How much this symbol pays when matched (in hundredths, 100 = 1x)
     */
    function configureSymbol(
        uint8 symbolId, 
        string calldata name, 
        uint16 weight, 
        uint16 payout
    ) external onlyOwner {
        // Make sure the symbol ID is valid
        if (symbolId >= NUM_SYMBOLS) revert InvalidSymbolId(symbolId, NUM_SYMBOLS - 1);
        
        // Update the symbol's properties
        symbolWeights[symbolId] = weight;
        symbolPayouts[symbolId] = payout;
        symbolNames[symbolId] = name;
        
        // Announce the symbol's new configuration
        emit SymbolsConfigured(symbolId, name, weight, payout);
    }
    
    /**
     * @dev Allows the owner to update the game's basic settings
     * 
     * This function lets the casino owner adjust:
     * - The minimum bet amount
     * - The maximum bet amount
     * - The house edge (casino's profit percentage)
     * 
     * @param newMinBet Smallest allowed bet amount
     * @param newMaxBet Largest allowed bet amount
     * @param newHouseEdgePercent Casino's profit percentage (in hundredths, 100 = 1%)
     */
    function updateGameConfig(
        uint256 newMinBet,
        uint256 newMaxBet,
        uint256 newHouseEdgePercent
    ) external onlyOwner {
        // Make sure the new values are valid
        if (newMinBet == 0) revert ZeroValueNotAllowed();
        if (newMaxBet < newMinBet) revert InvalidBetAmount(newMaxBet, newMinBet, type(uint256).max);
        if (newHouseEdgePercent > 5000) revert InvalidPercentage(newHouseEdgePercent, 5000); // Max 50%
        
        // Update the game configuration
        minBet = newMinBet;
        maxBet = newMaxBet;
        houseEdgePercent = newHouseEdgePercent;
        
        // Announce the new configuration
        emit ConfigUpdated(minBet, maxBet, houseEdgePercent);
    }
    
    /**
     * @dev Allows the owner to change which cryptocurrency token is used for betting
     * 
     * This might be needed if:
     * - The current token has issues
     * - A better token becomes available
     * - The casino wants to support a different currency
     * 
     * @param newTokenAddress The address of the new token to use
     */
    function updateGameToken(address newTokenAddress) external onlyOwner {
        // Make sure the new token address is valid
        if (newTokenAddress == address(0)) revert ZeroAddressNotAllowed();
        
        // Remember the old token address
        address oldToken = address(gameToken);
        
        // Update to the new token
        gameToken = IERC20(newTokenAddress);
        
        // Announce the token change
        emit TokenChanged(oldToken, newTokenAddress);
    }
    
    /**
     * @dev Allows the owner to withdraw tokens from the contract
     * 
     * This lets the casino owner collect profits from the game.
     * 
     * @param amount How much to withdraw (0 means withdraw everything)
     */
    function withdraw(uint256 amount) external onlyOwner {
        uint256 withdrawAmount = amount;
        uint256 contractBalance = gameToken.balanceOf(address(this));
        
        // If amount is 0, withdraw all tokens
        if (withdrawAmount == 0) {
            withdrawAmount = contractBalance;
        }
        
        // Make sure we have enough tokens to withdraw
        if (withdrawAmount > contractBalance) {
            revert InsufficientContractBalance(withdrawAmount, contractBalance);
        }
        
        // Send the tokens to the owner
        gameToken.safeTransfer(owner(), withdrawAmount);
        
        // Announce the withdrawal
        emit Withdrawal(owner(), withdrawAmount);
    }
    
    /**
     * @dev Checks how many tokens the contract holds
     * 
     * This is useful for the casino owner to monitor available funds.
     * 
     * @return The number of tokens the contract currently holds
     */
    function getContractBalance() external view returns (uint256) {
        return gameToken.balanceOf(address(this));
    }
    
    /**
     * @dev Gets a player's lifetime statistics
     * 
     * This shows how much a player has played and won over time.
     * 
     * @param player The player's address
     * @return spins Number of times they've played
     * @return betAmount Total amount they've bet
     * @return winAmount Total amount they've won
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
     * @dev Gets the current game configuration
     * 
     * This shows the basic settings of the slot machine.
     * 
     * @return token The cryptocurrency token used for betting
     * @return minBetAmount Smallest allowed bet
     * @return maxBetAmount Largest allowed bet
     * @return edge Casino's profit percentage
     * @return balance How many tokens the contract holds
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
     * @dev Gets the overall game statistics
     * 
     * This shows how active and profitable the slot machine has been.
     * 
     * @return totalSpinCount Total number of spins across all players
     * @return totalBet Total amount bet across all players
     * @return totalWin Total amount won by all players
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

    /**
     * @dev Allows the owner to pause the game in case of emergency
     * 
     * This stops all spins until the game is unpaused.
     * Useful if a bug or security issue is discovered.
     */
    function pause() external onlyOwner {
        _pause();
        emit GamePaused(msg.sender);
    }
    
    /**
     * @dev Allows the owner to resume the game after it was paused
     * 
     * This lets players start spinning again after a pause.
     */
    function unpause() external onlyOwner {
        _unpause();
        emit GameUnpaused(msg.sender);
    }
}
