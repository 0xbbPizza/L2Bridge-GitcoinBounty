import { ethers } from "hardhat";
import { Signer, BigNumber, Contract} from "ethers";
import "ethers";
import { expect } from "chai";

describe("source", function () {
  let accounts: Signer[];
  let fakeToken: Contract;
  let source: Contract;
  let dest: Contract;
  let hashOnion: string;
  let sourceAmount : BigNumber;

  before(async function () {
    accounts = await ethers.getSigners()
    // console.log("ABC", accounts.map((a) => a.getAddress()));

    // deploy token contract
    const FakeToken = await ethers.getContractFactory("BasicToken")
    let amount:BigNumber = BigNumber.from(1000000000000)
    fakeToken = await FakeToken.deploy(amount);
    await fakeToken.deployed()
    console.log("FakeToken address:",fakeToken.address)
    
    
    // set account token amount
    for (let i = 1 ; i < accounts.length ; i++){
      let amount = i*1000000000
      fakeToken.transfer(accounts[i].getAddress(),amount)
    }
    
    // deploy source contract
    const Source = await ethers.getContractFactory("SourceContract")
    source = await Source.deploy(accounts[0].getAddress(),fakeToken.address)
    await source.deployed()
    console.log("sourceContract Address", source.address)

    // deploy dest contract
    const Dest = await ethers.getContractFactory("DestinationContract")
    dest = await Dest.deploy(accounts[0].getAddress(),fakeToken.address)
    await dest.deployed()
    console.log("destContract Address", dest.address)

    sourceAmount = BigNumber.from(0)
  });

  it("transfer on SourceContract, change hashOnion", async function () {
    let amount = await fakeToken.balanceOf(accounts[1].getAddress())
    let fee = BigNumber.from(0)
    let address1 = await accounts[1].getAddress()

    let data = ethers.utils.defaultAbiCoder.encode(["address","uint","uint"],[ethers.constants.AddressZero,0,0])
    hashOnion = ethers.utils.keccak256(data);

    expect(await source.hashOnion()).to.equal(hashOnion)
    
    await fakeToken.connect(accounts[1]).approve(source.address,amount)
    await source.connect(accounts[1]).transfer(amount,fee)
    expect(await fakeToken.balanceOf(address1)).to.equal(0)

  
    sourceAmount = sourceAmount.add(amount)

    expect(await fakeToken.balanceOf(source.address)).to.equal(sourceAmount)

    let data1 = ethers.utils.defaultAbiCoder.encode(["address","uint","uint"],[await address1,amount,fee])
    let oneTxHash = ethers.utils.keccak256(data1)
    let dataHash_1 = ethers.utils.defaultAbiCoder.encode(["bytes32","bytes32"],[hashOnion,oneTxHash])
    hashOnion = ethers.utils.keccak256(dataHash_1);

    expect(await source.hashOnion()).to.equal(hashOnion)
  });

  it("transferWithDest on SourceContract, change hashOnion", async function () {
    let user = accounts[2]
    let allAmount = await fakeToken.balanceOf(user.getAddress())
    let fee = BigNumber.from(10000)
    let amount = allAmount.sub(fee)
    let userAddress = await accounts[2].getAddress()
    let userAddress2 = await accounts[3].getAddress()
    
    sourceAmount = sourceAmount.add(allAmount)

    await fakeToken.connect(user).approve(source.address,allAmount)
    await source.connect(user).transferWithDest(userAddress2,amount,fee)
    expect(await fakeToken.balanceOf(userAddress)).to.equal(0)
    expect(await fakeToken.balanceOf(source.address)).to.equal(sourceAmount)
    
    let txABI = await ethers.utils.defaultAbiCoder.encode(["address","uint","uint"],[userAddress2,amount,fee])
    let txHash = ethers.utils.keccak256(txABI)
    let onionABI = ethers.utils.defaultAbiCoder.encode(["bytes32","bytes32"],[hashOnion,txHash])
    hashOnion = ethers.utils.keccak256(onionABI);
    
    expect(await source.hashOnion()).to.equal(hashOnion)
  });

  it("creat long hashOnion on SourceContract", async function () {
    let user;
    let userAddress;
    let allAmount: BigNumber;
    let fee : BigNumber;
    let amount : BigNumber;
    

    for (let i = 3 ; i < accounts.length ; i++){
      user = accounts[i]
      userAddress = await accounts[i].getAddress()

      allAmount = await fakeToken.balanceOf(user.getAddress())
      fee = BigNumber.from(i*10000)
      amount = allAmount.sub(fee)
      sourceAmount = sourceAmount.add(allAmount)
      
      await fakeToken.connect(user).approve(source.address,allAmount)
      await source.connect(user).transfer(amount,fee)
      expect(await fakeToken.balanceOf(userAddress)).to.equal(0)
      expect(await fakeToken.balanceOf(source.address)).to.equal(sourceAmount)

      let txABI = await ethers.utils.defaultAbiCoder.encode(["address","uint","uint"],[userAddress,amount,fee])
      let txHash = ethers.utils.keccak256(txABI)
      let onionABI = ethers.utils.defaultAbiCoder.encode(["bytes32","bytes32"],[hashOnion,txHash])
      hashOnion = ethers.utils.keccak256(onionABI);
      
      expect(await source.hashOnion()).to.equal(hashOnion)
    }
  });

  it("dest OnionHead", async function () {
      
  });
});