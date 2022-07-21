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

import "../Dock_L1.sol";

interface IFxStateSender {
    function sendMessageToChild(address _receiver, bytes calldata _data)
        external;
}

// contract ICheckpointManager {
//     struct HeaderBlock {
//         bytes32 root;
//         uint256 start;
//         uint256 end;
//         uint256 createdAt;
//         address proposer;
//     }

//     /**
//      * @notice mapping of checkpoint header numbers to block details
//      * @dev These checkpoints are submited by plasma contracts
//      */
//     mapping(uint256 => HeaderBlock) public headerBlocks;
// }

contract DockL1_Go is Dock_L1 {
    // IFxStateSender public fxRoot;
    // ICheckpointManager public checkpointManager;

    constructor(
        address _l2CallInAddress, // fxChildTunnel: child tunnel contract which receives and sends messages
        address _l2OutAddress, // fxRoot address
        address _relayAddress
        // address _checkpointManager // checkpointManager address
    ) Dock_L1(_l2CallInAddress, _l2OutAddress, _relayAddress) {
        // checkpointManager = ICheckpointManager(_checkpointManager);
        // fxRoot = IFxStateSender(_l2OutAddress);
    }

    function _callBridge(bytes[2] memory _data) internal override {
        //  data[0] encodewithSinger (function(string xxxx),xxxx)
        IFxStateSender(l2OutAddress).sendMessageToChild(l2CallInAddress, _data[0]);
    }

    // From bridge
    function _verifySenderAndDockPair() internal view override {
        // IBridge arbBridge = IInbox(l2OutAddress).bridge();
        // IOutbox outbox = IOutbox(arbBridge.activeOutbox());
        // require(msg.sender == address(outbox), "DOCK1");
        // // Verify that sender
        // require(outbox.l2ToL1Sender() == l2CallInAddress, "DOCK2");
    }
}

// ARB -> POlygon -> Child
// Kovan -> Goerli -> Root
