// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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
 * @title DistributeTokens
 * @notice This is a Token Distribution Contract
 * 
 * ===== OVERVIEW FOR NON-TECHNICAL READERS =====
 * 
 * What this contract does:
 * This contract automatically splits any tokens it receives among predefined wallet addresses
 * according to fixed percentages. Think of it like a treasure chest that, when opened,
 * automatically divides its contents among specific people based on rules that cannot be changed.
 * 
 * Key points to understand:
 * 
 * 1. FIXED DISTRIBUTION: The wallet addresses and their percentage allocations are permanently 
 *    set when this contract is deployed. They CANNOT be modified afterward. This ensures complete
 *    transparency and prevents any manipulation of the distribution.
 * 
 * 2. NO MANUAL WITHDRAWALS: There is NO function that allows anyone to manually withdraw tokens
 *    to an arbitrary address. The ONLY way tokens can leave this contract is through the 
 *    distributeTokens function, which follows the predefined percentage rules.
 *
 * 3. AUTOMATIC SPLITTING: When the distributeTokens function is called, it automatically
 *    calculates how many tokens each wallet should receive based on their percentage and
 *    sends the tokens accordingly.
 *
 * 4. DISTRIBUTION TRACKING: The contract keeps a record of all token distributions, making
 *    it possible to verify that tokens were distributed correctly.
 *
 * In simple terms, this contract acts as an automatic, tamper-proof distribution system
 * that cannot be changed after it's deployed.
 */
contract DistributeTokens {
    // This enables the safe transfer of tokens to prevent certain types of attacks
    using SafeERC20 for IERC20;

    // These are custom error messages that appear if something goes wrong
    error InvalidPercentages();    // Appears if percentages don't add up to 100%
    error NoTokensToDistribute();  // Appears if trying to distribute when there are no tokens
    error ZeroAddress();           // Appears if token address is missing

    // This defines what an "Allocation" is - a wallet address and its percentage
    struct Allocation {
        address wallet;            // The wallet address that will receive tokens
        uint256 percentage;        // The percentage this wallet gets (in basis points: 100% = 10000)
    }

    // A list of all the allocations (who gets what percentage)
    Allocation[] public allocations;

    // This keeps track of how many tokens have been distributed to each wallet address
    // It works like a spreadsheet where we record: [token type][recipient wallet] = amount sent
    mapping(address => mapping(address => uint256)) public distributedTokens;
    
    // This constant represents 100% in basis points (10000 = 100.00%)
    uint256 private constant TOTAL_PERCENTAGE = 10000;

    // These events are public announcements recorded on the blockchain when actions happen
    // They help with transparency and tracking what the contract has done
    event TokensDistributed(address indexed token, uint256 totalAmount);
    event AllocationDistributed(address indexed token, address indexed recipient, uint256 amount);

    /**
     * @dev This runs only once when the contract is created
     * 
     * IMPORTANT: The wallet addresses and percentages defined here are PERMANENT
     * and CANNOT be changed after the contract is deployed. This ensures that
     * the distribution rules cannot be manipulated.
     */
    constructor() {
        // Marketing wallet gets 30% of all tokens
        allocations.push(Allocation({
            wallet: 0x5953D009299f31fac1d7B08176Cc7a7A571405Cb,
            percentage: 3000 // 30%
        }));
        
        // Charity for Breast Cancer gets 20% of all tokens
        allocations.push(Allocation({
            wallet: 0x30788484042272b05304A75038178c647f34F35d,
            percentage: 2000 // 20%
        }));

        // Team & Advisors get 20% of all tokens
        allocations.push(Allocation({
            wallet: 0x4BC8dFCa3eB09C4587a50DA3254E6cD0Ea550F3D,
            percentage: 2000 // 20%
        }));
        
        // Community wallet gets 10% of all tokens
        allocations.push(Allocation({
            wallet: 0x91Fc532e2B7E2295865A790D03692e7141fD05F5,
            percentage: 1000 // 10%
        }));

        // Developer wallet gets 10% of all tokens
        allocations.push(Allocation({
            wallet: 0xaEeaA55ED4f7df9E4C5688011cEd1E2A1b696772,
            percentage: 1000 // 10%
        }));
        
        // 10% of tokens are permanently removed from circulation (burned)
        // The zero address is like a black hole - tokens sent here can never be recovered
        allocations.push(Allocation({
            wallet: 0x000000000000000000000000000000000000dEaD,
            percentage: 1000 // 10%
        }));

        // This checks that all percentages add up to exactly 100%
        // If they don't, the contract will fail to deploy
        uint256 totalPercentage;
        for (uint256 i = 0; i < allocations.length; i++) {
            totalPercentage += allocations[i].percentage;
        }
        
        if (totalPercentage != TOTAL_PERCENTAGE) {
            revert InvalidPercentages();
        }
    }

    /**
     * @notice This is the ONLY function that can distribute tokens from this contract
     * 
     * IMPORTANT: Tokens CANNOT be manually withdrawn to arbitrary addresses.
     * They can ONLY be distributed according to the predefined percentages
     * established when the contract was created.
     *
     * Anyone can call this function to trigger the distribution of a specific token.
     * The contract will automatically calculate how much each wallet should receive
     * based on their allocated percentage.
     *
     * @param token The address of the token you want to distribute
     */
    function distributeTokens(address token) external {
        // Check that a valid token address was provided
        if (token == address(0)) {
            revert ZeroAddress();
        }

        // Create a reference to the token and check how many tokens this contract holds
        IERC20 tokenInstance = IERC20(token);
        uint256 balance = tokenInstance.balanceOf(address(this));
        
        // If there are no tokens to distribute, stop and show an error
        if (balance == 0) {
            revert NoTokensToDistribute();
        }

        // Loop through each allocation and distribute tokens according to percentages
        for (uint256 i = 0; i < allocations.length; i++) {
            Allocation memory allocation = allocations[i];
            
            // Calculate how many tokens this wallet should receive
            // Example: If we have 1000 tokens and this wallet gets 30%, 
            // it would receive 300 tokens (1000 * 3000 / 10000)
            uint256 amount = (balance * allocation.percentage) / TOTAL_PERCENTAGE;
            
            if (amount > 0) {
                // Keep track of how many tokens have been sent to this wallet
                distributedTokens[token][allocation.wallet] += amount;
                
                // Send the tokens to the wallet
                tokenInstance.safeTransfer(allocation.wallet, amount);
                
                // Announce that tokens were sent to this wallet
                emit AllocationDistributed(token, allocation.wallet, amount);
            }
        }
        
        // Announce that all tokens have been distributed
        emit TokensDistributed(token, balance);
    }

    /**
     * @notice A function that lets anyone view all the allocation details at once
     * 
     * This provides transparency by allowing anyone to see exactly which wallets
     * receive tokens and what percentage each wallet gets.
     *
     * @return A list of all wallet addresses and their percentages
     */
    function getAllocations() external view returns (Allocation[] memory) {
        return allocations;
    }

    /**
     * @notice A function that lets anyone check how many tokens a specific wallet has received
     * 
     * This provides transparency by allowing anyone to verify past distributions.
     *
     * @param token The address of the token you want to check
     * @param recipient The wallet address you want to check
     * @return The total amount of tokens that have been distributed to that wallet
     */
    function getDistributedAmount(address token, address recipient) external view returns (uint256) {
        return distributedTokens[token][recipient];
    }
}
