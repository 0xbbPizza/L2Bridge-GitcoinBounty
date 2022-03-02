 // SPDX-License-Identifier: Apache-2.0

/*
 * Copyright 2019-2021, Offchain Labs, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

pragma solidity 0.8.4;
 
    //     // !!! Determine whether the index at the moment is greater than the last withdrawal index, and determine whether the index is at zero
    //     // !!! Make a settlement for the bond
    //     // !!! Send onion to Relay, each step will be settled to bonder
    //     uint256 amount = IERC20(tokenAddress).balanceOf(address(this));
    //     IERC20(tokenAddress).safeTransfer(relayAddress,amount);

    //     Relay(relayAddress).getHashOnion(txIndex,hashOnion,tokenAddress,msg.sender);

// interface IArbSys { 
//     // from arbitrum
//     function sendTxToL1(address destAddr, bytes calldata calldataForL1) external payable;
// }


//  // send to L1 dest
//         bytes memory message = abi.encodeWithSignature(
//             "getHashOnion(bytes32)",
//             bringHashOnion
//         );

//         IArbSys(l2Messenger).sendTxToL1(
//             raley,
//             message
//         );



    