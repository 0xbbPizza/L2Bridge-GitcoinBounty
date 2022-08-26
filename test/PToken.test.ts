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
    await basicToken.transfer(pToken.address, ethers.utils.parseEther("100"));
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
    console.log("dBalance: ", dBalance);
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
    const borrow = await dToken.totalBorrows();
    console.log("borrow: ", borrow);
    console.log("afterBasicBalance:", afterBasicBalance);
    expect(afterBasicBalance).to.equal(amount.mul(2));
    expect(secondBorrowExchageRate).to.gt(beforeExchageRate);
  });

  it("Test DToken redeem", async function () {
    // The amount of deposit redeemed by the user should be less than the amount of cash in DToken Pool.
    // The DToken Pool only have 0.4 Ether.
    const beforeDTokenBalance = await dToken.balanceOf(
      accounts[0].getAddress()
    );
    const beforeBasicTokenBalance = await basicToken.balanceOf(
      accounts[0].getAddress()
    );
    // The user redeem 0.3 Ether.
    const redeemAmount = ethers.utils.parseEther("0.3");

    await dToken.redeem(redeemAmount);

    const redeemExchageRate = await dToken.exchangeRateStored();
    // Calculation of the number of underlying assets based on exchange rates.
    const expectAmount = redeemExchageRate
      .mul(redeemAmount)
      .div(ethers.utils.parseEther("1"));
    const afterDTokenBalance = await dToken.balanceOf(accounts[0].getAddress());
    const afterBasicTokenBalance = await basicToken.balanceOf(
      accounts[0].getAddress()
    );
    expect(beforeDTokenBalance.sub(redeemAmount)).to.equal(afterDTokenBalance);
    expect(beforeBasicTokenBalance.add(expectAmount)).to.equal(
      afterBasicTokenBalance
    );
  });

  it("Test DToken repayBorrow", async function () {
    const pTokenTestNew = pTokenTest.connect(accounts[1]);
    const beforeExchageRate = await dToken.exchangeRateStored();
    // The user borrowed 0.6 Ether.
    const beforeBasicTokenBalance = await basicToken.balanceOf(
      pTokenTestNew.address
    );
    // The user repayBorrow 0.3 Ether.
    const amount = ethers.utils.parseEther("0.3");

    await pTokenTestNew.approve(
      basicToken.address,
      dToken.address,
      beforeBasicTokenBalance
    );
    await pTokenTestNew.repayBorrowToken(dToken.address, amount);

    const secondExchageRate = await dToken.exchangeRateStored();
    const afterBasicTokenBalance = await basicToken.balanceOf(
      pTokenTestNew.address
    );
    expect(secondExchageRate).to.gt(beforeExchageRate);
    expect(afterBasicTokenBalance).to.equal(
      beforeBasicTokenBalance.sub(amount)
    );
  });

  it("Test APY", async function () {
    const APY = await dToken.supplyRatePerBlock();
    console.log("APY: ", APY);
  });
});

// var provider = new ethers.providers.JsonRpcProvider(
//   "http://localhost:8545"
// );
// const metacoinArtifacts = require("../build/contracts/MyToken.json");
// const address = metacoinArtifacts.networks[3].address;

// var filter = {
//   address: address,
//   fromBlock: 0,
// };
// var callPromise = provider.getLogs(filter);
// callPromise
//   .then(function (events) {
//     console.log("Printing array of events:");
//     console.log(events);
//   })
//   .catch(function (err) {
//     console.log(err);
//   });

// to: 0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0; //ptoken
// owner: 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266; //user

// // borrow
// to: 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512; // dest
// owner: 0xcf7ed3acca5a467e9e704c703e8d87f634fb0fc9; //dtoken

// // redeem
// to: 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266; //user
// owner: 0xcf7ed3acca5a467e9e704c703e8d87f634fb0fc9; //dtoken
