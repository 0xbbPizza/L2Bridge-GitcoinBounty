import { Contract, providers, Wallet } from "ethers";
import { config, ethers } from "hardhat";
import { expect } from "chai";
describe("ArbitrumToPolygon", function () {
  let MumbaiPolygonProvider: any;
  let GoerliArbitrumProvider: any;
  let GoerliArbitrum: Wallet;
  let MumbaiPolygon: Wallet;
  let relay: Contract;
  let mainNet: Contract;
  let test_source: Contract;
  let test_destination: Contract;
  let dockL1_Go: Contract;
  let dockL2_Po: Contract;
  const MumbaiPolygonChainId = 80001;
  const GoerliArbitrumChainId = 421613;
  const FxRoot = "0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA";
  const CheckpointManager = "0x2890bA17EfE978480615e330ecB65333b880928e";
  const FxChild = "0xCf73231F28B7331BBe3124B907840A94851f9f11";
  const options = {
    gasLimit: 1000000,
    maxPriorityFeePerGas: 2500000000,
    maxFeePerGas: 3500000000,
  };
  before(async function () {
    // send message to MumbaiPolygon(L2) from GoerliArbitrum(L1)
    const networkGoerliArbitrum: any = config.networks["goerliArbitrum"];
    const networkMumbaiPolygon: any = config.networks["goerliPolygon"];
    GoerliArbitrumProvider = new providers.JsonRpcProvider(
      networkGoerliArbitrum.url
    );
    MumbaiPolygonProvider = new providers.JsonRpcProvider(
      networkMumbaiPolygon.url
    );
    GoerliArbitrum = new Wallet(
      networkGoerliArbitrum.accounts[0],
      GoerliArbitrumProvider
    );
    MumbaiPolygon = new Wallet(
      networkMumbaiPolygon.accounts[0],
      MumbaiPolygonProvider
    );

    // L1 delpoy Realy
    const Relay = await ethers.getContractFactory("Relay", GoerliArbitrum);
    relay = await Relay.deploy();
    await relay.deployed();
    console.log("relay Address:", relay.address);

    // L1 deploy MainNet
    const MainNet = await ethers.getContractFactory(
      "Dock_MainNet",
      GoerliArbitrum
    );
    mainNet = await MainNet.deploy(relay.address);
    await mainNet.deployed();
    console.log("mainNet Address:", mainNet.address);

    // L2 deploy DockPair_Po
    const DockL2_Po = await ethers.getContractFactory(
      "DockL2_Po",
      MumbaiPolygon
    );
    dockL2_Po = await DockL2_Po.deploy(FxChild);
    await dockL2_Po.deployed();
    console.log("dockL2_Po Address:", dockL2_Po.address);

    // L1 deploy  DockL1_GO
    const DockL1_Go = await ethers.getContractFactory(
      "DockL1_Go",
      GoerliArbitrum
    );
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
    const addMainNetResp = await relay.addDock(
      mainNet.address,
      GoerliArbitrumChainId
    );
    await addMainNetResp.wait();
    console.log("addMainNetResp hash:", addMainNetResp.hash);

    // Relay addDock
    const addDockResp = await relay.addDock(
      dockL1_Go.address,
      MumbaiPolygonChainId
    );
    await addDockResp.wait();
    console.log("addDock hash:", addDockResp.hash);

    // L1 deploy Test_source
    const Test_source = await ethers.getContractFactory(
      "Test_source",
      GoerliArbitrum
    );
    test_source = await Test_source.deploy(mainNet.address);
    await test_source.deployed();
    console.log("test_source Address:", test_source.address);

    // L2 deploy Test_destination
    const Test_destination = await ethers.getContractFactory(
      "Test_destination",
      MumbaiPolygon
    );
    test_destination = await Test_destination.deploy(dockL2_Po.address);
    await test_destination.deployed();
    console.log("test_destination Address:", test_destination.address);

    // L1 addDestDomain
    const addDestDomainResp = await test_source.addDestDomain(
      MumbaiPolygonChainId,
      test_destination.address
    );
    await addDestDomainResp.wait();
    console.log("addDestDomain hash:", addDestDomainResp.hash);

    // L2 addSourceDomain
    const addSourceDomainResp = await test_destination.addDomain(
      GoerliArbitrumChainId,
      test_source.address,
      options
    );
    await addSourceDomainResp.wait();
    console.log("addSourceDomain hash:", addSourceDomainResp.hash);
  });

  it("DockRelayArbitrumToPolygon", async function () {
    function timeout(ms: number) {
      return new Promise((resolve) => setTimeout(resolve, ms));
    }

    const messageInfo = [
      MumbaiPolygonChainId,
      "This message comes from GoerliArbitrum",
    ];

    const sendMessageTX = await test_source.sendMessage(
      MumbaiPolygon.address,
      messageInfo[0],
      0,
      0,
      0,
      messageInfo[1]
    );
    const sendMessageResp = await sendMessageTX.wait();
    console.log("sendMessageResp hash:", sendMessageResp.transactionHash);
    await timeout(180000);
    console.log(await dockL2_Po.testData());
    console.log(await test_destination.message());
    expect(await test_destination.message()).to.equal(messageInfo[1]);
    expect(await test_destination.chainId()).to.equal(MumbaiPolygonChainId);
  });
});
