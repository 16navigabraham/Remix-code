import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";

describe("Dispersion", function () {
  let dispersion: any;
  let token: any;
  let owner: Signer;
  let addr1: Signer;
  let addr2: Signer;
  let addr3: Signer;
  
  beforeEach(async function () {
    // Get signers
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    
    // Deploy TestToken
    const TestToken = await ethers.getContractFactory("TestToken");
    token = await TestToken.deploy("TestToken", "TTK", ethers.parseEther("10000"));
    await token.waitForDeployment();
    
    // Deploy Dipersion
    const Dispersion = await ethers.getContractFactory("Dipersion");
    dispersion = await Dispersion.deploy();
    await dispersion.waitForDeployment();
    
    // Transfer some tokens to addr1 for testing
    await token.transfer(await addr1.getAddress(), ethers.parseEther("1000"));
  });
  
  describe("sendDifferentAmounts", function () {
    it("should send different amounts to multiple recipients", async function () {
      const recipients = [await addr2.getAddress(), await addr3.getAddress()];
      const amounts = [ethers.parseEther("100"), ethers.parseEther("200")];
      
      // Approve the dispersion contract to spend tokens on behalf of addr1
      await token.connect(addr1).approve(await dispersion.getAddress(), ethers.parseEther("300"));
      
      // Call the sendDifferentAmounts function
      await dispersion.connect(addr1).sendDifferentAmounts(await token.getAddress(), recipients, amounts);
      
      // Check balances
      expect(await token.balanceOf(await addr2.getAddress())).to.equal(ethers.parseEther("100"));
      expect(await token.balanceOf(await addr3.getAddress())).to.equal(ethers.parseEther("200"));
      expect(await token.balanceOf(await addr1.getAddress())).to.equal(ethers.parseEther("700"));
    });
    
    it("should revert when sender has insufficient balance", async function () {
      const recipients = [await addr2.getAddress(), await addr3.getAddress()];
      const amounts = [ethers.parseEther("600"), ethers.parseEther("500")];
      
      // Approve the dispersion contract to spend tokens on behalf of addr1
      await token.connect(addr1).approve(await dispersion.getAddress(), ethers.parseEther("1100"));
      
      // Expect revert due to insufficient balance
      await expect(
        dispersion.connect(addr1).sendDifferentAmounts(await token.getAddress(), recipients, amounts)
      ).to.be.revertedWith("Insufficient balance");
    });
    
    it("should revert when recipients and amounts arrays have different lengths", async function () {
      const recipients = [await addr2.getAddress()];
      const amounts = [ethers.parseEther("100"), ethers.parseEther("200")];
      
      // Expect revert due to length mismatch
      await expect(
        dispersion.connect(addr1).sendDifferentAmounts(await token.getAddress(), recipients, amounts)
      ).to.be.revertedWith("Recipients and amounts length mismatch");
    });
    
    it("should revert when no recipients are provided", async function () {
      const recipients: string[] = [];
      const amounts: bigint[] = [];
      
      // Expect revert due to no recipients
      await expect(
        dispersion.connect(addr1).sendDifferentAmounts(await token.getAddress(), recipients, amounts)
      ).to.be.revertedWith("No recipients provided");
    });
  });
  
  describe("sendSameAmount", function () {
    it("should send same amount to multiple recipients", async function () {
      const recipients = [await addr2.getAddress(), await addr3.getAddress()];
      const amount = ethers.parseEther("100");
      
      // Approve the dispersion contract to spend tokens on behalf of addr1
      await token.connect(addr1).approve(await dispersion.getAddress(), ethers.parseEther("200"));
      
      // Call the sendSameAmount function
      await dispersion.connect(addr1).sendSameAmount(await token.getAddress(), recipients, amount);
      
      // Check balances
      expect(await token.balanceOf(await addr2.getAddress())).to.equal(ethers.parseEther("100"));
      expect(await token.balanceOf(await addr3.getAddress())).to.equal(ethers.parseEther("100"));
      expect(await token.balanceOf(await addr1.getAddress())).to.equal(ethers.parseEther("800"));
    });
    
    it("should revert when amount is zero", async function () {
      const recipients = [await addr2.getAddress()];
      const amount = 0;
      
      // Expect revert due to zero amount
      await expect(
        dispersion.connect(addr1).sendSameAmount(await token.getAddress(), recipients, amount)
      ).to.be.revertedWith("Amount must be greater than zero");
    });
  });
});