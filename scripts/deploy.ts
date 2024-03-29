import { ethers, run } from "hardhat";
import { getGoerliFastPerGas, getChainId } from "../test/utils";
async function main() {
  await run("compile");
  const accounts = await ethers.getSigners();
  let chainId = await accounts[0].getChainId();
  let tmp = getChainId(chainId);
  tmp !== undefined ? (chainId = tmp) : null;
  console.log("chainId", chainId);
  let tokenAddress = process.env["TOKEN_ADDRESS"];
  if (!tokenAddress) {
    const FakeToken = await ethers.getContractFactory("BasicToken");
    let fakeToken = await FakeToken.deploy(ethers.utils.parseEther("80000"));
    await fakeToken.deployed();
    // For not deployed —— start
    await fakeToken.transfer(
      fakeToken.address,
      ethers.utils.parseEther("68000")
    );
    await fakeToken.transfer(
      "0x49377441951437beE356D7d90a16dFF97C66fBB0",
      ethers.utils.parseEther("10000")
    );
    // end
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
  const addResp = await relay.addDock(
    dock_Mainnet.address,
    chainId
    // await getGoerliFastPerGas()
  );
  await addResp.wait();
  // Deploy DToken
  const DToken = await ethers.getContractFactory("DToken");
  let dToken = await DToken.deploy("Orbiter DToken", "ETH", 18);
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
  await dest.addDomain(
    chainId,
    source.address
    // await getGoerliFastPerGas()
  );

  // add 4 to 1
  await source.addDestDomain(
    chainId,
    dest.address
    // await getGoerliFastPerGas()
  );

  // deploy PToken contract
  const PToken = await ethers.getContractFactory("PToken");
  let pToken = await PToken.deploy(dest.address);
  await pToken.deployed();
  console.log("pTokenContract Adddress", pToken.address);

  await dest.bindPTokenAddress(
    pToken.address
    // await getGoerliFastPerGas()
  );
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
    // await getGoerliFastPerGas()
  );
  await iResp.wait();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
