import { utils } from "ethers";
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
