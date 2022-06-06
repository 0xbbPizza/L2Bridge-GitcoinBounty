import { BigNumber } from "ethers";
import { ethers, run } from "hardhat";

async function main() {
  await run("compile");
  const accounts = await ethers.getSigners();

  const chainId = await accounts[0].getChainId();
  console.log("chainId", chainId);

  let tokenAddress = process.env["TOKEN_ADDRESS"];
  if (!tokenAddress) {
    const FakeToken = await ethers.getContractFactory("BasicToken");
    let fakeToken = await FakeToken.deploy(ethers.utils.parseEther("80000"));
    await fakeToken.deployed();
    tokenAddress = fakeToken.address;
  }
  console.log("Token address:", tokenAddress);

  // Deploy relay
  const Relay = await ethers.getContractFactory("Relay");
  const relay = await Relay.deploy();
  await relay.deployed();
  console.log("relay Address:", relay.address);

  // Deploy dock
  const Dock_Mainnet = await ethers.getContractFactory("Dock_MainNet");
  const dock_Mainnet = await Dock_Mainnet.deploy(relay.address);
  await dock_Mainnet.deployed();
  console.log("dock_Mainnet Address:", dock_Mainnet.address);

  // Add dock to relay
  await relay.addDock(dock_Mainnet.address, chainId);

  // deploy dest contract
  const Dest = await ethers.getContractFactory("NewDestination");
  let dest = await Dest.deploy(tokenAddress, dock_Mainnet.address);
  await dest.deployed();
  console.log("destContract Address", dest.address);

  // deploy source contract
  const Source = await ethers.getContractFactory("SourceContract");
  let source = await Source.deploy(
    tokenAddress,
    dock_Mainnet.address,
    dest.address
  );
  await source.deployed();
  console.log("sourceContract Address", source.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
