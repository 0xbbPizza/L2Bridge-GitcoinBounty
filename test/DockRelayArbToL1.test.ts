import { Contract, providers, Wallet } from "ethers";
import { config, ethers } from "hardhat";
import { expect } from "chai";
import { L2TransactionReceipt, L2ToL1MessageStatus } from "@arbitrum/sdk";
import { getPolygonMumbaiFastPerGas } from "./utils";
describe("Arb", function () {
  let GoerliArbitrumProvider: any;
  let GoerliProvider: any;
  let Goerli: Wallet;
  let GoerliArbitrum: Wallet;
  let relay: Contract;
  let mainNet: Contract;
  let test_source: Contract;
  let test_destination: Contract;
  let dockL1_AR: Contract;
  let dockL2_AR: Contract;
  const GoerliArbitrumChainId = 421613;
  const GoerliChainId = 5;
  const Proxy__OVM_L1CrossDomainMessenger =
    "0x6BEbC4925716945D46F0Ec336D5C2564F419682C";
  const L2_BridgeAddress = "0x0000000000000000000000000000000000000064";
  before(async function () {
    const networkGoerli: any = config.networks["goerli"];
    const networkGoerliArbitrum: any = config.networks["goerliArbitrum"];

    GoerliProvider = new providers.JsonRpcProvider(networkGoerli.url);
    GoerliArbitrumProvider = new providers.JsonRpcProvider(
      networkGoerliArbitrum.url
    );

    Goerli = new Wallet(networkGoerli.accounts[0], GoerliProvider);
    GoerliArbitrum = new Wallet(
      networkGoerliArbitrum.accounts[0],
      GoerliArbitrumProvider
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

    // L2 deploy DockL2_AR
    const DockL2_AR = await ethers.getContractFactory(
      "DockL2_Arb",
      GoerliArbitrum
    );
    dockL2_AR = await DockL2_AR.deploy(L2_BridgeAddress);
    await dockL2_AR.deployed();
    console.log("dockL2_AR Address:", dockL2_AR.address);

    // L1 deploy  DockL1_AR
    const DockL1_AR = await ethers.getContractFactory("DockL1_Arb", Goerli);
    dockL1_AR = await DockL1_AR.deploy(
      dockL2_AR.address,
      Proxy__OVM_L1CrossDomainMessenger,
      relay.address
    );
    await dockL1_AR.deployed();
    console.log("dockL1_AR Address:", dockL1_AR.address);

    // L2 bindDockL1_AR
    const bindDock_L1Resp = await dockL2_AR.bindDock_L1(dockL1_AR.address);
    await bindDock_L1Resp.wait();
    console.log("bindDockL1_AR hash:", bindDock_L1Resp.hash);

    // Relay addMainNet
    const addMainNetResp = await relay.addDock(mainNet.address, GoerliChainId);
    await addMainNetResp.wait();
    console.log("addMainNetResp hash:", addMainNetResp.hash);

    // Relay addDock
    const addDockResp = await relay.addDock(
      dockL1_AR.address,
      GoerliArbitrumChainId
    );
    await addDockResp.wait();
    console.log("addDock hash:", addDockResp.hash);

    // L2 deploy Test_source
    const Test_source = await ethers.getContractFactory(
      "Test_source",
      GoerliArbitrum
    );
    test_source = await Test_source.deploy(dockL2_AR.address);
    await test_source.deployed();
    console.log("test_source Address:", test_source.address);

    // L1 deploy Test_destination
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
      test_destination.address
    );
    await addDestDomainResp.wait();
    console.log("addDestDomain hash:", addDestDomainResp.hash);

    // L1 addSourceDomain
    const addSourceDomainResp = await test_destination.addDomain(
      GoerliArbitrumChainId,
      test_source.address
    );
    await addSourceDomainResp.wait();
    console.log("addSourceDomain hash:", addSourceDomainResp.hash);
  });

  it("DockRelayArbToL1", async function () {
    const messageInfo = [
      GoerliChainId,
      "This message comes from Arbitrum Goerli",
    ];
    const sendMessageTX = await test_source.sendMessage(
      Goerli.address,
      messageInfo[0],
      0,
      0,
      0,
      messageInfo[1]
    );
    const sendMessageResp = await sendMessageTX.wait();
    const txnHash = sendMessageResp.transactionHash;
    console.log("txnHash:", txnHash);

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

    // Test the number of certificates once a minute, and the estimated total time is half an hour to one hour.
    const timeToWaitMs = 1000 * 60;
    console.log(
      "Waiting for the outbox entry to be created. This only happens when the L2 block is confirmed on L1, ~1 week after it's creation."
    );
    await l2ToL1Msg.waitUntilReadyToExecute(
      GoerliArbitrumProvider,
      timeToWaitMs
    );
    console.log("Outbox entry exists! Trying to execute now");

    const res = await l2ToL1Msg.execute(
      GoerliArbitrumProvider,
      await getPolygonMumbaiFastPerGas()
    );
    await res.wait();
    console.log("Done! Your transaction is executed");
    expect(await test_destination.message()).to.equal(messageInfo[1]);
    expect(await test_destination.chainId()).to.equal(GoerliChainId);
  });
});
