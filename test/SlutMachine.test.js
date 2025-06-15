const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SlutMachine Contract", function () {
  let slutMachine;
  let gameToken;
  let owner;
  let player1;
  let player2;
  
  // Test configuration
  const TOKEN_SUPPLY = ethers.parseEther("1000000");
  const MIN_BET = ethers.parseEther("1");
  const MAX_BET = ethers.parseEther("100");
  const HOUSE_EDGE_PERCENT = 500; // 5% house edge
  const SYMBOLS = 6;
  // Define USER_SEED at the top level for consistent use across tests
  const USER_SEED = "test_seed_123";

  before(async function () {
    // Get signers
    [owner, player1, player2] = await ethers.getSigners();
  });

  beforeEach(async function () {
    // Deploy mock token for testing
    const MockToken = await ethers.getContractFactory("contracts/test/MockERC20.sol:MockERC20");
    gameToken = await MockToken.deploy("Game Token", "GAME", TOKEN_SUPPLY);
    
    // Transfer tokens to players for betting
    await gameToken.transfer(player1.address, ethers.parseEther("10000"));
    await gameToken.transfer(player2.address, ethers.parseEther("10000"));
    
    // Deploy the SlutMachine contract
    const SlutMachine = await ethers.getContractFactory("SlutMachine");
    slutMachine = await SlutMachine.deploy(
      gameToken.target,
      MIN_BET,
      MAX_BET,
      HOUSE_EDGE_PERCENT
    );
    
    // Fund the contract with tokens for potential payouts
    await gameToken.transfer(slutMachine.target, ethers.parseEther("50000"));
  });

  // Helper function to spin with proper approvals
  async function spinWithApproval(player, betAmount, userSeed) {
    // Approve token spending
    await gameToken.connect(player).approve(slutMachine.target, betAmount);
    
    // Spin
    return slutMachine.connect(player).spin(betAmount, userSeed);
  }

  describe("Deployment", function () {
    it("Should deploy with correct initial values", async function () {
      expect(await slutMachine.gameToken()).to.equal(gameToken.target);
      expect(await slutMachine.minBet()).to.equal(MIN_BET);
      expect(await slutMachine.maxBet()).to.equal(MAX_BET);
      expect(await slutMachine.houseEdgePercent()).to.equal(HOUSE_EDGE_PERCENT);
      expect(await slutMachine.owner()).to.equal(owner.address);
      expect(await slutMachine.REELS()).to.equal(3);
      expect(await slutMachine.ROWS()).to.equal(3);
      expect(await slutMachine.NUM_SYMBOLS()).to.equal(SYMBOLS);
    });
    
    it("Should have initialized default symbols", async function () {
      // Check all symbol configurations
      for (let i = 0; i < SYMBOLS; i++) {
        const name = await slutMachine.symbolNames(i);
        const weight = await slutMachine.symbolWeights(i);
        const payout = await slutMachine.symbolPayouts(i);
        
        // All values should be non-empty
        expect(name).to.not.equal("");
        expect(weight).to.be.gt(0);
        expect(payout).to.be.gt(0);
      }
      
      // Verify specific symbol data (spot check)
      expect(await slutMachine.symbolNames(0)).to.equal("Cherry");
      expect(await slutMachine.symbolNames(5)).to.equal("Seven");
    });
    
    it("Should revert deployment with invalid parameters", async function () {
      const SlutMachine = await ethers.getContractFactory("SlutMachine");
      
      // Test zero token address
      await expect(
        SlutMachine.deploy(ethers.ZeroAddress, MIN_BET, MAX_BET, HOUSE_EDGE_PERCENT)
      ).to.be.revertedWithCustomError(slutMachine, "ZeroAddressNotAllowed");
      
      // Test zero min bet
      await expect(
        SlutMachine.deploy(gameToken.target, 0, MAX_BET, HOUSE_EDGE_PERCENT)
      ).to.be.revertedWithCustomError(slutMachine, "ZeroValueNotAllowed");
      
      // Test max bet less than min bet
      await expect(
        SlutMachine.deploy(gameToken.target, MIN_BET, ethers.parseEther("0.5"), HOUSE_EDGE_PERCENT)
      ).to.be.revertedWithCustomError(slutMachine, "InvalidBetAmount");
      
      // Test excessive house edge
      await expect(
        SlutMachine.deploy(gameToken.target, MIN_BET, MAX_BET, 5001)
      ).to.be.revertedWithCustomError(slutMachine, "InvalidPercentage");
    });
  });

  describe("Game Configuration", function () {
    it("Should allow owner to update game configuration", async function () {
      const newMinBet = ethers.parseEther("2");
      const newMaxBet = ethers.parseEther("200");
      const newHouseEdge = 300; // 3%
      
      await slutMachine.updateGameConfig(newMinBet, newMaxBet, newHouseEdge);
      
      expect(await slutMachine.minBet()).to.equal(newMinBet);
      expect(await slutMachine.maxBet()).to.equal(newMaxBet);
      expect(await slutMachine.houseEdgePercent()).to.equal(newHouseEdge);
    });
    
    it("Should emit ConfigUpdated event when config is updated", async function () {
      const newMinBet = ethers.parseEther("2");
      const newMaxBet = ethers.parseEther("200");
      const newHouseEdge = 300; // 3%
      
      await expect(slutMachine.updateGameConfig(newMinBet, newMaxBet, newHouseEdge))
        .to.emit(slutMachine, "ConfigUpdated")
        .withArgs(newMinBet, newMaxBet, newHouseEdge);
    });
    
    it("Should revert when non-owner tries to update config", async function () {
      await expect(
        slutMachine.connect(player1).updateGameConfig(
          ethers.parseEther("2"),
          ethers.parseEther("200"),
          300
        )
      ).to.be.revertedWithCustomError(slutMachine, "OwnableUnauthorizedAccount");
    });
    
    it("Should allow owner to configure symbols", async function () {
      const symbolId = 0;
      const name = "NewSymbol";
      const weight = 25;
      const payout = 300; // 3x
      
      await slutMachine.configureSymbol(symbolId, name, weight, payout);
      
      expect(await slutMachine.symbolNames(symbolId)).to.equal(name);
      expect(await slutMachine.symbolWeights(symbolId)).to.equal(weight);
      expect(await slutMachine.symbolPayouts(symbolId)).to.equal(payout);
    });
    
    it("Should emit SymbolsConfigured event when symbols are updated", async function () {
      const symbolId = 1;
      const name = "NewSymbol";
      const weight = 25;
      const payout = 300; // 3x
      
      await expect(slutMachine.configureSymbol(symbolId, name, weight, payout))
        .to.emit(slutMachine, "SymbolsConfigured")
        .withArgs(symbolId, name, weight, payout);
    });
    
    it("Should revert when trying to configure invalid symbol", async function () {
      const invalidSymbolId = 10; // We only have 6 symbols
      
      await expect(
        slutMachine.configureSymbol(invalidSymbolId, "Test", 10, 200)
      ).to.be.revertedWithCustomError(slutMachine, "InvalidSymbolId");
    });
    
    it("Should allow owner to change game token", async function () {
      // Create a new token
      const NewToken = await ethers.getContractFactory("contracts/test/MockERC20.sol:MockERC20");
      const newToken = await NewToken.deploy("New Game Token", "NGAME", TOKEN_SUPPLY);
      
      await expect(slutMachine.updateGameToken(newToken.target))
        .to.emit(slutMachine, "TokenChanged")
        .withArgs(gameToken.target, newToken.target);
      
      expect(await slutMachine.gameToken()).to.equal(newToken.target);
    });
  });

  describe("Spin Functionality", function () {
    const BET_AMOUNT = ethers.parseEther("10");
    
    it("Should allow player to spin with valid bet", async function () {
      const tx = await spinWithApproval(player1, BET_AMOUNT, USER_SEED);
      const receipt = await tx.wait();
      
      // Check that a Spin event was emitted
      const spinEvent = receipt.logs.find(log => 
        slutMachine.interface.parseLog(log)?.name === "Spin"
      );
      expect(spinEvent).to.not.be.undefined;
      
      // Player spins should be incremented
      expect(await slutMachine.playerSpins(player1.address)).to.equal(1);
      
      // Total spins should be incremented
      expect(await slutMachine.totalSpins()).to.equal(1);
      
      // Player bet amount should be recorded
      expect(await slutMachine.playerBetAmount(player1.address)).to.equal(BET_AMOUNT);
      
      // Total bet amount should be incremented
      expect(await slutMachine.totalBetAmount()).to.equal(BET_AMOUNT);
    });
    
    it("Should increment player nonce on each spin", async function () {
      // Initially nonce should be 0
      expect(await slutMachine.playerNonce(player1.address)).to.equal(0);
      
      // First spin
      await spinWithApproval(player1, BET_AMOUNT, USER_SEED);
      expect(await slutMachine.playerNonce(player1.address)).to.equal(1);
      
      // Second spin
      await spinWithApproval(player1, BET_AMOUNT, USER_SEED + "2");
      expect(await slutMachine.playerNonce(player1.address)).to.equal(2);
    });
    
    it("Should revert when bet amount is below minimum", async function () {
      const lowBet = ethers.parseEther("0.5"); // Below MIN_BET
      
      await expect(
        spinWithApproval(player1, lowBet, USER_SEED)
      ).to.be.revertedWithCustomError(slutMachine, "InvalidBetAmount");
    });
    
    it("Should revert when bet amount exceeds maximum", async function () {
      const highBet = ethers.parseEther("150"); // Above MAX_BET
      
      await expect(
        spinWithApproval(player1, highBet, USER_SEED)
      ).to.be.revertedWithCustomError(slutMachine, "InvalidBetAmount");
    });
    
    it("Should revert when user seed is empty", async function () {
      await expect(
        spinWithApproval(player1, BET_AMOUNT, "")
      ).to.be.revertedWithCustomError(slutMachine, "EmptySeedNotAllowed");
    });
    
    it("Should revert when token allowance is insufficient", async function () {
      // No approval given
      await expect(
        slutMachine.connect(player1).spin(BET_AMOUNT, USER_SEED)
      ).to.be.revertedWithCustomError(slutMachine, "InsufficientAllowance");
    });
    
    it("Should store spin result in player history", async function () {
      await spinWithApproval(player1, BET_AMOUNT, USER_SEED);
      
      // Check that spin history has been recorded
      expect(await slutMachine.getPlayerSpinHistoryLength(player1.address)).to.equal(1);
      
      // Check the stored spin result
      const spinResult = await slutMachine.getPlayerSpinResult(player1.address, 0);
      expect(spinResult[1]).to.equal(BET_AMOUNT); // betAmount
      expect(spinResult[4]).to.equal(USER_SEED); // userSeed
    });
    
    it("Should limit spin history when maxHistoryPerPlayer is set", async function () {
      // Set history limit to 2
      await slutMachine.setMaxHistoryPerPlayer(2);
      
      // Do 3 spins
      await spinWithApproval(player1, BET_AMOUNT, USER_SEED + "1");
      await spinWithApproval(player1, BET_AMOUNT, USER_SEED + "2");
      await spinWithApproval(player1, BET_AMOUNT, USER_SEED + "3");
      
      // Check that only 2 results are stored
      expect(await slutMachine.getPlayerSpinHistoryLength(player1.address)).to.equal(2);
      
      // The oldest result should be removed
      const latestResult = await slutMachine.getPlayerSpinResult(player1.address, 1);
      expect(latestResult[4]).to.equal(USER_SEED + "3"); // Latest userSeed
    });
  });

  describe("Winnings and Payouts", function () {
    it("Should correctly pay out winnings when player wins", async function () {
      // We'll control the outcome by manipulating symbol weights to ensure a win
      // Set the first symbol to 100% chance and a 2x payout
      await slutMachine.configureSymbol(0, "AllWin", 100, 200);
      
      // Set all other symbols to 0% chance
      for (let i = 1; i < SYMBOLS; i++) {
        await slutMachine.configureSymbol(i, `Symbol${i}`, 0, 100);
      }
      
      const betAmount = ethers.parseEther("10");
      const playerInitialBalance = await gameToken.balanceOf(player1.address);
      
      // Spin with this rigged configuration - this should result in a win
      await spinWithApproval(player1, betAmount, USER_SEED);
      
      // Player should have received winnings
      const playerFinalBalance = await gameToken.balanceOf(player1.address);
      
      // The player should have more tokens than before (initial - bet + winnings > initial)
      expect(playerFinalBalance).to.be.gt(playerInitialBalance - betAmount);
    });
    
    it("Should apply house edge to winnings", async function () {
      // Set the first symbol to 100% chance with a fixed payout to create a deterministic test
      await slutMachine.configureSymbol(0, "AllWin", 100, 200); // 2x payout
      
      for (let i = 1; i < SYMBOLS; i++) {
        await slutMachine.configureSymbol(i, `Symbol${i}`, 0, 100);
      }
      
      const betAmount = ethers.parseEther("10");
      const houseEdge = await slutMachine.houseEdgePercent();
      
      // Record balances before spin
      const playerInitialBalance = await gameToken.balanceOf(player1.address);
      const contractInitialBalance = await gameToken.balanceOf(slutMachine.target);
      
      // Make the spin
      const tx = await spinWithApproval(player1, betAmount, USER_SEED);
      const receipt = await tx.wait();
      
      // Get player stats to see if they won
      const playerStats = await slutMachine.getPlayerStats(player1.address);
      const winAmount = playerStats[2]; // Win amount from player stats
      
      // Player should have won something (with our rigged game)
      expect(winAmount).to.be.gt(0);
      
      // Check player balance change
      const playerFinalBalance = await gameToken.balanceOf(player1.address);
      const contractFinalBalance = await gameToken.balanceOf(slutMachine.target);
      
      // Verify the balances add up
      // Player's balance change + contract's balance change should be 0
      expect(playerFinalBalance - playerInitialBalance + contractFinalBalance - contractInitialBalance)
        .to.equal(0);
      
      // The player's balance change should be: -betAmount + winAmount
      expect(playerFinalBalance).to.equal(playerInitialBalance - betAmount + winAmount);
    });
    
    it("Should revert when contract has insufficient balance for payout", async function () {
      // Create a new SlutMachine with minimal contract balance
      const SlutMachine = await ethers.getContractFactory("SlutMachine");
      const poorSlutMachine = await SlutMachine.deploy(
        gameToken.target,
        MIN_BET,
        MAX_BET,
        HOUSE_EDGE_PERCENT
      );
      
      // Fund with very little tokens
      await gameToken.transfer(poorSlutMachine.target, ethers.parseEther("1"));
      
      // Configure symbols for a guaranteed win with a very high payout
      await poorSlutMachine.configureSymbol(0, "BigWin", 100, 5000); // 50x payout
      for (let i = 1; i < SYMBOLS; i++) {
        await poorSlutMachine.configureSymbol(i, `Symbol${i}`, 0, 100);
      }
      
      // Try to spin with a large bet that would result in a payout larger than the contract balance
      const betAmount = ethers.parseEther("10");
      
      // Approve spending
      await gameToken.connect(player1).approve(poorSlutMachine.target, betAmount);
      
      // This should revert due to insufficient contract balance
      await expect(
        poorSlutMachine.connect(player1).spin(betAmount, USER_SEED)
      ).to.be.revertedWithCustomError(poorSlutMachine, "InsufficientContractBalance");
    });
  });

  describe("Admin Functions", function () {
    it("Should allow owner to withdraw tokens", async function () {
      const withdrawAmount = ethers.parseEther("1000");
      const initialOwnerBalance = await gameToken.balanceOf(owner.address);
      const initialContractBalance = await gameToken.balanceOf(slutMachine.target);
      
      await expect(slutMachine.withdraw(withdrawAmount))
        .to.emit(slutMachine, "Withdrawal")
        .withArgs(owner.address, withdrawAmount);
      
      const finalOwnerBalance = await gameToken.balanceOf(owner.address);
      const finalContractBalance = await gameToken.balanceOf(slutMachine.target);
      
      expect(finalOwnerBalance).to.equal(initialOwnerBalance + withdrawAmount);
      expect(finalContractBalance).to.equal(initialContractBalance - withdrawAmount);
    });
    
    it("Should allow owner to withdraw all tokens when amount is 0", async function () {
      const initialOwnerBalance = await gameToken.balanceOf(owner.address);
      const initialContractBalance = await gameToken.balanceOf(slutMachine.target);
      
      await slutMachine.withdraw(0); // Withdraw all
      
      const finalOwnerBalance = await gameToken.balanceOf(owner.address);
      const finalContractBalance = await gameToken.balanceOf(slutMachine.target);
      
      expect(finalOwnerBalance).to.equal(initialOwnerBalance + initialContractBalance);
      expect(finalContractBalance).to.equal(0);
    });
    
    it("Should revert when non-owner tries to withdraw", async function () {
      await expect(
        slutMachine.connect(player1).withdraw(ethers.parseEther("1000"))
      ).to.be.revertedWithCustomError(slutMachine, "OwnableUnauthorizedAccount");
    });
    
    it("Should revert when trying to withdraw more than available", async function () {
      const contractBalance = await gameToken.balanceOf(slutMachine.target);
      const excessiveAmount = contractBalance + 1n;
      
      await expect(
        slutMachine.withdraw(excessiveAmount)
      ).to.be.revertedWithCustomError(slutMachine, "InsufficientContractBalance");
    });
    
    it("Should allow owner to update max history per player", async function () {
      const newMaxHistory = 10;
      
      await expect(slutMachine.setMaxHistoryPerPlayer(newMaxHistory))
        .to.emit(slutMachine, "MaxHistoryUpdated")
        .withArgs(0, newMaxHistory);
      
      expect(await slutMachine.maxHistoryPerPlayer()).to.equal(newMaxHistory);
    });
  });

  describe("View Functions", function () {
    it("Should return correct player stats", async function () {
      const betAmount = ethers.parseEther("10");
      
      // Make a spin
      await spinWithApproval(player1, betAmount, USER_SEED);
      
      // Get player stats
      const stats = await slutMachine.getPlayerStats(player1.address);
      
      expect(stats[0]).to.equal(1); // Spins
      expect(stats[1]).to.equal(betAmount); // Bet amount
      expect(stats[2]).to.be.gte(0); // Win amount (could be 0 or more)
    });
    
    it("Should return correct game configuration", async function () {
      const config = await slutMachine.getGameConfig();
      
      expect(config[0]).to.equal(gameToken.target); // Token
      expect(config[1]).to.equal(MIN_BET); // Min bet
      expect(config[2]).to.equal(MAX_BET); // Max bet
      expect(config[3]).to.equal(HOUSE_EDGE_PERCENT); // House edge
      expect(config[4]).to.equal(await gameToken.balanceOf(slutMachine.target)); // Balance
    });
    
    it("Should return correct game stats", async function () {
      const betAmount = ethers.parseEther("20");
      
      // Make two spins with different players
      await spinWithApproval(player1, betAmount, USER_SEED);
      await spinWithApproval(player2, betAmount, USER_SEED + "different");
      
      // Get game stats
      const stats = await slutMachine.getGameStats();
      
      expect(stats[0]).to.equal(2); // Total spins
      expect(stats[1]).to.equal(betAmount * 2n); // Total bet
      // Total win amount could be anything from 0 to a large number
    });
    
    it("Should return correct contract balance", async function () {
      const balance = await slutMachine.getContractBalance();
      expect(balance).to.equal(await gameToken.balanceOf(slutMachine.target));
    });
  });

  describe("Player Spin History", function () {
    it("Should retrieve correct spin results with pagination", async function () {
      // Make multiple spins
      await spinWithApproval(player1, ethers.parseEther("10"), "seed1");
      await spinWithApproval(player1, ethers.parseEther("20"), "seed2");
      await spinWithApproval(player1, ethers.parseEther("30"), "seed3");
      await spinWithApproval(player1, ethers.parseEther("40"), "seed4");
      
      // Get paginated results (2 results starting from index 1)
      const results = await slutMachine.getPlayerSpinResults(player1.address, 1, 2);
      
      // Should have 2 results
      expect(results.length).to.equal(2);
      
      // Check specific results
      expect(results[0].betAmount).to.equal(ethers.parseEther("20")); // Second spin
      expect(results[0].userSeed).to.equal("seed2");
      
      expect(results[1].betAmount).to.equal(ethers.parseEther("30")); // Third spin
      expect(results[1].userSeed).to.equal("seed3");
    });
    
    it("Should revert when requesting invalid spin history index", async function () {
      // Make one spin
      await spinWithApproval(player1, ethers.parseEther("10"), USER_SEED);
      
      // Try to access invalid index
      await expect(
        slutMachine.getPlayerSpinResult(player1.address, 1) // Index 1 doesn't exist
      ).to.be.revertedWithCustomError(slutMachine, "InvalidIndex");
    });
  });
});

