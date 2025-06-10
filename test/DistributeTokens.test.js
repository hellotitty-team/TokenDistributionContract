const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DistributeTokens Contract", function () {
  let distributeTokens;
  let mockToken;
  let owner;
  let otherAccount;
  
  // Define the expected allocations based on the contract
  const expectedAllocations = [
    { wallet: "0x5953D009299f31fac1d7B08176Cc7a7A571405Cb", percentage: 3000 }, // Marketing
    { wallet: "0x30788484042272b05304A75038178c647f34F35d", percentage: 2000 }, // Charity
    { wallet: "0x4BC8dFCa3eB09C4587a50DA3254E6cD0Ea550F3D", percentage: 2000 }, // Team & Advisors
    { wallet: "0x91Fc532e2B7E2295865A790D03692e7141fD05F5", percentage: 1000 }, // Community
    { wallet: "0xaEeaA55ED4f7df9E4C5688011cEd1E2A1b696772", percentage: 1000 }, // Developer
    { wallet: "0x000000000000000000000000000000000000dEaD", percentage: 1000 }  // Burn
  ];

  // Deploy contracts before each test
  beforeEach(async function () {
    // Get signers
    [owner, otherAccount] = await ethers.getSigners();
    
    // Deploy a mock ERC20 token for testing
    const MockToken = await ethers.getContractFactory("MockERC20");
    mockToken = await MockToken.deploy("Mock Token", "MOCK", ethers.parseEther("1000000"));
    
    // Deploy the DistributeTokens contract
    const DistributeTokens = await ethers.getContractFactory("DistributeTokens");
    distributeTokens = await DistributeTokens.deploy();
  });

  // Create a MockERC20 contract for testing purposes
  it("Should deploy the contracts correctly", async function () {
    expect(await mockToken.name()).to.equal("Mock Token");
    expect(await mockToken.symbol()).to.equal("MOCK");
    expect(distributeTokens.target).to.not.equal(ethers.ZeroAddress);
  });

  describe("Allocations", function () {
    it("Should set correct allocations on deployment", async function () {
      const allocations = await distributeTokens.getAllocations();
      expect(allocations.length).to.equal(6);
      
      // Check each allocation
      for (let i = 0; i < allocations.length; i++) {
        expect(allocations[i].wallet).to.equal(expectedAllocations[i].wallet);
        expect(allocations[i].percentage).to.equal(expectedAllocations[i].percentage);
      }
    });
    
    it("Should have allocations that sum to 100%", async function () {
      const allocations = await distributeTokens.getAllocations();
      
      let totalPercentage = 0;
      for (let i = 0; i < allocations.length; i++) {
        totalPercentage += Number(allocations[i].percentage);
      }
      
      // Total should be 10000 (100.00%)
      expect(totalPercentage).to.equal(10000);
    });
  });

  describe("Token Distribution", function () {
    const INITIAL_SUPPLY = ethers.parseEther("1000");
    
    beforeEach(async function () {
      // Mint tokens and approve the distributor contract to spend them
      await mockToken.mint(owner.address, INITIAL_SUPPLY);
      await mockToken.transfer(distributeTokens.target, INITIAL_SUPPLY);
    });
    
    it("Should distribute tokens according to allocations", async function () {
      // Check initial balances before distribution
      expect(await mockToken.balanceOf(distributeTokens.target)).to.equal(INITIAL_SUPPLY);
      
      // Distribute tokens
      await distributeTokens.distributeTokens(mockToken.target);
      
      // Check that tokens were distributed according to percentages
      for (let i = 0; i < expectedAllocations.length; i++) {
        const expectedAmount = INITIAL_SUPPLY * BigInt(expectedAllocations[i].percentage) / 10000n;
        const actualBalance = await mockToken.balanceOf(expectedAllocations[i].wallet);
        expect(actualBalance).to.equal(expectedAmount);
        
        // Check tracking in the contract matches
        const distributedAmount = await distributeTokens.getDistributedAmount(
          mockToken.target, 
          expectedAllocations[i].wallet
        );
        expect(distributedAmount).to.equal(expectedAmount);
      }
      
      // Contract should have 0 balance after distribution
      expect(await mockToken.balanceOf(distributeTokens.target)).to.equal(0);
    });
    
    it("Should emit correct events on distribution", async function () {
      // Test that all expected events are emitted with a single distribution call
      // First, test the TokensDistributed event
      await expect(distributeTokens.distributeTokens(mockToken.target))
        .to.emit(distributeTokens, "TokensDistributed")
        .withArgs(mockToken.target, INITIAL_SUPPLY)
        // Check for the first allocation's event in the same transaction
        .and.to.emit(distributeTokens, "AllocationDistributed")
        .withArgs(
          mockToken.target, 
          expectedAllocations[0].wallet, 
          INITIAL_SUPPLY * BigInt(expectedAllocations[0].percentage) / 10000n
        );
    });
    
    it("Should revert if token address is zero", async function () {
      await expect(distributeTokens.distributeTokens(ethers.ZeroAddress))
        .to.be.revertedWithCustomError(distributeTokens, "ZeroAddress");
    });
    
    it("Should revert if no tokens to distribute", async function () {
      // Create new mock token with no balance
      const EmptyToken = await ethers.getContractFactory("MockERC20");
      const emptyToken = await EmptyToken.deploy("Empty Token", "EMPTY", 0);
      
      await expect(distributeTokens.distributeTokens(emptyToken.target))
        .to.be.revertedWithCustomError(distributeTokens, "NoTokensToDistribute");
    });
    
    it("Should correctly handle multiple distributions", async function () {
      // First distribution
      await distributeTokens.distributeTokens(mockToken.target);
      
      // Send more tokens to the contract
      const SECOND_AMOUNT = ethers.parseEther("500");
      await mockToken.mint(owner.address, SECOND_AMOUNT);
      await mockToken.transfer(distributeTokens.target, SECOND_AMOUNT);
      
      // Second distribution
      await distributeTokens.distributeTokens(mockToken.target);
      
      // Check cumulative distributed amounts
      for (let i = 0; i < expectedAllocations.length; i++) {
        const expectedAmount = 
          (INITIAL_SUPPLY + SECOND_AMOUNT) * BigInt(expectedAllocations[i].percentage) / 10000n;
        
        const distributedAmount = await distributeTokens.getDistributedAmount(
          mockToken.target, 
          expectedAllocations[i].wallet
        );
        
        expect(distributedAmount).to.equal(expectedAmount);
      }
    });
  });

  describe("View Functions", function () {
    it("Should correctly return all allocations", async function () {
      const allocations = await distributeTokens.getAllocations();
      expect(allocations.length).to.equal(expectedAllocations.length);
      
      for (let i = 0; i < allocations.length; i++) {
        expect(allocations[i].wallet).to.equal(expectedAllocations[i].wallet);
        expect(allocations[i].percentage).to.equal(expectedAllocations[i].percentage);
      }
    });
    
    it("Should correctly return distributed amount", async function () {
      // Initially all distributed amounts should be zero
      for (let i = 0; i < expectedAllocations.length; i++) {
        const amount = await distributeTokens.getDistributedAmount(
          mockToken.target, 
          expectedAllocations[i].wallet
        );
        expect(amount).to.equal(0);
      }
      
      // Transfer tokens and distribute
      const amount = ethers.parseEther("1000");
      await mockToken.mint(owner.address, amount);
      await mockToken.transfer(distributeTokens.target, amount);
      await distributeTokens.distributeTokens(mockToken.target);
      
      // Check distributed amounts
      for (let i = 0; i < expectedAllocations.length; i++) {
        const expectedAmount = amount * BigInt(expectedAllocations[i].percentage) / 10000n;
        const distributedAmount = await distributeTokens.getDistributedAmount(
          mockToken.target, 
          expectedAllocations[i].wallet
        );
        expect(distributedAmount).to.equal(expectedAmount);
      }
    });
  });
}); 