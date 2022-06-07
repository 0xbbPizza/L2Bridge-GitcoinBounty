import { expect } from "chai";
import { BigNumber, Contract, Signer } from "ethers";
import { ethers } from "hardhat";

describe("PoolToken", function () {
  let accounts: Signer[];
  let basicToken: Contract;
  let poolToken: Contract;
  let poolTokenTest: Contract;
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

    // Deploy PoolTokenTest
    const PoolTokenTest = await ethers.getContractFactory("PoolTokenTest");
    poolTokenTest = await PoolTokenTest.deploy();
    await poolTokenTest.deployed();
    console.log("poolTokenTest address:", poolTokenTest.address);

    // Deploy PoolToken
    const PoolToken = await ethers.getContractFactory("PoolToken");
    poolToken = await PoolToken.deploy(poolTokenTest.address);
    await poolToken.deployed();
    console.log("PoolToken address:", poolToken.address);

    await poolTokenTest.bindPoolTokenAddress(poolToken.address);

    // Transfer 100ether BasicToken to poolToken from accounts[0]
    await basicToken.transfer(
      poolToken.address,
      ethers.utils.parseEther("100")
    );
  });

  it("Test exchangeBasicToken", async function () {
    const poolTokenAmount = ethers.utils.parseEther("1");

    await poolTokenTest.exchangeBasicToken(basicToken.address, poolTokenAmount);

    const balanceBasicToken = await basicToken.balanceOf(poolTokenTest.address);
    expect(balanceBasicToken).to.equal(poolTokenAmount.mul(10));
    console.log("balanceBasicToken: ", balanceBasicToken + "");

    const balancePoolToken = await poolToken.balanceOf(poolTokenTest.address);
    expect(balancePoolToken).to.equal(0);
  });
});
