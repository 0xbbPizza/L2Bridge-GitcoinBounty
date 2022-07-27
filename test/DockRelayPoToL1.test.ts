import { BigNumber, Contract, providers, Signer, Wallet } from "ethers";
import { config, ethers, network } from "hardhat";
import { expect } from "chai";
describe("GoerliToPolygon", function () {
  let GoerliPolygonProvider: any;
  let GoerliProvider: any;
  let Goerli: Wallet;
  let GoerliPolygon: Wallet;
  let relay: Contract;
  let mainNet: Contract;
  let test_source: Contract;
  let test_destination: Contract;
  let dockL1_Go: Contract;
  let dockL2_Po: Contract;
  const GoerliPolygonChainId = 80001;
  const GoerliChainId = 5;
  const FxRoot = "0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA";
  const CheckpointManager = "0x2890bA17EfE978480615e330ecB65333b880928e";
  const FxChild = "0xCf73231F28B7331BBe3124B907840A94851f9f11";
  const options = {
    gasLimit: 1000000,
    maxPriorityFeePerGas: 2500000000,
    maxFeePerGas: 3500000000,
  };
  before(async function () {
    // send message to Goerli(L1) from Polygon Mumbai(L2)
    const networkGoerli: any = config.networks["goerli"];
    const networkGoerliPolygon: any = config.networks["goerliPolygon"];
    GoerliProvider = new providers.JsonRpcProvider(networkGoerli.url);
    GoerliPolygonProvider = new providers.JsonRpcProvider(
      networkGoerliPolygon.url
    );
    Goerli = new Wallet(networkGoerli.accounts[0], GoerliProvider);
    GoerliPolygon = new Wallet(
      networkGoerliPolygon.accounts[0],
      GoerliPolygonProvider
    );

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

    // L2 deploy DockPair_Po
    const DockL2_Po = await ethers.getContractFactory(
      "DockL2_Po",
      GoerliPolygon
    );
    dockL2_Po = await DockL2_Po.deploy(FxChild);
    await dockL2_Po.deployed();
    console.log("dockL2_Po Address:", dockL2_Po.address);

    // L1 deploy  DockL1_GO
    const DockL1_Go = await ethers.getContractFactory("DockL1_Go", Goerli);
    dockL1_Go = await DockL1_Go.deploy(
      dockL2_Po.address,
      FxRoot,
      relay.address,
      CheckpointManager
    );
    await dockL1_Go.deployed();
    console.log("dockL1_Go Address:", dockL1_Go.address);

    // L2 bindDockL1_Go
    const bindDock_L1Resp = await dockL2_Po.bindDock_L1(
      dockL1_Go.address,
      options
    );
    await bindDock_L1Resp.wait();
    console.log("bindDockL1_Go hash:", bindDock_L1Resp.hash);

    // Relay addMainNet
    const addMainNetResp = await relay.addDock(mainNet.address, GoerliChainId);
    await addMainNetResp.wait();
    console.log("addMainNetResp hash:", addMainNetResp.hash);

    // Relay addDock
    const addDockResp = await relay.addDock(
      dockL1_Go.address,
      GoerliPolygonChainId
    );
    await addDockResp.wait();
    console.log("addDock hash:", addDockResp.hash);

    // L2 deploy Test_source
    const Test_source = await ethers.getContractFactory(
      "Test_source",
      GoerliPolygon
    );
    test_source = await Test_source.deploy(dockL2_Po.address);
    await test_source.deployed();
    console.log("test_source Address:", test_source.address);

    // L2 deploy Test_destination
    const Test_destination = await ethers.getContractFactory(
      "Test_destination",
      Goerli
    );
    test_destination = await Test_destination.deploy(mainNet.address);
    await test_destination.deployed();
    console.log("test_destination Address:", test_destination.address);

    // L2 addDestDomain
    const addDestDomainResp = await test_source.addDestDomain(
      GoerliChainId,
      test_destination.address,
      options
    );
    await addDestDomainResp.wait();
    console.log("addDestDomain hash:", addDestDomainResp.hash);

    // L1 addSourceDomain
    const addSourceDomainResp = await test_destination.addDomain(
      GoerliPolygonChainId,
      test_source.address
    );
    await addSourceDomainResp.wait();
    console.log("addSourceDomain hash:", addSourceDomainResp.hash);
  });

  it("DockRelayGoToPo", async function () {
    function timeout(ms: number) {
      return new Promise((resolve) => setTimeout(resolve, ms));
    }

    const messageInfo = [
      GoerliChainId,
      "This message comes from GoerliPolygon",
    ];

    const sendMessageTX = await test_source.sendMessage(
      Goerli.address,
      messageInfo[0],
      0,
      0,
      0,
      messageInfo[1],
      options
    );
    const sendMessageResp = await sendMessageTX.wait();
    console.log("sendMessageResp hash:", sendMessageResp.transactionHash);
    await timeout(180000);
    console.log(await test_destination.message());
    expect(await test_destination.message()).to.equal(messageInfo[1]);
    expect(await test_destination.chainId()).to.equal(GoerliChainId);
  });
});
