import { expect } from "chai";
import { Contract, providers, Wallet } from "ethers";
import { CrossChainMessenger, MessageStatus } from "@eth-optimism/sdk";
import { config, ethers } from "hardhat";
import { timeout } from "./utils";
describe("source", function () {
  let Goerli: Wallet;
  let GoerliOptimism: Wallet;
  let relay: Contract;
  let mainNet: Contract;
  let test_source: Contract;
  let test_destination: Contract;
  let dockL1_OP: Contract;
  let dockL2_OP: Contract;
  const GoerliOptimismChainId = 420;
  const GoerliChainId = 5;
  const defaultGasLimit = 1000000;
  const Proxy__OVM_L1CrossDomainMessenger =
    "0x5086d1eEF304eb5284A0f6720f79403b4e9bE294";
  const L2_BridgeAddress = "0x4200000000000000000000000000000000000007";
  const options = {
    gasLimit: 1000000,
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
    dockL2_OP = await DockL2_OP.deploy(
      L2_BridgeAddress,
      defaultGasLimit,
      options
    );
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

    // L2 deploy Test_source
    const Test_source = await ethers.getContractFactory(
      "Test_source",
      GoerliOptimism
    );
    test_source = await Test_source.deploy(dockL2_OP.address, options);
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
      test_destination.address,
      options
    );
    await addDestDomainResp.wait();
    console.log("addDestDomain hash:", addDestDomainResp.hash);

    // L1 addSourceDomain
    const addSourceDomainResp = await test_destination.addDomain(
      GoerliOptimismChainId,
      test_source.address
    );
    await addSourceDomainResp.wait();
    console.log("addSourceDomain hash:", addSourceDomainResp.hash);
  });

  it("DockRelayOPToL1", async function () {
    const messageInfo = [GoerliChainId, "hello world from Op to L1"];
    const sendMessageResp = await test_source.sendMessage(
      Goerli.address,
      messageInfo[0],
      0,
      0,
      0,
      messageInfo[1],
      options
    );
    await sendMessageResp.wait();
    console.log("sendMessageResp hash:", sendMessageResp.hash);

    const crossChainMessenger = new CrossChainMessenger({
      l1ChainId: GoerliChainId,
      l2ChainId: GoerliOptimismChainId,
      l1SignerOrProvider: Goerli,
      l2SignerOrProvider: GoerliOptimism,
    });
    /* 
      MessageStatus.STATE_ROOT_NOT_PUBLISHED(2)：The state root has not been published yet. The challenge period only starts when the state root is published, which is means you might need to wait a few minutes.
      MessageStatus.IN_CHALLENGE_PERIOD(3)：Still in the challenge period, wait a few seconds.
      MessageStatus.READY_FOR_RELAY(4)：Ready to finalize the message. Go on to the next step.
    */
    let L2_NOT_READY_FOR_RELAY = true;
    while (L2_NOT_READY_FOR_RELAY) {
      await timeout(1);
      (await crossChainMessenger.getMessageStatus(sendMessageResp.hash)) ===
      MessageStatus.READY_FOR_RELAY
        ? (L2_NOT_READY_FOR_RELAY = false)
        : (L2_NOT_READY_FOR_RELAY = true);
    }

    const finalizeTx = await crossChainMessenger.finalizeMessage(
      sendMessageResp.hash
    );
    await finalizeTx.wait();

    expect(await test_destination.message()).to.equal(messageInfo[1]);
    expect(await test_destination.chainId()).to.equal(messageInfo[0]);
  });
});
