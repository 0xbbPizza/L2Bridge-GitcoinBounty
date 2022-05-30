import { BigNumber } from "ethers";
import { ethers, run } from "hardhat";

async function main() {
  await run("compile");
  const accounts = await ethers.getSigners();

  const FakeToken = await ethers.getContractFactory("BasicToken");
  let amount = BigNumber.from(8000000000000000); // no use , the amount is in contract
  let fakeToken = await FakeToken.deploy(amount);
  await fakeToken.deployed();
  console.log("FakeToken address:", fakeToken.address);

  // deploy source contract
  const Source = await ethers.getContractFactory("SourceContract");
  let source = await Source.deploy(accounts[0].getAddress(), fakeToken.address);
  await source.deployed();
  console.log("sourceContract Address", source.address);

  // deploy dest contract
  const Dest = await ethers.getContractFactory("NewDestination");
  let dest = await Dest.deploy(fakeToken.address);
  await dest.deployed();
  console.log("destContract Address", dest.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
