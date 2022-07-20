import { Contract, providers, Signer, Wallet } from "ethers";
import { config, ethers } from "hardhat";
describe("source", function () {
  let Kovan: Signer;
  let KovanOptimismOP: Signer;
  let relay: Contract;
  let mainNet: Contract;
  let test_source: Contract;
  let test_destination: Contract;
  let dockL1_OP: Contract;
  let dockL2_OP: Contract;
  const kovanOptimismChainId = 69;
  const kovanChainId = 42;
  const defaultGasLimit = 1000000;
  const Proxy__OVM_L1CrossDomainMessenger =
    "0x4361d0F75A0186C05f971c566dC6bEa5957483fD";
  const L2_BridgeAddress = "0x4200000000000000000000000000000000000007";
  const options = {
    gasPrice: 8100000000,
    gasLimit: 1000000,
  };

  before(async function () {
    const networkKovanOptimism: any = config.networks["kovanOptimism"];
    KovanOptimismOP = new Wallet(networkKovanOptimism.accounts[0]).connect(
      new providers.JsonRpcProvider(networkKovanOptimism.url)
    );
    const networkKovan: any = config.networks["kovan"];
    Kovan = new Wallet(networkKovan.accounts[0]).connect(
      new providers.JsonRpcProvider(networkKovan.url)
    );
    // L1 delpoy Relay
    const Relay = await ethers.getContractFactory("Relay", Kovan);
    relay = await Relay.deploy();
    await relay.deployed();
    console.log("relay Address:", relay.address);

    // L1 deploy MainNet
    const MainNet = await ethers.getContractFactory("Dock_MainNet", Kovan);
    mainNet = await MainNet.deploy(relay.address);
    await mainNet.deployed();
    console.log("mainNet Address:", mainNet.address);

    // L2 deploy DockL2_OP
    const DockL2_OP = await ethers.getContractFactory(
      "DockL2_OP",
      KovanOptimismOP
    );
    dockL2_OP = await DockL2_OP.deploy(L2_BridgeAddress, 1800000);
    await dockL2_OP.deployed();
    console.log("dockL2_OP Address:", dockL2_OP.address);

    // L1 deploy  DockL1_OP
    const DockL1_OP = await ethers.getContractFactory("DockL1_OP", Kovan);
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
    const addMainNetResp = await relay.addDock(mainNet.address, kovanChainId);
    await addMainNetResp.wait();
    console.log("addMainNetResp hash:", addMainNetResp.hash);

    // Relay addDock
    const addDockResp = await relay.addDock(
      dockL1_OP.address,
      kovanOptimismChainId
    );
    await addDockResp.wait();
    console.log("addDock hash:", addDockResp.hash);

    // Relay addDock
    const addDock2Resp = await relay.addDock(dockL2_OP.address, kovanChainId);
    await addDockResp.wait();
    console.log("addDock2Resp hash:", addDock2Resp.hash);

    // L2 deploy Test_source
    const Test_source = await ethers.getContractFactory(
      "Test_source",
      KovanOptimismOP
    );
    test_source = await Test_source.deploy(dockL2_OP.address);
    await test_source.deployed();
    console.log("test_source Address:", test_source.address);

    // L1 deploy Test_destination
    const Test_destination = await ethers.getContractFactory(
      "Test_destination",
      Kovan
    );
    test_destination = await Test_destination.deploy(mainNet.address);
    await test_destination.deployed();
    console.log("test_destination Address:", test_destination.address);

    // L2 addDestDomain
    const addDestDomainResp = await test_source.addDestDomain(
      kovanChainId,
      test_destination.address,
      options
    );
    await addDestDomainResp.wait();
    console.log("addDestDomain hash:", addDestDomainResp.hash);

    // L1 addSourceDomain
    const addSourceDomainResp = await test_destination.addDomain(
      kovanOptimismChainId,
      test_source.address
    );
    await addSourceDomainResp.wait();
    console.log("addSourceDomain hash:", addSourceDomainResp.hash);
  });

  it("Dock_Mainnet.callOtherDomainFunction", async function () {
    function timeout(ms: number) {
      return new Promise((resolve) => setTimeout(resolve, ms));
    }
    const message = "hello world from L2";
    const sendMessageResp = await test_source.sendMessage(
      kovanChainId,
      message,
      options
    );
    await sendMessageResp.wait();
    console.log("sendMessageResp hash:", sendMessageResp.hash);
    await timeout(120000);
    console.log(await test_destination.status());
    console.log("dockl1 status", await dockL1_OP.status());
    // expect(await test_destination.message()).to.equal(message);
    // expect(await test_destination.chainId()).to.equal(kovanChainId);
  });
});
