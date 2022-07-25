import { BigNumber, Contract, providers, Signer, Wallet } from "ethers";
import { config, ethers, network } from "hardhat";
import { hexDataLength } from "ethers/lib/utils";
import { estimateSubmissionFee } from "./utils";
import { expect } from "chai";
import { L1ToL2MessageGasEstimator } from "@arbitrum/sdk/dist/lib/message/L1ToL2MessageGasEstimator";
import { L1TransactionReceipt, L1ToL2MessageStatus } from "@arbitrum/sdk";
describe("Arb", function () {
  let RinkebyArbitrumProvider: any;
  let RinkebyProvider: any;
  let Rinkeby: Wallet;
  let RinkebyArbitrum: Wallet;
  let relay: Contract;
  let mainNet: Contract;
  let test_source: Contract;
  let test_destination: Contract;
  let dockL1_AR: Contract;
  let dockL2_AR: Contract;
  const RinkebyArbitrumChainId = 421611;
  const RinkebyChainId = 4;
  const defaultGasLimit = 1000000;
  const Proxy__OVM_L1CrossDomainMessenger =
    "0x578bade599406a8fe3d24fd7f7211c0911f5b29e";
  const L2_BridgeAddress = "0x0000000000000000000000000000000000000064";
  const options = {
    gasLimit: 1000000,
    gasPrice: 1000000000,
  };
  before(async function () {
    const networkRinkebyArbitrum: any = config.networks["rinkebyArbitrum"];
    const networkRinkeby: any = config.networks["rinkeby"];
    RinkebyProvider = new providers.JsonRpcProvider(networkRinkeby.url);
    RinkebyArbitrumProvider = new providers.JsonRpcProvider(
      networkRinkebyArbitrum.url
    );
    Rinkeby = new Wallet(networkRinkeby.accounts[0], RinkebyProvider);
    RinkebyArbitrum = new Wallet(
      networkRinkebyArbitrum.accounts[0],
      RinkebyArbitrumProvider
    );

    // L1 delpoy Realy
    const Relay = await ethers.getContractFactory("Relay", Rinkeby);
    relay = await Relay.deploy();
    await relay.deployed();
    console.log("relay Address:", relay.address);

    // L1 deploy MainNet
    const MainNet = await ethers.getContractFactory("Dock_MainNet", Rinkeby);
    mainNet = await MainNet.deploy(relay.address);
    await mainNet.deployed();
    console.log("mainNet Address:", mainNet.address);

    // L2 deploy DockL2_AR
    const DockL2_AR = await ethers.getContractFactory(
      "DockL2_Arb",
      RinkebyArbitrum
    );
    dockL2_AR = await DockL2_AR.deploy(L2_BridgeAddress, defaultGasLimit);
    await dockL2_AR.deployed();
    console.log("dockL2_AR Address:", dockL2_AR.address);

    // L1 deploy  DockL1_AR
    const DockL1_AR = await ethers.getContractFactory("DockL1_Arb", Rinkeby);
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
    const addMainNetResp = await relay.addDock(mainNet.address, RinkebyChainId);
    await addMainNetResp.wait();
    console.log("addMainNetResp hash:", addMainNetResp.hash);

    // Relay addDock
    const addDockResp = await relay.addDock(
      dockL1_AR.address,
      RinkebyArbitrumChainId
    );
    await addDockResp.wait();
    console.log("addDock hash:", addDockResp.hash);

    // L1 deploy Test_source
    const Test_source = await ethers.getContractFactory("Test_source", Rinkeby);
    test_source = await Test_source.deploy(mainNet.address);
    await test_source.deployed();
    console.log("test_source Address:", test_source.address);

    // L2 deploy Test_destination
    const Test_destination = await ethers.getContractFactory(
      "Test_destination",
      RinkebyArbitrum
    );
    test_destination = await Test_destination.deploy(dockL2_AR.address);
    await test_destination.deployed();
    console.log("test_destination Address:", test_destination.address);

    // L1 addDestDomain
    const addDestDomainResp = await test_source.addDestDomain(
      RinkebyArbitrumChainId,
      test_destination.address
    );
    await addDestDomainResp.wait();
    console.log("addDestDomain hash:", addDestDomainResp.hash);

    // L2 addSourceDomain
    const addSourceDomainResp = await test_destination.addDomain(
      RinkebyChainId,
      test_source.address
    );
    await addSourceDomainResp.wait();
    console.log("addSourceDomain hash:", addSourceDomainResp.hash);
  });

  it("DockRelayArb", async function () {
    function timeout(ms: number) {
      return new Promise((resolve) => setTimeout(resolve, ms));
    }

    const messageInfo = [
      RinkebyArbitrumChainId,
      "This message comes from Bridge",
    ];
    const newGreetingBytes = ethers.utils.defaultAbiCoder.encode(
      ["uint256", "string"],
      messageInfo
    );
    const newGreetingBytesLength = hexDataLength(newGreetingBytes) + 4;

    console.log("L1 gas price", await RinkebyProvider.getGasPrice());

    const l1ToL2MessageGasEstimate = new L1ToL2MessageGasEstimator(
      RinkebyArbitrumProvider
    );

    // L1 submissionPriceWei
    const _submissionPriceWei = estimateSubmissionFee(
      await RinkebyProvider.getGasPrice(),
      newGreetingBytesLength
    );

    console.log(
      `Current retryable base submission price: ${_submissionPriceWei.toString()}`
    );

    const submissionPriceWei = _submissionPriceWei.mul(5);

    // L2 gasPrice
    const gasPriceBid = await RinkebyArbitrumProvider.getGasPrice();
    console.log(`L2 gas price: ${gasPriceBid.toString()}`);

    // const ABI = ["function getMessage(uint256 _chainId, string _message)"];
    // const iface = new ethers.utils.Interface(ABI);
    // const calldata = iface.encodeFunctionData("getMessage", messageInfo);

    const l2CallValue = 0;
    // // L2 gasLimit
    const maxGas = ethers.BigNumber.from("21000");

    const callValue = submissionPriceWei
      .add(gasPriceBid.mul(maxGas))
      .mul(BigNumber.from("100"));

    console.log(
      `Sending ${
        messageInfo[1]
      } to L2 with ${callValue.toString()} callValue for L2 fees:`
    );

    const sendMessageTX = await test_source.sendMessage(
      RinkebyArbitrum.address,
      messageInfo[0],
      maxGas,
      gasPriceBid,
      submissionPriceWei,
      messageInfo[1],
      {
        value: callValue,
      }
    );
    const sendMessageResp = await sendMessageTX.wait();

    console.log("sendMessageResp hash:", sendMessageResp.transactionHash);

    const l1TxReceipt = new L1TransactionReceipt(sendMessageResp);

    const l1ToL2Message = await l1TxReceipt.getL1ToL2Message(RinkebyArbitrum);
    const status: any = await l1ToL2Message.waitForStatus();
    console.log("status", status);
    if (status === L1ToL2MessageStatus.REDEEMED) {
      console.log(`L2 retryable txn executed 🥳 `);
    } else {
      console.log(`L2 retryable txn failed with status`);
    }
    try {
      const response = await l1ToL2Message.redeem();
      await response.wait();
    } catch (error) {
      console.log(error);
    }
    timeout(120000);
    console.log("redeem: ", await test_destination.message());
    expect(await test_destination.message()).to.equal(messageInfo[1]);
    expect(await test_destination.chainId()).to.equal(RinkebyArbitrumChainId);
  });
});
