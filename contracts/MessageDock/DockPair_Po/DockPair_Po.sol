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
    // MessageTunnel on L1 will get data from this event
    event MessageSent(bytes message);

    address public testSender;
    uint256 public testStateId;
    bytes public testData;

    // _bridgeAddress   : fxChild
    constructor(address _bridgeAddress) Dock_L2(_bridgeAddress) {}

    // _l1PairAddress   :fxRootTunnel
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
        testSender = sender;
        testStateId = stateId;
        testData = message;
        (bool success, ) = address(this).call(message);
        require(success, "WRONG_MSG");
    }

    function _callBridge(bytes memory _data) internal override {
        emit MessageSent(_data);
    }

    // From bridge
    function _verifySenderAndDockPair() internal view override {
        require(msg.sender == bridgeAddress, "DOCK1");
    }
}
