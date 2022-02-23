import { run, ethers } from "hardhat";
import { BigNumber, Contract,  providers , Wallet} from "ethers";


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


async function main() {

  await run("compile");
  // const accounts = await ethers.getSigners();
  const l1Provider = new providers.JsonRpcProvider(process.env.rinkebyRPC)
  const l2Provider = new providers.JsonRpcProvider(process.env.rb_rinkebyRPC)
  const l1Wallet = new Wallet(getPrivateKey()[0], l1Provider)
  const l2Wallet = new Wallet(getPrivateKey()[0], l2Provider)


  const FakeToken = await (await ethers.getContractFactory("BasicToken")).connect(l2Wallet)
  let amount:BigNumber = BigNumber.from(8000000000000000) // no use , the amount is in contract
  let fakeToken: Contract = await FakeToken.deploy(amount);
  await fakeToken.deployed()
  console.log("FakeToken address:",fakeToken.address)

  // deploy source contract
  // let arbsys_L2 = ethers.utils.getAddress("0x0000000000000000000000000000000000000064")
  // const Source = await (await ethers.getContractFactory("SourceContract")).connect(l2Wallet)
  // let source: Contract = await Source.deploy(arbsys_L2,fakeToken.address)
  // await source.deployed()
  // console.log("sourceContract Address", source.address)

  // let bridgeAddress = ethers.utils.getAddress("0x9a28e783c47bbeb813f32b861a431d0776681e95")
  // const Relay = await (await ethers.getContractFactory("Relay")).connect(l1Wallet)
  // let relay = await Relay.deploy(bridgeAddress, source.address)
  // await relay.deployed()
  // console.log("Relay Address", relay.address)

  // let aamount = await fakeToken.balanceOf(l2Wallet.getAddress())
  // let fee = BigNumber.from(0)
  
  // await fakeToken.connect(l2Wallet).approve(source.address,aamount)
  // await source.connect(l2Wallet).transfer(aamount,fee)

  // await source.connect(l2Wallet).extractHashOnionAndBalance(relay.address)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });