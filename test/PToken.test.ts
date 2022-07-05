import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { Contract, Signer } from "ethers";
import { ethers } from "hardhat";

describe("PToken", function () {
  let accounts: Signer[];
  let basicToken: Contract;
  let pToken: Contract;
  let pTokenTest: Contract;
  let dToken: Contract;
  let chainId: number;

  before(async function () {
    accounts = await ethers.getSigners();

    chainId = await accounts[0].getChainId();
    console.log("chainId", chainId);

    // Deploy BasicToken
    const BasicToken = await ethers.getContractFactory("BasicToken");
    basicToken = await BasicToken.deploy(ethers.utils.parseEther("80000"));
    await basicToken.deployed();
    console.log("BasicToken address:", basicToken.address);

    // Deploy PTokenTest
    const PTokenTest = await ethers.getContractFactory("PTokenTest");
    pTokenTest = await PTokenTest.deploy();
    await pTokenTest.deployed();
    console.log("pTokenTest address:", pTokenTest.address);

    // Deploy PToken
    const PToken = await ethers.getContractFactory("PToken");
    pToken = await PToken.deploy(pTokenTest.address);
    await pToken.deployed();
    console.log("PToken address:", pToken.address);

    // Deploy DToken
    const DToken = await ethers.getContractFactory("DToken");
    dToken = await DToken.deploy("DToken", "DToken", 18);
    await dToken.deployed();
    console.log("DToken address:", dToken.address);

    await pTokenTest.bindPTokenAddress(pToken.address);

    // Transfer 100ether BasicToken to pToken from accounts[0]
    await basicToken.transfer(
      pToken.address,
      ethers.utils.parseEther("100")
    );
  });

  it("Test mintToken", async function () {
    const pTokenAmount = ethers.utils.parseEther("1");

    await pTokenTest.mintToken(pTokenAmount);

    const balancePToken = await pToken.balanceOf(pTokenTest.address);
    expect(balancePToken).to.equal(pTokenAmount);
  });

  it("Test DToken mint", async function () {
    await dToken.initialize(
      basicToken.address,
      pTokenTest.address,
      pToken.address,
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.004"),
      ethers.utils.parseEther("0.011"),
      ethers.utils.parseEther("0.008"),
      ethers.utils.parseEther("0.008")
    );

    const amount = ethers.utils.parseEther("1");
    const amoutBasic = await basicToken.balanceOf(accounts[0].getAddress());

    await basicToken.approve(dToken.address, amoutBasic);
    await dToken.mint(amount);

    const dBalance = await dToken.balanceOf(accounts[0].getAddress());
    expect(dBalance).to.equal(amount);
  });

  it("Test DToken borrow", async function () {
    const pTokenTestNew = pTokenTest.connect(accounts[1]);
    const beforeExchageRate = await dToken.exchangeRateStored();
    const amount = ethers.utils.parseEther("0.3");

    // The first borrow 
    await pTokenTestNew.borrowToken(dToken.address, amount);

    // The second borrow
    await pTokenTestNew.borrowToken(dToken.address, amount);

    const secondBorrowExchageRate = await dToken.exchangeRateStored();
    const afterBasicBalance = await basicToken.balanceOf(pTokenTestNew.address);
    expect(afterBasicBalance).to.equal(ethers.utils.parseEther("0.6"));
    expect(secondBorrowExchageRate).to.not.equal(beforeExchageRate);
  });

  it("Test DToken redeem", async function () {
    // The amount of deposit redeemed by the user should be less than the amount of cash in DToken Pool.
    // The DToken Pool only have 0.4 Ether.
    const beforeDTokenBalance = await dToken.balanceOf(accounts[0].getAddress());
    const beforeBasicTokenBalance = await basicToken.balanceOf(accounts[0].getAddress());
    // The user redeem 0.3 Ether.
    const redeemAmount = ethers.utils.parseEther("0.3");

    await dToken.redeem(redeemAmount);

    const redeemExchageRate = await dToken.exchangeRateStored();
    // Calculation of the number of underlying assets based on exchange rates.
    const expectAmount = (redeemExchageRate.mul(redeemAmount)).div(ethers.utils.parseEther("1"));
    const afterDTokenBalance = await dToken.balanceOf(accounts[0].getAddress());
    const afterBasicTokenBalance = await basicToken.balanceOf(accounts[0].getAddress());
    expect(beforeDTokenBalance.sub(redeemAmount)).to.equal(afterDTokenBalance);
    expect(beforeBasicTokenBalance.add(expectAmount)).to.equal(afterBasicTokenBalance);
  });

  it("Test DToken repayBorrow", async function () {
    const pTokenTestNew = pTokenTest.connect(accounts[1]);
    const beforeExchageRate = await dToken.exchangeRateStored();
    // The user borrowed 0.6 Ether.
    const beforeBasicTokenBalance = await basicToken.balanceOf(pTokenTestNew.address);
    // The user repayBorrow 0.3 Ether.
    const amount = ethers.utils.parseEther("0.3");

    await pTokenTestNew.approve(basicToken.address, dToken.address, beforeBasicTokenBalance)
    await pTokenTestNew.repayBorrowToken(dToken.address, amount);

    const secondBorrowExchageRate = await dToken.exchangeRateStored();
    const afterBasicTokenBalance = await basicToken.balanceOf(pTokenTestNew.address);
    expect(secondBorrowExchageRate).to.not.equal(beforeExchageRate);
    expect(afterBasicTokenBalance).to.equal(beforeBasicTokenBalance.sub(amount));
  });

  it("Test APY",async function () {
   const APY = await dToken.supplyRatePerBlock();
   console.log("APY: ", APY);
  })
});
