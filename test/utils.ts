import { utils } from "ethers";
import { config, ethers } from "hardhat";
import fetch from "node-fetch";
/**
 * Generate fork's key
 * @param chainId
 * @param hashOnion
 * @param index
 * @returns
 */
export function generateForkKey(chainId: number, hashOnion: string, index = 0) {
  return utils.keccak256(
    utils.defaultAbiCoder.encode(
      ["uint256", "bytes32", "uint16"],
      [chainId, hashOnion, index]
    )
  );
}

/**
 * Wait for a specific time
 * @param min
 * @returns
 */
export function timeout(min: number) {
  return new Promise((resolve) => setTimeout(resolve, min * 1000 * 60));
}

/**
 *
 * @returns
 */
export async function getPolygonMumbaiFastPerGas() {
  const response = await fetch("https://gasstation-mumbai.matic.today/v2");
  const json = await response.json();
  const fastPerGas = Math.trunc(json["fast"]["maxFee"] * 10 ** 9);
  const options = {
    gasLimit: 3000000,
    maxPriorityFeePerGas: fastPerGas,
    maxFeePerGas: fastPerGas,
  };
  return options;
}

/**
 *
 * @returns
 */
export async function getGoerliFastPerGas() {
  const networkGoerli: any = config.networks["goerli"];
  const data = {
    method: "POST",
    headers: { Accept: "application/json", "Content-Type": "application/json" },
    body: JSON.stringify({
      id: 1,
      jsonrpc: "2.0",
      method: "eth_maxPriorityFeePerGas",
    }),
  };
  const response = await fetch(networkGoerli.url, data);
  const json = await response.json();
  const PriorityFeePerGas = ethers.BigNumber.from(json.result);
  const options = {
    gasLimit: 3000000,
    maxPriorityFeePerGas: PriorityFeePerGas,
    maxFeePerGas: PriorityFeePerGas.mul(2),
  };
  return options;
}
