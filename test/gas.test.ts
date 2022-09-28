import { BigNumber, Contract, providers, Wallet } from "ethers";
import { config, ethers } from "hardhat";
describe("Gas", function () {
  let GoerliArbitrumProvider: any;
  let GoerliProvider: any;
  let Goerli: Wallet;
  let GoerliArbitrum: Wallet;
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
  });

  it("Pizza ", async function () {
    let goerliList = [
      "0xd94a5d466c3f8774423e753be480a47bc2dc6458319ed92ebe9a47cb309c1b2a",
      "0x97f2a5bff0537f3d6daf0b384e1b4fa927200eed8fd2fc79ab842db75216928a",
      "0x55815c76c6bb84076e56a988454c696bd9f30a77ee392ebc62ac5bdf5dc04c1a",
    ];
    let arbGoerliList = [
      "0xeb3288ddab2abb2329f70743c5a83bdb60c220924b1876b3e4cfdac2a3e04fa8",
      "0x9d2528441626d1128f75de45c794ec9c8f174db44d950093defe63b8ffc52012",
      "0xbbfa85438bcd302ac383090ae8f1731459f2e20d6e1bf57a232fd2949f4ce766",
    ];
    let goerliTotalGas = BigNumber.from("0");
    let goerliTotalGasLimit = BigNumber.from("0");
    let arbTotalGas = BigNumber.from("0");
    let arbtotalGasLimit = BigNumber.from("0");
    let totalGas = BigNumber.from("0");
    let totalGasLimit = BigNumber.from("0");
    for (let i = 0; i < goerliList.length; i++) {
      const gtx = await Goerli.provider.getTransactionReceipt(goerliList[i]);
      const atx = await GoerliArbitrum.provider.getTransactionReceipt(
        arbGoerliList[i]
      );
      const goerliGetUsed = gtx.gasUsed.mul(gtx.effectiveGasPrice);
      const arbGetUsed = atx.gasUsed.mul(atx.effectiveGasPrice);
      goerliTotalGasLimit = goerliTotalGasLimit.add(gtx.gasUsed);
      arbtotalGasLimit = arbtotalGasLimit.add(atx.gasUsed);
      goerliTotalGas = goerliTotalGas.add(goerliGetUsed);
      arbTotalGas = arbTotalGas.add(arbGetUsed);
    }
    totalGas = goerliTotalGas.add(arbTotalGas);
    totalGasLimit = goerliTotalGasLimit.add(arbtotalGasLimit);
    console.log("totalGas: ", totalGas.toNumber());
    console.log("totalGasLimit: ", totalGasLimit.toNumber());
    console.log("one try", totalGas.div(goerliList.length).toNumber());
  });
  it("Arbitrum Bridge", async function () {
    let goerliList = [
      "0x68012e1e9d7a5533022c8dd502475f46dfd8e2963573c4f5a8a49dcdbee7ec92",
      "0x136174a7f535ff375bc50ceb58898131f644fcb2fb9ca2b278b0ebdfafc5ba97",
      "0x638f070f0afb2a670d94df18edfd6fc99275f38fb8483b8b4afa96ee6846a6a6",
    ];
    let arbGoerliList = [
      "0x992e417ac9fec9b8526df706c4fefb9b7be053dbe5518efec2599354dac947a3",
      "0x147fba39a1b7d5717027159fb313d1cbcc33fe899d8bdddbd82e2f6c32c810f4",
      "0x33bf961e7f51314f77a4e3805027300a4ad23f1d8939a0da7cea9b92274eb0f4",
    ];
    let goerliTotalGas = BigNumber.from("0");
    let goerliTotalGasLimit = BigNumber.from("0");
    let arbTotalGas = BigNumber.from("0");
    let arbtotalGasLimit = BigNumber.from("0");
    let totalGas = BigNumber.from("0");
    let totalGasLimit = BigNumber.from("0");
    for (let i = 0; i < goerliList.length; i++) {
      const gtx = await Goerli.provider.getTransactionReceipt(goerliList[i]);
      const atx = await GoerliArbitrum.provider.getTransactionReceipt(
        arbGoerliList[i]
      );
      const goerliGetUsed = gtx.gasUsed.mul(gtx.effectiveGasPrice);
      const arbGetUsed = atx.gasUsed.mul(atx.effectiveGasPrice);
      goerliTotalGasLimit = goerliTotalGasLimit.add(gtx.gasUsed);
      arbtotalGasLimit = arbtotalGasLimit.add(atx.gasUsed);
      goerliTotalGas = goerliTotalGas.add(goerliGetUsed);
      arbTotalGas = arbTotalGas.add(arbGetUsed);
    }
    totalGas = goerliTotalGas.add(arbTotalGas);
    totalGasLimit = goerliTotalGasLimit.add(arbtotalGasLimit);
    console.log("totalGas: ", totalGas.toNumber());
    console.log("totalGasLimit: ", totalGasLimit.toNumber());
    console.log("one try", totalGas.div(goerliList.length).toNumber());
  });
});
