import { ethers } from "hardhat";
import { Signer, BigNumber, Contract} from "ethers";
// import "ethers";
import { expect } from "chai";

describe("source", function () {
  let accounts: Signer[];
  let fakeToken: Contract;
  let source: Contract;
  let dest: Contract;
  let hashOnion: string;
  let sourceAmount : BigNumber;
  let users: Signer[];
  let makers: Signer[];
  let txs : [string,BigNumber,BigNumber][];
  let ONEFORK_MAX_LENGTH: any;
  // let sourceToDestAmount: any;

  before(async function () {
    accounts = await ethers.getSigners()
    
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
    ONEFORK_MAX_LENGTH = await source.ONEFORK_MAX_LENGTH()
    console.log("sourceContract Address", source.address)
    

    // deploy dest contract
    const Dest = await ethers.getContractFactory("DestinationContract")
    dest = await Dest.deploy(accounts[0].getAddress(),fakeToken.address)
    await dest.deployed()
    console.log("destContract Address", dest.address)

    sourceAmount = BigNumber.from(0)
    users = accounts.slice(1,17)
    makers = accounts.slice(18)
    txs = []
  });

  // async function set(tick: number) {
  //   const { liquidityGross, feeGrowthOutside0X128, feeGrowthOutside1X128, liquidityNet } = await pool.ticks(tick)
  //   expect(liquidityGross).to.eq(0)
  //   expect(feeGrowthOutside0X128).to.eq(0)
  //   expect(feeGrowthOutside1X128).to.eq(0)
  //   expect(liquidityNet).to.eq(0)
  // }

  it("transfer on SourceContract, change hashOnion", async function () {
    let amount = await fakeToken.balanceOf(users[1].getAddress())
    let fee = BigNumber.from(0)
    let address1 = await users[1].getAddress()

    hashOnion = ethers.constants.HashZero;

    expect(await source.hashOnion()).to.equal(hashOnion)
    
    await fakeToken.connect(users[1]).approve(source.address,amount)
    await source.connect(users[1]).transfer(amount,fee)
    expect(await fakeToken.balanceOf(address1)).to.equal(0)

    sourceAmount = sourceAmount.add(amount)

    expect(await fakeToken.balanceOf(source.address)).to.equal(sourceAmount)

    let data1 = ethers.utils.defaultAbiCoder.encode(["address","uint","uint"],[address1,amount,fee])
    let oneTxHash = ethers.utils.keccak256(data1)
    let dataHash_1 = ethers.utils.defaultAbiCoder.encode(["bytes32","bytes32"],[hashOnion,oneTxHash])
    hashOnion = ethers.utils.keccak256(dataHash_1);

    expect(await source.hashOnion()).to.equal(hashOnion)
    txs.push([address1,amount,fee])
  });

  it("transferWithDest on SourceContract, change hashOnion", async function () {
    let user = users[2]
    let allAmount = await fakeToken.balanceOf(user.getAddress())
    let fee = BigNumber.from(10000)
    let amount = allAmount.sub(fee)
    let userAddress = await users[2].getAddress()
    let userAddress2 = await users[3].getAddress()
    
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
    txs.push([userAddress2,amount,fee])
  });

  it("creat long hashOnion on SourceContract", async function () {
    let user;
    let userAddress;
    let allAmount: BigNumber;
    let fee : BigNumber;
    let amount : BigNumber;
    

    for (let i = 3 ; i < users.length ; i++){
      user = users[i]
      userAddress = await users[i].getAddress()

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
      txs.push([userAddress,amount,fee])
    }
  });

  it("only zFork on dest", async function () {
    expect(ONEFORK_MAX_LENGTH).to.equal(await dest.ONEFORK_MAX_LENGTH())

    let amount = await fakeToken.balanceOf(accounts[0].getAddress())

    await dest.becomeCommiter()
    fakeToken.approve(dest.address,amount)

    let forkKey = ethers.constants.HashZero
    let index = 0
    let sourOnion : string = ethers.constants.HashZero
    let destOnion : string = ethers.constants.HashZero
    
    for (let i = 0 ; i < txs.length ; i++){
      
      let txABI = await ethers.utils.defaultAbiCoder.encode(["address","uint","uint"],txs[i])
      let txHash = ethers.utils.keccak256(txABI)
      let onionABI = ethers.utils.defaultAbiCoder.encode(["bytes32","bytes32"],[sourOnion,txHash])
      sourOnion = ethers.utils.keccak256(onionABI);
      let destOnionABI = ethers.utils.defaultAbiCoder.encode(["bytes32","bytes32","address"],[destOnion,sourOnion,await accounts[0].getAddress()])
      destOnion = ethers.utils.keccak256(destOnionABI);

      index = i%ONEFORK_MAX_LENGTH
      if(index == 0){
        await dest.zFork(forkKey,0,txs[i][0],txs[i][1],txs[i][2],true)
        forkKey = sourOnion
      }else{
        await dest.claim(forkKey,0,index,[{destination: txs[i][0],amount: txs[i][1],fee: txs[i][2]}],[true])
      }
      let fork = await dest.hashOnionForks(forkKey,0)
      // console.log(i)
      // console.log(fork)
      expect(fork[0]).to.equal(sourOnion)
      expect(fork[1]).to.equal(destOnion)
    }

    let fork = await dest.hashOnionForks(forkKey,0)

    expect(fork[0]).to.equal(hashOnion)

    let userAddress = await users[2].getAddress()
    expect(await fakeToken.balanceOf(userAddress)).to.equal(0)
    let userAddress2 = await users[3].getAddress()
    let user2Amount = txs[1][1].add(txs[2][1])
    expect(await fakeToken.balanceOf(userAddress2)).to.equal(user2Amount)

  });

  it("only zbond on dest", async function () {
    await dest.setHashOnion(hashOnion)
    expect(await dest.sourceHashOnion()).to.equal(hashOnion)
    expect(await dest.onWorkHashOnion()).to.equal(hashOnion)
    await dest.setHashOnion("0x003d8a08f9ede42ea05521791c51a4fda7c79781c03131deef9f90cfd5741aaa")
    expect(await dest.sourceHashOnion()).to.equal("0x003d8a08f9ede42ea05521791c51a4fda7c79781c03131deef9f90cfd5741aaa")
    expect(await dest.onWorkHashOnion()).to.equal(hashOnion)


    let sourOnion : string = ethers.constants.HashZero
    let keySourOnion  = [sourOnion]
    
    let index;
    let transferDatas = []
    let commitAddresslist = []


    for (let i = 0 ; i < txs.length ; i++){
      let txABI = await ethers.utils.defaultAbiCoder.encode(["address","uint","uint"],txs[i])
      let txHash = ethers.utils.keccak256(txABI)
      let onionABI = ethers.utils.defaultAbiCoder.encode(["bytes32","bytes32"],[sourOnion,txHash])
      sourOnion = ethers.utils.keccak256(onionABI);

      index = i%ONEFORK_MAX_LENGTH
      if(index == 0){
        keySourOnion.push(sourOnion)
      }

      transferDatas.push({destination: txs[i][0],amount: txs[i][1],fee: txs[i][2]})
      commitAddresslist.push(accounts[0].getAddress())
    }
    
    let sourceAmount = await fakeToken.balanceOf(source.address)
    let bonderAmount = await fakeToken.balanceOf(accounts[0].getAddress())
    await fakeToken.transfer(dest.address,sourceAmount)
    expect(await fakeToken.balanceOf(dest.address)).to.equal(sourceAmount)
    expect(await fakeToken.balanceOf(accounts[0].getAddress())).to.equal(bonderAmount-sourceAmount)
    
    for (let i = keySourOnion.length-1; i > 0; i--){
      let x = (i-1) * ONEFORK_MAX_LENGTH
      let y = i * ONEFORK_MAX_LENGTH
      await dest.zbond(keySourOnion[i], keySourOnion[i-1],0,transferDatas.slice(x,y),commitAddresslist.slice(x,y))
    }

    expect(await fakeToken.balanceOf(dest.address)).to.equal(0)
    expect(await fakeToken.balanceOf(accounts[0].getAddress())).to.equal(bonderAmount)
  });

});