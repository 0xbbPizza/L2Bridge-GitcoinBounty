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
      ["uint256", "bytes32", "uint8"],
      [chainId, hashOnion, index]
    )
  );
}
