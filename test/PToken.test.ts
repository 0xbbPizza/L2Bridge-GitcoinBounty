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
      0,
      0,
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

    const beforeBasicBalance = await basicToken.balanceOf(pTokenTestNew.address);
    console.log('beforeBasicBalance: ', beforeBasicBalance);
    // const beforeTotalCash = await dToken.getCashPrior()
    // const beforeTotalBorrows = await dToken.totalBorrows()
    // const beforeTotalReserves = await dToken.totalReserves()
    // const beforeUtilizationRate = await dToken.utilizationRate(beforeTotalCash, beforeTotalBorrows, beforeTotalReserves)
    // console.log('beforeUtilizationRate: ', beforeUtilizationRate);

    const beforeExchageRate = await dToken.exchangeRateStored();
    console.log('beforeExchageRate: ', beforeExchageRate);
    console.log(await dToken.testGet())

    const amount = ethers.utils.parseEther("0.3");
    await pTokenTestNew.borrowToken(dToken.address, amount);

    const afterBasicBalance = await basicToken.balanceOf(pTokenTestNew.address);
    console.log('afterBasicBalance: ', afterBasicBalance);

    const afterExchageRate = await dToken.exchangeRateStored();
    console.log('afterExchageRate: ', afterExchageRate);
    // const afterTotalCash = await dToken.getCashPrior()
    // const afterTotalBorrows = await dToken.totalBorrows()
    // const afterTotalReserves = await dToken.totalReserves()
    // const afterUtilizationRate = await dToken.utilizationRate(afterTotalCash, afterTotalBorrows, afterTotalReserves)
    // console.log('afterUtilizationRate: ', afterUtilizationRate);
    console.log(await dToken.testGet())
    // console.log(await dToken.totalBorrows())

  });
});
