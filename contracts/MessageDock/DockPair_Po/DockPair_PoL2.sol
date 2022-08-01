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
    string public testMessage;

    // _bridgeAddress   : fxChild
    constructor(address _bridgeAddress) Dock_L2(_bridgeAddress) {}

    // _l1PairAddress   :fxRootTunnel
    function bindDock_L1(address _l1PairAddress) external override {
        require(_l1PairAddress != address(0), "");
        l1PairAddress = _l1PairAddress;
    }

    function processMessageFromRoot(
        uint256 stateId,
        address sender,
        bytes calldata message
    ) external override {
        testSender = sender;
        testStateId = stateId;
        bytes memory _message;
        (_message, testMessage) = abi.decode(message, (bytes, string));
        (bool success, ) = address(this).call(_message);
        require(success, "WRONG_MSG");
    }

    function _callBridge(bytes memory _data) internal override {
        // If abi.encodeWithSignature is used here, data cannot be transmitted, so abi.encode is used for transmission on this basis.
        bytes memory _message = abi.encode(_data);
        emit MessageSent(_message);
    }

    // From bridge
    function _verifySenderAndDockPair() internal view override {
        require(msg.sender == bridgeAddress, "DOCK1");
    }
}
