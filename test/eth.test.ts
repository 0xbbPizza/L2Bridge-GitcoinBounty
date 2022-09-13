import { expect } from "chai";
import { BigNumber, Contract, Signer } from "ethers";
import { ethers } from "hardhat";
describe("PToken", function () {
  let accounts: Signer[];
  let basicToken: Contract;
  let pToken: Contract;
  let pTokenTest: Contract;
  let dToken: Contract;
  let chainId: number;
  let tokenAddress: any;

  before(async function () {
    accounts = await ethers.getSigners();
    chainId = await accounts[0].getChainId();
    console.log("chainId", chainId);
    tokenAddress = ethers.constants.AddressZero;

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
    console.log("beforeBalance:", await accounts[0].getBalance());

    // Transfer 100ether BasicToken to pToken from accounts[0]
    await accounts[0].sendTransaction({
      to: pToken.address,
      value: ethers.utils.parseEther("100"),
      gasLimit: 3000000,
    });
  });

  it("Test mintToken", async function () {
    const pTokenAmount = ethers.utils.parseEther("1");

    await pTokenTest.mintToken(pTokenAmount);

    const balancePToken = await pToken.balanceOf(pTokenTest.address);
    expect(balancePToken).eq(pTokenAmount);
  });
  it("Test DToken mint", async function () {
    await dToken.initialize(
      tokenAddress,
      pTokenTest.address,
      pToken.address,
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.004"),
      ethers.utils.parseEther("0.011"),
      ethers.utils.parseEther("0.008"),
      ethers.utils.parseEther("0.008")
    );

    const amount = ethers.utils.parseEther("10");
    const beforeUserETHBalance = await accounts[0].getBalance();
    const beforeUserTokenBalance = await dToken.balanceOf(
      await accounts[0].getAddress()
    );
    const beforeContractETHBalance = await dToken.getBalance(dToken.address);

    const responce = await dToken.mint(amount, { value: amount });
    const tx = await responce.wait();
    const gasUsed = tx.cumulativeGasUsed.mul(tx.effectiveGasPrice);
    const afterUserETHBalance = await accounts[0].getBalance();
    const afterUserTokenBalance = await dToken.balanceOf(
      await accounts[0].getAddress()
    );
    const afterContractETHBalance = await dToken.getBalance(dToken.address);

    expect(beforeUserETHBalance.sub(amount).sub(gasUsed)).eq(
      afterUserETHBalance
    );
    expect(beforeUserTokenBalance.add(amount)).eq(afterUserTokenBalance);
    expect(beforeContractETHBalance.add(amount)).eq(afterContractETHBalance);
  });
  it("Test DToken borrow", async function () {
    const pTokenTestNew = pTokenTest.connect(accounts[1]);
    const beforeExchageRate = await dToken.exchangeRateStored();
    const beforeUserETHBalance = await ethers.provider.getBalance(
      pTokenTestNew.address
    );
    const beforeContractETHBalance = await dToken.getBalance(dToken.address);
    const amount = ethers.utils.parseEther("0.3");

    // The first borrow
    await pTokenTestNew.borrowToken(dToken.address, amount);
    // The second borrow
    await pTokenTestNew.borrowToken(dToken.address, amount);
    // Gas fee is not counted here because the user makes a transaction through pTokenTest.

    const secondBorrowExchageRate = await dToken.exchangeRateStored();
    const afterUserETHBalance = await ethers.provider.getBalance(
      pTokenTestNew.address
    );
    const afterContractETHBalance = await dToken.getBalance(dToken.address);
    const borrow = await dToken.totalBorrows();
    console.log("borrow: ", borrow);
    expect(beforeUserETHBalance.add(amount.mul(2))).eq(afterUserETHBalance);
    expect(beforeContractETHBalance.sub(amount.mul(2))).eq(
      afterContractETHBalance
    );
    expect(secondBorrowExchageRate).gt(beforeExchageRate);
  });
  it("Test DToken redeem", async function () {
    // The amount of deposit redeemed by the user should be less than the amount of cash in DToken Pool.
    // The DToken Pool only have 0.4 Ether.
    const beforeUserTokenBalance = await dToken.balanceOf(
      accounts[0].getAddress()
    );
    const beforeUserETHBalance = await accounts[0].getBalance();
    const beforeContractETHBalance = await dToken.getBalance(dToken.address);
    // The user redeem 0.3 Ether.
    const redeemAmount = ethers.utils.parseEther("0.3");

    const responce = await dToken.redeem(redeemAmount);

    const tx = await responce.wait();
    const gasUsed = tx.cumulativeGasUsed.mul(tx.effectiveGasPrice);

    const redeemExchageRate = await dToken.exchangeRateStored();
    // Calculation of the number of underlying assets based on exchange rates.
    const expectAmount = redeemExchageRate
      .mul(redeemAmount)
      .div(ethers.utils.parseEther("1"));
    const afterUserTokenBalance = await dToken.balanceOf(
      accounts[0].getAddress()
    );
    const afterUserETHBalance = await accounts[0].getBalance();
    const afterContractETHBalance = await dToken.getBalance(dToken.address);
    expect(beforeUserTokenBalance.sub(redeemAmount)).eq(afterUserTokenBalance);
    expect(beforeUserETHBalance.add(expectAmount).sub(gasUsed)).eq(
      afterUserETHBalance
    );
    expect(beforeContractETHBalance.sub(expectAmount)).eq(
      afterContractETHBalance
    );
  });
  it("Test DToken repayBorrow", async function () {
    const pTokenTestNew = pTokenTest.connect(accounts[1]);
    const beforeExchageRate = await dToken.exchangeRateStored();
    // The user borrowed 0.6 Ether.
    const beforeUserETHBalance = await ethers.provider.getBalance(
      pTokenTestNew.address
    );
    const beforeContractETHBalance = await dToken.getBalance(dToken.address);
    // The user repayBorrow 0.3 Ether.
    const amount = ethers.utils.parseEther("0.3");

    await pTokenTestNew.repayBorrowToken(dToken.address, amount);
    // Gas fee is not counted here because the user makes a transaction through pTokenTest.
    const secondExchageRate = await dToken.exchangeRateStored();
    const afterUserETHBalance = await ethers.provider.getBalance(
      pTokenTestNew.address
    );
    const afterContractETHBalance = await dToken.getBalance(dToken.address);
    expect(secondExchageRate).gt(beforeExchageRate);
    expect(beforeUserETHBalance.sub(amount)).eq(afterUserETHBalance);
    expect(beforeContractETHBalance.add(amount)).eq(afterContractETHBalance);
  });
  it("Test APY", async function () {
    const APY = await dToken.supplyRatePerBlock();
    console.log("APY: ", APY);
  });
});
