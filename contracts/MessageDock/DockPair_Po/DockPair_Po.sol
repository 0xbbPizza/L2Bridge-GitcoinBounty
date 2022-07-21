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

import "../Dock_L2.sol";

interface IFxMessageProcessor {
    function processMessageFromRoot(
        uint256 stateId,
        address rootMessageSender,
        bytes calldata data
    ) external;
}

contract DockL2_Po is Dock_L2, IFxMessageProcessor {
    address public testSender;
    uint256 public testStateId;

    constructor(
        address _bridgeAddress, // fxChild
        uint256 _defaultGasLimit
    ) Dock_L2(_bridgeAddress) {}

    // modifier validateSender(address sender) {
    //     require(
    //         sender == l1PairAddress,
    //         "FxBaseChildTunnel: INVALID_SENDER_FROM_ROOT"
    //     );
    //     _;
    // }

    function bindDock_L1(address _l1PairAddress) external override {
        require(_l1PairAddress != address(0), "");
        l1PairAddress = _l1PairAddress;
    }

    /**
     * @notice Process message received from Root Tunnel
     * @dev function needs to be implemented to handle message as per requirement
     * This is called by onStateReceive function.
     * Since it is called via a system call, any event will not be emitted during its execution.
     * @param stateId unique state id
     * @param sender root message sender
     * @param message bytes message that was sent from Root Tunnel
     */
    function processMessageFromRoot(
        uint256 stateId,
        address sender,
        bytes calldata message
    ) external override {
        // _processMessageFromRoot(stateId, sender, message);
        testSender = sender;
        testStateId = stateId;
        this.fromL1Pair(message);
    }

    function _callBridge(bytes memory _data) internal override {
        // FxStateRootTunnel(bridgeAddress).sendMessageToChild(_data);
    }

    // From bridge
    function _verifySenderAndDockPair() internal view override {
        require(msg.sender == bridgeAddress, "DOCK1");
    }

    // function _processMessageFromRoot(
    //     uint256 stateId,
    //     address sender,
    //     bytes memory message
    // ) internal virtual;
}
