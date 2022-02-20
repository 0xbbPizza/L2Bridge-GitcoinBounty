import { run, ethers } from "hardhat";
import { BigNumber, Contract} from "ethers";
import hre from 'hardhat'

// import {
//   verifyContract
//   // EtherscanVerifyRequest,
// } from "./VerifyWithEtherScan/EtherscanService";

// import {
//   toVerifyRequest,
// } from "./VerifyWithEtherScan/EtherscanVerifyContractRequest";

async function main() {
  await run("compile");
  // 100000000000000000000000000
  const accounts = await ethers.getSigners();
  
  // let addressList : string[] = [];
  // let argList : any[][] = [];

  const FakeToken = await ethers.getContractFactory("BasicToken")
  let amount:BigNumber = BigNumber.from(1000000000000)
  let fakeToken: Contract = await FakeToken.deploy(amount);
  await fakeToken.deployed()
  console.log("FakeToken address:",fakeToken.address)

  // await hre.run("verify:verify", {
  //   address: fakeToken.address,
  //   constructorArguments: [amount],
  //   contract: "contracts/FakeToken.sol:BasicToken"
  // });

  // deploy source contract
  const Source = await ethers.getContractFactory("SourceContract")
  let source: Contract = await Source.deploy(accounts[0].getAddress(),fakeToken.address)
  await source.deployed()
  console.log("sourceContract Address", source.address)

  // addressList.push(source.address)
  // argList.push([accounts[0].getAddress(),fakeToken.address])

  // deploy dest contract
  const Dest = await ethers.getContractFactory("DestinationContract")
  let dest: Contract = await Dest.deploy(accounts[0].getAddress(),fakeToken.address)
  await dest.deployed()
  console.log("destContract Address", dest.address)

  // addressList.push(dest.address)
  // argList.push([accounts[0].getAddress(),fakeToken.address])

  // for (let i = 0 ; i < addressList.length ; i++){
  //   console.log(addressList[i],argList[i])
  //   await hre.run("verify:verify", {
  //     address: addressList[i],
  //     constructorArguments: argList[i],
  //   });
  }
  
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });