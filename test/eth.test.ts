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
    // Deploy BasicToken
    // const BasicToken = await ethers.getContractFactory("BasicToken");
    // basicToken = await BasicToken.deploy(ethers.utils.parseEther("80000"));
    // await basicToken.deployed();
    // console.log("BasicToken address:", basicToken.address);

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
    console.log("transfer");
    console.log("afterBalance:", await accounts[0].getBalance());
  });

  it("Test mintToken", async function () {
    const pTokenAmount = ethers.utils.parseEther("1");

    await pTokenTest.mintToken(pTokenAmount);

    const balancePToken = await pToken.balanceOf(pTokenTest.address);
    expect(balancePToken).to.equal(pTokenAmount);
  });

  // add Liquidity
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
    const beforeContractETHBalance = await dToken.getContractBalance();

    const responce = await dToken.mint(amount, { value: amount });
    const tx = await responce.wait();
    const gasUsed = tx.cumulativeGasUsed.mul(tx.effectiveGasPrice);
    const afterUserETHBalance = await accounts[0].getBalance();
    const afterUserTokenBalance = await dToken.balanceOf(
      await accounts[0].getAddress()
    );
    const afterContractETHBalance = await dToken.getContractBalance();

    expect(beforeUserETHBalance.sub(amount).sub(gasUsed)).eq(
      afterUserETHBalance
    );
    expect(beforeUserTokenBalance.add(amount)).eq(afterUserTokenBalance);
    expect(beforeContractETHBalance.add(amount)).eq(afterContractETHBalance);
  });

  // it("Test DToken borrow", async function () {
  //   const pTokenTestNew = pTokenTest.connect(accounts[1]);
  //   const beforeExchageRate = await dToken.exchangeRateStored();
  //   const amount = ethers.utils.parseEther("0.3");

  //   // The first borrow
  //   await pTokenTestNew.borrowToken(dToken.address, amount);

  //   // The second borrow
  //   await pTokenTestNew.borrowToken(dToken.address, amount);

  //   const secondBorrowExchageRate = await dToken.exchangeRateStored();
  //   const afterBasicBalance = await basicToken.balanceOf(pTokenTestNew.address);
  //   const borrow = await dToken.totalBorrows();
  //   console.log("borrow: ", borrow);
  //   console.log("afterBasicBalance:", afterBasicBalance);
  //   expect(afterBasicBalance).to.equal(amount.mul(2));
  //   expect(secondBorrowExchageRate).to.gt(beforeExchageRate);
  // });
});
