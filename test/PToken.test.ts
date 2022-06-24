import { expect } from "chai";
import { Contract, Signer } from "ethers";
import { ethers } from "hardhat";

describe("PToken", function () {
  let accounts: Signer[];
  let basicToken: Contract;
  let pToken: Contract;
  let pTokenTest: Contract;
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
});
