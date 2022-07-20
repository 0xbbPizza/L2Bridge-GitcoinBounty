import { BigNumber, utils, constants } from "ethers";

const DEFAULT_SUBMISSION_FEE_PERCENT_INCREASE = BigNumber.from(300);
const DEFAULT_GAS_PRICE_PERCENT_INCREASE = BigNumber.from(200);
const defaultL1ToL2MessageEstimateOptions = {
  maxSubmissionFeePercentIncrease: DEFAULT_SUBMISSION_FEE_PERCENT_INCREASE,
  gasLimitPercentIncrease: constants.Zero,
  maxFeePerGasPercentIncrease: DEFAULT_GAS_PRICE_PERCENT_INCREASE,
};

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
 *
 * @param num
 * @param increase
 * @returns
 */
function percentIncrease(num: BigNumber, increase: BigNumber) {
  return num.add(num.mul(increase).div(100));
}

/**
 *
 * @param maxSubmissionFeeOptions
 * @returns
 */
function applySubmissionPriceDefaults(
  maxSubmissionFeeOptions:
    | { base: any; percentIncrease: any }
    | null
    | undefined
) {
  return {
    base:
      maxSubmissionFeeOptions === null || maxSubmissionFeeOptions === void 0
        ? void 0
        : maxSubmissionFeeOptions.base,
    percentIncrease:
      (maxSubmissionFeeOptions === null || maxSubmissionFeeOptions === void 0
        ? void 0
        : maxSubmissionFeeOptions.percentIncrease) ||
      defaultL1ToL2MessageEstimateOptions.maxSubmissionFeePercentIncrease,
  };
}

/**
 * Return the fee, in wei, of submitting a new retryable tx with a given calldata size.
 * @param l1BaseFee
 * @param callDataSize
 * @param options
 * @returns
 */
export function estimateSubmissionFee(
  l1BaseFee: BigNumber,
  callDataSize: number,
  options?: any
) {
  const defaultedOptions = applySubmissionPriceDefaults(options);
  return percentIncrease(
    defaultedOptions.base ||
      BigNumber.from(l1BaseFee).mul(
        BigNumber.from(callDataSize)
          .mul(BigNumber.from(6))
          .add(BigNumber.from(1400))
      ),
    defaultedOptions.percentIncrease
  );
}

/**
 * Estimate the amount of L2 gas required for putting the transaction in the L2 inbox, and executing it.
 * @param sender
 * @param destAddr
 * @param l2CallValue
 * @param excessFeeRefundAddress
 * @param callValueRefundAddress
 * @param calldata
 * @param senderDeposit we dont know how much gas the transaction will use when executing
 * so by default we supply a dummy amount of call value that will definately be more than we need
 * @returns
 */
// export function estimateRetryableTicketGasLimit(
//   sender: any,
//   destAddr: any,
//   l2CallValue: any,
//   excessFeeRefundAddress: any,
//   callValueRefundAddress: any,
//   calldata: any,
//   senderDeposit = utils.parseEther("1").add(l2CallValue)
// ) {
//   const nodeInterface = NodeInterface__factory_1.NodeInterface__factory.connect(
//     constants_1.NODE_INTERFACE_ADDRESS,
//     l2Provider
//   );
//   return await nodeInterface.estimateGas.estimateRetryableTicket(
//     sender,
//     senderDeposit,
//     destAddr,
//     l2CallValue,
//     excessFeeRefundAddress,
//     callValueRefundAddress,
//     calldata
//   );
// }
