import { BigNumber } from "ethers";
import { ethers, run } from "hardhat";

async function main() {
  await run("compile");
  const accounts = await ethers.getSigners();

  const chainId = await accounts[0].getChainId();
  console.log("chainId", chainId);
  const options = {
    gasLimit: 3000000,
  };

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
  const addResp = await relay.addDock(dock_Mainnet.address, chainId, options);
  await addResp.wait();
  // Deploy DToken
  const DToken = await ethers.getContractFactory("DToken");
  let dToken = await DToken.deploy("Orbiter DToken", "DAI", 18);
  await dToken.deployed();
  console.log("dTokenContract Address", dToken.address);

  // deploy dest contract
  const Dest = await ethers.getContractFactory("NewDestination");
  let dest = await Dest.deploy(
    tokenAddress,
    dToken.address,
    dock_Mainnet.address
  );
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

  // add 1 to 4
  await dest.addDomain(chainId, source.address);

  // add 4 to 1
  await source.addDestDomain(chainId, dest.address);

  // deploy PToken contract
  const PToken = await ethers.getContractFactory("PToken");
  let pToken = await PToken.deploy(dest.address);
  await pToken.deployed();
  console.log("pTokenContract Adddress", pToken.address);

  await dest.bindPTokenAddress(pToken.address);
  // DToken initialize
  const iResp = await dToken.initialize(
    tokenAddress,
    dest.address,
    pToken.address,
    ethers.utils.parseEther("1"),
    ethers.utils.parseEther("0.004"),
    ethers.utils.parseEther("0.011"),
    ethers.utils.parseEther("0.008"),
    ethers.utils.parseEther("0.008")
  );
  await iResp.wait();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