// Mock ERC20 Test
describe("MockERC20", function () {
  let mockToken;
  let owner;
  let user;

  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();
    
    // Create MockERC20 contract factory - using the fully qualified name
    const MockERC20 = await ethers.getContractFactory("contracts/test/MockERC20.sol:MockERC20");
    
    // Deploy the contract
    mockToken = await MockERC20.deploy("Mock Token", "MOCK", ethers.parseEther("1000000"));
  });

  it("Should deploy with correct initial values", async function () {
    expect(await mockToken.name()).to.equal("Mock Token");
    expect(await mockToken.symbol()).to.equal("MOCK");
    expect(await mockToken.decimals()).to.equal(18);
    expect(await mockToken.totalSupply()).to.equal(ethers.parseEther("1000000"));
    expect(await mockToken.balanceOf(owner.address)).to.equal(ethers.parseEther("1000000"));
  });

  it("Should allow minting new tokens", async function () {
    const mintAmount = ethers.parseEther("5000");
    const initialSupply = await mockToken.totalSupply();
    
    await mockToken.mint(user.address, mintAmount);
    
    expect(await mockToken.balanceOf(user.address)).to.equal(mintAmount);
    expect(await mockToken.totalSupply()).to.equal(initialSupply + mintAmount);
  });
}); 