import { ethers } from "hardhat";
import { Signer, BigNumber, Contract , providers , Wallet} from "ethers";
// import "ethers";
import { expect } from "chai";

import * as dotenv from "dotenv";
dotenv.config({ path: __dirname+'/.env' });

import * as fs from 'fs';
const privateKeyPath = './generated/PrivateKey.secret';
const getPrivateKey = (): string[] => {
  try {
    return fs.readFileSync(privateKeyPath).toString().trim().split("\n");
  } catch (e) {
    if (process.env.HARDHAT_TARGET_NETWORK !== 'localhost') {
      console.log('☢️ WARNING: No PrivateKey file created for a deploy account. Try `yarn run generate` and then `yarn run account`.');
    }
  }
  return [''];
};

const l1Provider = new providers.JsonRpcProvider(process.env.rinkebyRPC)
const l2Provider = new providers.JsonRpcProvider(process.env.rb_rinkebyRPC)
const l1Wallet = new Wallet(getPrivateKey()[0], l1Provider)



describe("source", function () {
  let account: Signer;
  let fakeToken: Contract;
  let source: Contract;
  let relay: Contract;

  before(async function () {
    let accounts = await ethers.getSigners()
    account = accounts[0]

    // deploy token contract
    // const FakeToken = await ethers.getContractFactory("BasicToken")
    // let amount:BigNumber = BigNumber.from(1000000000000)
    // fakeToken = await FakeToken.deploy(amount);
    // await fakeToken.deployed()
    // console.log("FakeToken address:",fakeToken.address)
    
    // // deploy source contract
    // let arbsys_L2 = ethers.utils.getAddress("0x0000000000000000000000000000000000000064")
    // const Source = await ethers.getContractFactory("SourceContract")
    // source = await Source.deploy(arbsys_L2,fakeToken.address)
    // await source.deployed()
    // console.log("sourceContract Address", source.address)
    
    // deploy raley contract
    let bridgeAddress = ethers.utils.getAddress("0x9a28e783c47bbeb813f32b861a431d0776681e95")
    let sourceaddress = ethers.utils.getAddress("0x6410a9aaca48d8A5772892896eA260ff06e4a643")
    const Relay = (await ethers.getContractFactory("Relay")).connect(l1Wallet)
    relay = await Relay.deploy(bridgeAddress, sourceaddress)
    await relay.deployed()
    console.log("Relay Address", relay.address)
  });

  it("transfer on SourceContract, change hashOnion", async function () {
    let amount = await fakeToken.balanceOf(account.getAddress())
    let fee = BigNumber.from(0)
    let address1 = await account.getAddress()
    
    await fakeToken.approve(source.address,amount)
    await source.transfer(amount,fee)
    expect(await fakeToken.balanceOf(address1)).to.equal(0)
  });


  it("send raley", async function () {
    // await source.extractHashOnionAndBalance(relay.address)
  });

});