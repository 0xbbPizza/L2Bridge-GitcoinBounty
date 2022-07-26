import { Contract, providers, Wallet } from "ethers";
import { config, ethers } from "hardhat";
import { expect } from "chai";
describe("GoerliToPolygon", function () {
  let GoerliPolygonProvider: any;
  let GoerliProvider: any;
  let Goerli: Wallet;
  let GoerliPolygon: Wallet;
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
    // send message to Polygon Mumbai(L2) from Goerli(L1)
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

    // L2 deploy testPo
    const DockL2_Po = await ethers.getContractFactory(
      "FxStateChildTunnel",
      GoerliPolygon
    );
    dockL2_Po = await DockL2_Po.deploy(FxChild);
    await dockL2_Po.deployed();
    console.log("testPo Address:", dockL2_Po.address);

    // L1 deploy  testGo
    const DockL1_Go = await ethers.getContractFactory(
      "FxStateRootTunnel",
      Goerli
    );
    dockL1_Go = await DockL1_Go.deploy(CheckpointManager, FxRoot);
    await dockL1_Go.deployed();
    console.log("testGo Address:", dockL1_Go.address);

    // bind testPo address
    const bindtestPoResp = await dockL1_Go.setFxChildTunnel(dockL2_Po.address);
    await bindtestPoResp.wait();
    console.log("bindtestPoResp: ", bindtestPoResp.hash);

    // bind testGo address
    const bindtestGoResp = await dockL2_Po.setFxRootTunnel(
      dockL1_Go.address,
      options
    );
    await bindtestGoResp.wait();
    console.log("bindtestGoResp: ", bindtestGoResp.hash);
  });

  it("test now", async function () {
    function timeout(min: number) {
      return new Promise((resolve) => setTimeout(resolve, min * 1000 * 60));
    }

    const messageInfo = [
      GoerliPolygonChainId,
      "This message comes from Goerli",
    ];

    const setMessageTX = await dockL1_Go.setMessage(messageInfo[1]);
    const setMessageResp = await setMessageTX.wait();
    console.log("setMessageResp:", setMessageResp.hash);
    // It takes about 15 to 25 minutes during this period.
    await timeout(20);
    console.log("result: ", await dockL2_Po.lasdata());
  });
});
