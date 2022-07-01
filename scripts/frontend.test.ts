import { BigNumber, Contract, providers, utils, Wallet } from "ethers";
import { ethers, run } from "hardhat";
import sourceContractJson from "../artifacts/contracts/SourceContract.sol/SourceContract.json";
import erc20ContractJson from "../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json";

// npx hardhat run scripts/frontend.test.ts --network rinkeby

async function main() {
  await run("compile");

  const tokenAddress = "0x2e055eEe18284513B993dB7568A592679aB13188",
    sourceAddress = "0x8ADb5229F9Bd96215B886134620bAfD075630025",
    toChainId = 77;

  const singer = (await ethers.getSigners())[1];
  const singerAddress = await singer.getAddress();
  const sourceContract = new Contract(
    sourceAddress,
    sourceContractJson.abi,
    singer
  );
  const tokenContract = new Contract(
    tokenAddress,
    erc20ContractJson.abi,
    singer
  );

  // Approve
  const allowance: BigNumber = await tokenContract.allowance(
    await singer.getAddress(),
    sourceAddress
  );
  console.warn("allowance:::", allowance + "");

  if (allowance.lte(0)) {
    await tokenContract.approve(sourceAddress, ethers.constants.MaxUint256);
  }

  for (let i = 1; i <= 6; i++) {
    const amount = utils.parseEther(i + "");
    const { hash } = await sourceContract.transferWithDest(
      toChainId,
      singerAddress,
      amount,
      0
    );
    await singer.provider?.waitForTransaction(hash, 3);

    console.log(
      "TransferWithDest succeed: " + hash + ", amount: " + amount + ""
    );
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
