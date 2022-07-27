import { BigNumber, Contract, providers, Signer, Wallet } from "ethers";
import { config, ethers, network } from "hardhat";
import { hexDataLength } from "ethers/lib/utils";
import { expect } from "chai";
import { L1ToL2MessageGasEstimator } from "@arbitrum/sdk/dist/lib/message/L1ToL2MessageGasEstimator";
import { L1TransactionReceipt, L1ToL2MessageStatus } from "@arbitrum/sdk";
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
  const defaultGasLimit = 1000000;
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
    dockL2_AR = await DockL2_AR.deploy(L2_BridgeAddress, defaultGasLimit);
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

    // L1 deploy Test_source
    const Test_source = await ethers.getContractFactory("Test_source", Goerli);
    test_source = await Test_source.deploy(mainNet.address);
    await test_source.deployed();
    console.log("test_source Address:", test_source.address);

    // L2 deploy Test_destination
    const Test_destination = await ethers.getContractFactory(
      "Test_destination",
      GoerliArbitrum
    );
    test_destination = await Test_destination.deploy(dockL2_AR.address);
    await test_destination.deployed();
    console.log("test_destination Address:", test_destination.address);

    // L1 addDestDomain
    const addDestDomainResp = await test_source.addDestDomain(
      GoerliArbitrumChainId,
      test_destination.address
    );
    await addDestDomainResp.wait();
    console.log("addDestDomain hash:", addDestDomainResp.hash);

    // L2 addSourceDomain
    const addSourceDomainResp = await test_destination.addDomain(
      GoerliChainId,
      test_source.address
    );
    await addSourceDomainResp.wait();
    console.log("addSourceDomain hash:", addSourceDomainResp.hash);
  });

  it("DockRelayArb", async function () {
    const messageInfo = [
      GoerliArbitrumChainId,
      "This message comes from Bridge",
    ];
    const newGreetingBytes = ethers.utils.defaultAbiCoder.encode(
      ["uint256", "string"],
      messageInfo
    );
    const newGreetingBytesLength = hexDataLength(newGreetingBytes) + 4;
    const l1ToL2MessageGasEstimate = new L1ToL2MessageGasEstimator(
      GoerliArbitrumProvider
    );
    console.log("L1 GAS PRICE:", await GoerliProvider.getGasPrice());

    const _submissionPriceWei =
      await l1ToL2MessageGasEstimate.estimateSubmissionFee(
        GoerliProvider,
        await GoerliProvider.getGasPrice(),
        newGreetingBytesLength
      );
    console.log(
      `Current retryable base submission price: ${_submissionPriceWei.toString()}`
    );

    const submissionPriceWei = _submissionPriceWei.mul(10);
    const gasPriceBid = await GoerliArbitrumProvider.getGasPrice();
    console.log(`L2 gas price: ${gasPriceBid.toString()}`);

    // const ABI = ["function getMessage(uint256 _chainId, string _message)"];
    // const iface = new ethers.utils.Interface(ABI);
    // const calldata = iface.encodeFunctionData("getMessage", messageInfo);
    // const l2CallValue = BigNumber.from("0");
    const maxGas = ethers.BigNumber.from("310000");
    // const maxGas =
    //   await l1ToL2MessageGasEstimate.estimateRetryableTicketGasLimit(
    //     test_source.address,
    //     test_destination.address,
    //     l2CallValue,
    //     GoerliArbitrum.address,
    //     GoerliArbitrum.address,
    //     calldata
    //   );

    const callValue = submissionPriceWei
      .add(gasPriceBid.mul(maxGas))
      .mul(BigNumber.from("100"));

    console.log(
      `Sending ${
        messageInfo[1]
      } to L2 with ${callValue.toString()} callValue for L2 fees:`
    );

    const sendMessageTX = await test_source.sendMessage(
      GoerliArbitrum.address,
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

    const l1ToL2Message = (
      await l1TxReceipt.getL1ToL2Messages(GoerliArbitrum)
    )[0];
    const res = await l1ToL2Message.waitForStatus();
    if (res.status === L1ToL2MessageStatus.FUNDS_DEPOSITED_ON_L2) {
      /** Message wasn't auto-redeemed; redeem it now: */
      console.log(
        "Automatic redemption failed, manual redemption is being attempted"
      );
      const response = await l1ToL2Message.redeem();
      const receipt = await response.wait();
    } else if (res.status === L1ToL2MessageStatus.REDEEMED) {
      /** Message succesfully redeeemed */
      console.log(`L2 retryable txn executed 🥳 `);
    } else {
      console.log(`L2 retryable txn failed with status`);
    }

    expect(await test_destination.message()).to.equal(messageInfo[1]);
    expect(await test_destination.chainId()).to.equal(GoerliArbitrumChainId);
  });
});
