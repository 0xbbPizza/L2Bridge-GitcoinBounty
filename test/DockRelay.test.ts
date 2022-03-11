import { ethers } from "hardhat";
import { Signer, BigNumber, Contract } from "ethers";
// import "ethers";
import { expect } from "chai";

describe("source", function () {
  let accounts: Signer[];
  let source: Contract;
  let dest: Contract;

  before(async function () {
    accounts = await ethers.getSigners()
    
    // 3
    const Raley = await ethers.getContractFactory("Relay");
    const raley = await Raley.deploy();
    await raley.deployed();
    console.log("raley Address:",raley.address)

    // 2
    const Dock_Mainnet = await ethers.getContractFactory("Dock_MainNet");
    const dock_Mainnet = await Dock_Mainnet.deploy(raley.address);
    await dock_Mainnet.deployed();
    console.log("dock_Mainnet Address:",dock_Mainnet.address)

    // set 2 to 3 
    const chainId = await accounts[0].getChainId();
    console.log("chainId", chainId);
    raley.addDock(dock_Mainnet.address,chainId)
    
    // 6
    const Test_destination = await ethers.getContractFactory("Test_destination")
    const test_destination = await Test_destination.deploy(dock_Mainnet.address);
    await test_destination.deployed()
    console.log("test_destination Address:",test_destination.address)
    dest = test_destination

    // 7
    const Test_source = await ethers.getContractFactory("Test_source")
    const test_source = await Test_source.deploy(dock_Mainnet.address);
    await test_source.deployed()
    console.log("test_source Address:",test_source.address);
    source = test_source

    // set 7 to 6 
    test_destination.addDomain(chainId, test_source.address);

    // set 6 to 7
    test_source.addDestDomain(chainId, test_destination.address);
    
  });

  it("Dock_Mainnet.callOtherDomainFunction", async function () {
    const chainId = await accounts[0].getChainId();
    const massage = "hello world";
    await source.sendMessage(chainId, massage);

    expect(await dest.message()).to.equal(massage);
    expect(await dest.chainId()).to.equal(chainId);
  });

});