import { Contract, providers, Signer, Wallet } from "ethers";
import { config, ethers, hardhatArguments, network } from "hardhat";
import { expect } from "chai";
describe("source", function () {
  // let accounts: Signer[];
  // let source: Contract;
  // let dest: Contract;
  let Kovan: Signer;
  let KovanOptimismOP: Signer;
  let raley: Contract;
  let mainNet: Contract;
  let test_source: Contract;
  let test_destination: Contract;
  let dockL1_OP: Contract;
  let dockL2_OP: Contract;
  let timestamp: Number;
  const kovanOptimismChainId = 69;
  const kovanChainId = 42;
  const defaultGasLimit = 1000000;
  const Proxy__OVM_L1CrossDomainMessenger =
    "0x4361d0F75A0186C05f971c566dC6bEa5957483fD";
  const L2_BridgeAddress = "0x4200000000000000000000000000000000000007";
  const options = {
    gasPrice: 1000000000,
    gasLimit: 85000,
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
    //   // accounts = await ethers.getSigners();
    //   // const chainId = await accounts[0].getChainId();
    //   // console.log("chainId", chainId);
    //   // // 3

    // const Raley = await ethers.getContractFactory("Relay");
    // const raley = await Raley.deploy();
    // await raley.deployed();
    // console.log("raley Address:", raley.address);

    //   // // 2
    //   // const Dock_Mainnet = await ethers.getContractFactory("Dock_MainNet");
    //   // const dock_Mainnet = await Dock_Mainnet.deploy(raley.address);
    //   // await dock_Mainnet.deployed();
    //   // console.log("dock_Mainnet Address:", dock_Mainnet.address);

    //   // // set 2 to 3
    //   // const addDockResp = await raley.addDock(dock_Mainnet.address, chainId);
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
    // =======================
    // L1 delpoy Realy
    const Raley = await ethers.getContractFactory("Relay", Kovan);
    raley = await Raley.deploy();
    await raley.deployed();
    console.log("raley Address:", raley.address);

    // L1 deploy MainNet
    const MainNet = await ethers.getContractFactory("Dock_MainNet", Kovan);
    mainNet = await MainNet.deploy(raley.address);
    await mainNet.deployed();
    console.log("mainNet Address:", mainNet.address);

    // L2 deploy DockL2_OP
    const DockL2_OP = await ethers.getContractFactory(
      "DockL2_OP",
      KovanOptimismOP
    );
    dockL2_OP = await DockL2_OP.deploy(L2_BridgeAddress, defaultGasLimit);
    await dockL2_OP.deployed();
    console.log("dockL2_OP Address:", dockL2_OP.address);

    // L1 deploy  DockL1_OP
    const DockL1_OP = await ethers.getContractFactory("DockL1_OP", Kovan);
    dockL1_OP = await DockL1_OP.deploy(
      dockL2_OP.address,
      Proxy__OVM_L1CrossDomainMessenger,
      raley.address,
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

    // Raley addMainNet
    const addMainNetResp = await raley.addDock(mainNet.address, kovanChainId);
    await addMainNetResp.wait();
    console.log("addMainNetResp hash:", addMainNetResp.hash);

    // Raley addDock
    const addDockResp = await raley.addDock(
      dockL1_OP.address,
      kovanOptimismChainId
    );
    await addDockResp.wait();
    console.log("addDock hash:", addDockResp.hash);

    // L1 deploy Test_source
    const Test_source = await ethers.getContractFactory("Test_source", Kovan);
    test_source = await Test_source.deploy(mainNet.address);
    await test_source.deployed();
    console.log("test_source Address:", test_source.address);

    // L2 deploy Test_destination
    const Test_destination = await ethers.getContractFactory(
      "Test_destination",
      KovanOptimismOP
    );
    test_destination = await Test_destination.deploy(dockL2_OP.address);
    await test_destination.deployed();
    console.log("test_destination Address:", test_destination.address);

    // L1 addDestDomain
    const addDestDomainResp = await test_source.addDestDomain(
      kovanOptimismChainId,
      test_destination.address
    );
    await addDestDomainResp.wait();
    console.log("addDestDomain hash:", addDestDomainResp.hash);

    // L2 addSourceDomain
    const addSourceDomainResp = await test_destination.addDomain(
      kovanChainId,
      test_source.address,
      options
    );
    await addSourceDomainResp.wait();
    console.log("addSourceDomain hash:", addSourceDomainResp.hash);
  });

  it("Dock_Mainnet.callOtherDomainFunction", async function () {
    function timeout(ms: number) {
      return new Promise((resolve) => setTimeout(resolve, ms));
    }
    const message = "hello world";
    const sendMessageResp = await test_source.sendMessage(
      kovanOptimismChainId,
      message
    );
    await sendMessageResp.wait();
    console.log("sendMessageResp hash:", sendMessageResp.hash);
    await timeout(180000);
    const receiveMessageResp = await test_destination.message();
    console.log("receiveMessageResp:", receiveMessageResp);
  });
  it("Dock_Mainnet.callOtherDomainFunction2", async function () {
    // 
  })
});
// const chainId = await accounts[0].getChainId();
// const massage = "hello world";
// const sendMessageResp = await source.sendMessage(chainId, massage);
// await sendMessageResp.wait();
// expect(await dest.message()).to.equal(massage);
// expect(await dest.chainId()).to.equal(chainId);
