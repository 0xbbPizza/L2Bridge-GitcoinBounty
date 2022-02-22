import { run, ethers } from "hardhat";
import { BigNumber, Contract} from "ethers";


async function main() {
  await run("compile");
  const accounts = await ethers.getSigners();

  const FakeToken = await ethers.getContractFactory("BasicToken")
  let amount:BigNumber = BigNumber.from(8000000000000000) // no use , the amount is in contract
  let fakeToken: Contract = await FakeToken.deploy(amount);
  await fakeToken.deployed()
  console.log("FakeToken address:",fakeToken.address)

  // deploy source contract
  const Source = await ethers.getContractFactory("SourceContract")
  let source: Contract = await Source.deploy(accounts[0].getAddress(),fakeToken.address)
  await source.deployed()
  console.log("sourceContract Address", source.address)

  // deploy dest contract
  const Dest = await ethers.getContractFactory("DestinationContract")
  let dest: Contract = await Dest.deploy(accounts[0].getAddress(),fakeToken.address)
  await dest.deployed()
  console.log("destContract Address", dest.address)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });