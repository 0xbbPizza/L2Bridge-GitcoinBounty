import { Contract, providers, Wallet } from "ethers";
import { L2TransactionReceipt, L2ToL1MessageStatus } from "@arbitrum/sdk";
import { config, ethers } from "hardhat";
import { expect } from "chai";
import { timeout } from "./utils";
describe("ArbitrumToPolygon", function () {
  let GoerliProvider: any;
  let GoerliArbitrumProvider: any;
  let MumbaiPolygonProvider: any;
  let Goerli: Wallet;
  let GoerliArbitrum: Wallet;
  let MumbaiPolygon: Wallet;
  let relay: Contract;
  let mainNet: Contract;
  let test_sourceGoerli: Contract;
  let test_sourceGoerliArbitrum: Contract;
  let test_destinationGoerli: Contract;
  let test_destinationMumbaiPolygon: Contract;
  let dockL1_Arb: Contract;
  let dockL1_Go: Contract;
  let dockL2_Arb: Contract;
  let dockL2_Po: Contract;
  const GoerliChainId = 5;
  const GoerliArbitrumChainId = 421613;
  const MumbaiPolygonChainId = 80001;
  const Arb_L1Inbox = "0x6bebc4925716945d46f0ec336d5c2564f419682c";
  const Arb_BridgeAddress = "0x0000000000000000000000000000000000000064";
  const FxRoot = "0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA";
  const CheckpointManager = "0x2890bA17EfE978480615e330ecB65333b880928e";
  const FxChild = "0xCf73231F28B7331BBe3124B907840A94851f9f11";
  const options = {
    gasLimit: 1000000,
    maxPriorityFeePerGas: 2500000000,
    maxFeePerGas: 3500000000,
  };
  before(async function () {
    // Messages are sent from GoerliArbitrum(L2) to MumbaiPolygon(L2) through relay point Goerli(L1).
    // GoerliArbitrum(L2) -> Goerli(L1) -> MumbaiPolygon(L2)
    const networkGoerli: any = config.networks["goerli"];
    const networkGoerliArbitrum: any = config.networks["goerliArbitrum"];
    const networkMumbaiPolygon: any = config.networks["goerliPolygon"];
    GoerliProvider = new providers.JsonRpcProvider(networkGoerli.url);
    GoerliArbitrumProvider = new providers.JsonRpcProvider(
      networkGoerliArbitrum.url
    );
    MumbaiPolygonProvider = new providers.JsonRpcProvider(
      networkMumbaiPolygon.url
    );
    Goerli = new Wallet(networkGoerli.accounts[0], GoerliProvider);
    GoerliArbitrum = new Wallet(
      networkGoerliArbitrum.accounts[0],
      GoerliArbitrumProvider
    );
    MumbaiPolygon = new Wallet(
      networkMumbaiPolygon.accounts[0],
      MumbaiPolygonProvider
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

    // L2 deploy DockPair_ArbL2
    const DockL2_Arb = await ethers.getContractFactory(
      "DockL2_Arb",
      GoerliArbitrum
    );
    dockL2_Arb = await DockL2_Arb.deploy(Arb_BridgeAddress);
    await dockL2_Arb.deployed();
    console.log("dockL2_Arb Address:", dockL2_Arb.address);

    // L2 deploy DockPair_Polygon
    const DockL2_Po = await ethers.getContractFactory(
      "DockL2_Po",
      MumbaiPolygon
    );
    dockL2_Po = await DockL2_Po.deploy(FxChild);
    await dockL2_Po.deployed();
    console.log("dockL2_Po Address:", dockL2_Po.address);

    // L1 deploy DockPair_ArbL1 (DockPair_ArbL2)
    const DockL1_Arb = await ethers.getContractFactory("DockL1_Arb", Goerli);
    dockL1_Arb = await DockL1_Arb.deploy(
      dockL2_Arb.address,
      Arb_L1Inbox,
      relay.address
    );
    await dockL1_Arb.deployed();
    console.log("dockL1_Arb Address:", dockL1_Arb.address);

    // L1 deploy  DockL1_GO (DockPair_Polygon)
    const DockL1_Go = await ethers.getContractFactory("DockL1_Go", Goerli);
    dockL1_Go = await DockL1_Go.deploy(
      dockL2_Po.address,
      FxRoot,
      relay.address,
      CheckpointManager
    );
    await dockL1_Go.deployed();
    console.log("dockL1_Go Address:", dockL1_Go.address);

    // L2 DockPair_ArbL2 bind DockPair_ArbL1
    const bindDockPair_ArbL1Resp = await dockL2_Arb.bindDock_L1(
      dockL1_Arb.address
    );
    await bindDockPair_ArbL1Resp.wait();
    console.log("bindDockPair_ArbL1Resp Hash:", bindDockPair_ArbL1Resp.hash);

    // L2 DockPair_Polygon bind DockL1_Go
    const bindDock_L1Resp = await dockL2_Po.bindDock_L1(
      dockL1_Go.address,
      options
    );
    await bindDock_L1Resp.wait();
    console.log("bindDockL1_Go Hash:", bindDock_L1Resp.hash);

    // Relay addMainNet
    const addMainNetResp = await relay.addDock(mainNet.address, GoerliChainId);
    await addMainNetResp.wait();
    console.log("addMainNetResp hash:", addMainNetResp.hash);

    // Relay addDock for DockPair_ArbL1
    const addDockWithDockPair_ArbL1Resp = await relay.addDock(
      dockL1_Arb.address,
      GoerliArbitrumChainId
    );
    await addDockWithDockPair_ArbL1Resp.wait();
    console.log(
      "addDockWithDockPair_ArbL1Resp Hash:",
      addDockWithDockPair_ArbL1Resp.hash
    );

    // Relay addDock for dockL1_Go
    const addDockWithDockL1_GoResp = await relay.addDock(
      dockL1_Go.address,
      MumbaiPolygonChainId
    );
    await addDockWithDockL1_GoResp.wait();
    console.log(
      "addDockWithDockL1_GoResp Hash:",
      addDockWithDockL1_GoResp.hash
    );

    // L2 (GoerliArbitrum) deploy Test_source
    const Test_sourceGoerliArbitrum = await ethers.getContractFactory(
      "Test_source",
      GoerliArbitrum
    );
    test_sourceGoerliArbitrum = await Test_sourceGoerliArbitrum.deploy(
      dockL2_Arb.address
    );
    await test_sourceGoerliArbitrum.deployed();
    console.log(
      "test_sourceGoerliArbitrum Address:",
      test_sourceGoerliArbitrum.address
    );

    // L1 (Goerli) deploy Test_destination
    const Test_destinationGoerli = await ethers.getContractFactory(
      "Test_destination",
      Goerli
    );
    test_destinationGoerli = await Test_destinationGoerli.deploy(
      mainNet.address
    );
    await test_destinationGoerli.deployed();
    console.log(
      "test_destinationGoerli Address:",
      test_destinationGoerli.address
    );

    // L1 (Goerli) deploy Test_source
    const Test_sourceGoerli = await ethers.getContractFactory(
      "Test_source",
      Goerli
    );
    test_sourceGoerli = await Test_sourceGoerli.deploy(mainNet.address);
    await test_sourceGoerli.deployed();
    console.log("test_sourceGoerli Address:", test_sourceGoerli.address);

    // L2 (MumbaiPolygon) deploy Test_destination
    const Test_destinationMumbaiPolygon = await ethers.getContractFactory(
      "Test_destination",
      MumbaiPolygon
    );
    test_destinationMumbaiPolygon = await Test_destinationMumbaiPolygon.deploy(
      dockL2_Po.address
    );
    await test_destinationMumbaiPolygon.deployed();
    console.log(
      "test_destinationMumbaiPolygon Address:",
      test_destinationMumbaiPolygon.address
    );

    // L2 (GoerliArbitrum) addDestDomainGoerli
    const addDestDomainGoerliResp =
      await test_sourceGoerliArbitrum.addDestDomain(
        GoerliChainId,
        test_destinationGoerli.address
      );
    await addDestDomainGoerliResp.wait();
    console.log("addDestDomainGoerliResp hash:", addDestDomainGoerliResp.hash);

    // L1 (Goerli) addSourceDomainGoerliArbitrum
    const addSourceDomainGoerliArbitrumResp =
      await test_destinationGoerli.addDomain(
        GoerliArbitrumChainId,
        test_sourceGoerliArbitrum.address
      );
    await addSourceDomainGoerliArbitrumResp.wait();
    console.log(
      "addSourceDomainGoerliArbitrumResp Hash:",
      addSourceDomainGoerliArbitrumResp.hash
    );

    // L1 (Goerli) addDestDomainMumbaiPolygon
    const addDestDomainMumbaiPolygonResp =
      await test_sourceGoerli.addDestDomain(
        MumbaiPolygonChainId,
        test_destinationMumbaiPolygon.address
      );
    await addDestDomainMumbaiPolygonResp.wait();
    console.log(
      "addDestDomainMumbaiPolygonResp Hash:",
      addDestDomainMumbaiPolygonResp.hash
    );

    // L2 (MumbaiPolygon) addSourceDomainGoerli
    const addSourceDomainGoerliResp =
      await test_destinationMumbaiPolygon.addDomain(
        GoerliChainId,
        test_sourceGoerli.address
      );
    await addSourceDomainGoerliResp.wait();
    console.log(
      "addSourceDomainGoerliResp Hash:",
      addSourceDomainGoerliResp.address
    );
  });

  it("DockRelayArbitrumToPolygon", async function () {
    const messageInfo = [
      MumbaiPolygonChainId,
      "This message comes from GoerliArbitrum",
    ];

    // sendMessage from L2 (GoerliArbitrum) to L1 (Goerli)
    const sendMessageToGoerliTX = await test_sourceGoerliArbitrum.sendMessage(
      Goerli.address,
      GoerliChainId,
      0,
      0,
      0,
      messageInfo[1]
    );
    const sendMessageToGoerliResp = await sendMessageToGoerliTX.wait();
    console.log(
      "sendMessageToGoerliResp Hash:",
      sendMessageToGoerliResp.transactionHash
    );
    const txnHash = sendMessageToGoerliResp.transactionHash;
    if (!txnHash)
      throw new Error(
        "Provide a transaction hash of an L2 transaction that sends an L2 to L1 message"
      );
    if (!txnHash.startsWith("0x") || txnHash.trim().length != 66)
      throw new Error(`Hmm, ${txnHash} doesn't look like a txn hash...`);
    const receipt = await GoerliArbitrumProvider.getTransactionReceipt(txnHash);
    const l2Receipt = new L2TransactionReceipt(receipt);
    const messages = await l2Receipt.getL2ToL1Messages(Goerli);
    const l2ToL1Msg = messages[0];
    if (
      (await l2ToL1Msg.status(GoerliArbitrumProvider)) ==
      L2ToL1MessageStatus.EXECUTED
    ) {
      console.log(`Message already executed! Nothing else to do here`);
      process.exit(1);
    }
    // The time here is 1 hour.
    const timeToWaitMs = 1000 * 60;
    console.log(
      "Waiting for the outbox entry to be created. This only happens when the L2 block is confirmed on L1, ~1 week after it's creation."
    );
    await l2ToL1Msg.waitUntilReadyToExecute(
      GoerliArbitrumProvider,
      timeToWaitMs
    );
    console.log("Outbox entry exists! Trying to execute now");
    const proofInfo = await l2ToL1Msg.getOutboxProof(GoerliArbitrumProvider);
    // In the official document, the parameter here is proofInfo, but it will not work. It is useful to change it to GoerliArbitrumProvider, but I don't know why
    const res = await l2ToL1Msg.execute(GoerliArbitrumProvider);
    const rec = await res.wait();
    console.log("Done! Your transaction is executed", rec);

    // sendMessage from L1 (Goerli) to L2 (MumbaiPolygon)
    const messageAgain = await test_destinationGoerli.message();
    const sendMessageToMumbaiPolygonTX = await test_sourceGoerli.sendMessage(
      MumbaiPolygon.address,
      MumbaiPolygonChainId,
      0,
      0,
      0,
      messageAgain
    );
    const sendMessageToMumbaiPolygonResp =
      await sendMessageToMumbaiPolygonTX.wait();
    console.log(
      "sendMessageToMumbaiPolygonResp Hash:",
      sendMessageToMumbaiPolygonResp.transactionHash
    );

    // It takes about 25 to 45 minutes during this period.
    await timeout(50);
    console.log(await test_destinationMumbaiPolygon.message());

    expect(await test_destinationMumbaiPolygon.message()).to.equal(
      messageInfo[1]
    );
    expect(await test_destinationMumbaiPolygon.chainId()).to.equal(
      MumbaiPolygonChainId
    );
  });
});
