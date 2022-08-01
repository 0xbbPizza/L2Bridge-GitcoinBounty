import { Contract, providers, Signer, Wallet } from "ethers";
import { config, ethers, hardhatArguments, network } from "hardhat";
import { expect } from "chai";
import { timeout } from "./utils";
describe("source", function () {
  // let accounts: Signer[];
  // let source: Contract;
  // let dest: Contract;
  let Goerli: Wallet;
  let GoerliOptimism: Wallet;
  let relay: Contract;
  let mainNet: Contract;
  let test_source: Contract;
  let test_destination: Contract;
  let dockL1_OP: Contract;
  let dockL2_OP: Contract;
  const GoerliOptimismChainId = 69;
  const GoerliChainId = 42;
  const defaultGasLimit = 1000000;
  const Proxy__OVM_L1CrossDomainMessenger =
    "0x5086d1eEF304eb5284A0f6720f79403b4e9bE294";
  const L2_BridgeAddress = "0x4200000000000000000000000000000000000007";
  const options = {
    gasPrice: 1000000000,
    gasLimit: 85000,
  };
  before(async function () {
    const networkGoerli: any = config.networks["goerli"];
    const networkGoerliOptimism: any = config.networks["goerliOptimism"];
    Goerli = new Wallet(networkGoerli.accounts[0]).connect(
      new providers.JsonRpcProvider(networkGoerli.url)
    );
    GoerliOptimism = new Wallet(networkGoerliOptimism.accounts[0]).connect(
      new providers.JsonRpcProvider(networkGoerliOptimism.url)
    );

    //   // accounts = await ethers.getSigners();
    //   // const chainId = await accounts[0].getChainId();
    //   // console.log("chainId", chainId);
    //   // // 3

    // const Relay = await ethers.getContractFactory("Relay");
    // const relay = await Relay.deploy();
    // await relay.deployed();
    // console.log("relay Address:", relay.address);

    //   // // 2
    //   // const Dock_Mainnet = await ethers.getContractFactory("Dock_MainNet");
    //   // const dock_Mainnet = await Dock_Mainnet.deploy(relay.address);
    //   // await dock_Mainnet.deployed();
    //   // console.log("dock_Mainnet Address:", dock_Mainnet.address);

    //   // // set 2 to 3
    //   // const addDockResp = await relay.addDock(dock_Mainnet.address, chainId);
    //   // await addDockResp.wait();
    //   // console.log("addDock hash:", addDockResp.hash);

    //   // // 6
    //   // const Test_destination = await ethers.getContractFactory(
    //   //   "Test_destination"
    //   // );
    //   // const test_destination = await Test_destination.deploy(
    //   //   dock_Mainnet.address
    //   // );
    //   // await test_destination.deployed();
    //   // console.log("test_destination Address:", test_destination.address);
    //   // dest = test_destination;

    //   // // 7
    //   // const Test_source = await ethers.getContractFactory("Test_source");
    //   // const test_source = await Test_source.deploy(dock_Mainnet.address);
    //   // await test_source.deployed();
    //   // console.log("test_source Address:", test_source.address);
    //   // source = test_source;

    //   // // set 7 to 6
    //   // const addDomainResp = await test_destination.addDomain(
    //   //   chainId,
    //   //   test_source.address
    //   // );
    //   // await addDomainResp.wait();
    //   // console.log("addDomainResp.hash:", addDomainResp.hash);

    //   // // set 6 to 7
    //   // const addDestDomainResp = await test_source.addDestDomain(
    //   //   chainId,
    //   //   test_destination.address
    //   // );
    //   // await addDestDomainResp.wait();
    //   // console.log("addDestDomainResp.hash:", addDestDomainResp.hash);

    // L1 delpoy Realy
    const Relay = await ethers.getContractFactory("Relay", Goerli);
    relay = await Relay.deploy();
    await relay.deployed();
    console.log("relay Address:", relay.address);

    // L1 deploy MainNet
    const MainNet = await ethers.getContractFactory("Dock_MainNet", Goerli);
    mainNet = await MainNet.deploy(relay.address);
    await mainNet.deployed();
    console.log("mainNet Address:", mainNet.address);

    // L2 deploy DockL2_OP
    const DockL2_OP = await ethers.getContractFactory(
      "DockL2_OP",
      GoerliOptimism
    );
    dockL2_OP = await DockL2_OP.deploy(L2_BridgeAddress, defaultGasLimit);
    await dockL2_OP.deployed();
    console.log("dockL2_OP Address:", dockL2_OP.address);

    // L1 deploy  DockL1_OP
    const DockL1_OP = await ethers.getContractFactory("DockL1_OP", Goerli);
    dockL1_OP = await DockL1_OP.deploy(
      dockL2_OP.address,
      Proxy__OVM_L1CrossDomainMessenger,
      relay.address,
      defaultGasLimit
    );
    await dockL1_OP.deployed();
    console.log("dockL1_OP Address:", dockL1_OP.address);

    // L2 bindDock_L1
    const bindDock_L1Resp = await dockL2_OP.bindDock_L1(
      dockL1_OP.address,
      options
    );
    await bindDock_L1Resp.wait();
    console.log("bindDock_L1 hash:", bindDock_L1Resp.hash);

    // Relay addMainNet
    const addMainNetResp = await relay.addDock(mainNet.address, GoerliChainId);
    await addMainNetResp.wait();
    console.log("addMainNetResp hash:", addMainNetResp.hash);

    // Relay addDock
    const addDockResp = await relay.addDock(
      dockL1_OP.address,
      GoerliOptimismChainId
    );
    await addDockResp.wait();
    console.log("addDock hash:", addDockResp.hash);

    // L1 deploy Test_source
    const Test_source = await ethers.getContractFactory("Test_source", Goerli);
    test_source = await Test_source.deploy(mainNet.address);
    await test_source.deployed();
    console.log("test_source Address:", test_source.address);

    // L2 deploy Test_destination
    const Test_destination = await ethers.getContractFactory(
      "Test_destination",
      GoerliOptimism
    );
    test_destination = await Test_destination.deploy(dockL2_OP.address);
    await test_destination.deployed();
    console.log("test_destination Address:", test_destination.address);

    // L1 addDestDomain
    const addDestDomainResp = await test_source.addDestDomain(
      GoerliOptimismChainId,
      test_destination.address
    );
    await addDestDomainResp.wait();
    console.log("addDestDomain hash:", addDestDomainResp.hash);

    // L2 addSourceDomain
    const addSourceDomainResp = await test_destination.addDomain(
      GoerliChainId,
      test_source.address,
      options
    );
    await addSourceDomainResp.wait();
    console.log("addSourceDomain hash:", addSourceDomainResp.hash);
  });

  it("DockRelayL1ToOp", async function () {
    const message = "hello world from L1 to Op";
    const sendMessageResp = await test_source.sendMessage(
      GoerliOptimismChainId,
      message
    );
    await sendMessageResp.wait();
    console.log("sendMessageResp hash:", sendMessageResp.hash);
    await timeout(2);
    expect(await test_destination.message()).to.equal(message);
    expect(await test_destination.chainId()).to.equal(GoerliOptimismChainId);
  });
});
