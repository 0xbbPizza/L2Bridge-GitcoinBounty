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

import "@openzeppelin/contracts/utils/Address.sol";
import "./IDock_L2.sol";

abstract contract Dock_L2 is IDock_L2 {
    using Address for address;

    address public l1PairAddress;
    address public immutable bridgeAddress;

    // Note, these variables are set and then wiped during a single transaction.
    // Therefore their values don't need to be maintained, and their slots will
    // be empty outside of transactions
    uint256 internal sourceChainID;
    address internal sourceSender;

    constructor(address _bridgeAddress) {
        bridgeAddress = _bridgeAddress;
    }

    function bindDock_L1(address _l1PairAddress) external virtual;

    function getSourceChainID() external view override returns (uint256) {
        return sourceChainID;
    }

    function getSourceSender() external view override returns (address) {
        return sourceSender;
    }

    // fromDomain
    function callOtherDomainFunction(
        address _destAddress,
        uint256 _destChainID,
        bytes memory _destMassage,
        bytes memory _ticketIncidentalInfo
    ) external payable override {
        bytes memory onions1 = abi.encode(
            _destAddress,
            _destMassage,
            // _ticketIncidentalInfo,//eth test
            msg.sender,
            block.chainid
        );
        bytes memory onions2 = abi.encodeWithSignature(
            "fromL2Pair(uint256,bytes)",
            _destChainID,
            onions1
        );
        _callBridge(onions2);
    }

    // muti : call bridge
    function _callBridge(bytes memory _data) internal virtual;

    // fromBridge
    function fromL1Pair(bytes calldata _data) external payable {
        _verifySenderAndDockPair();
        address preSourceSender = sourceSender;
        uint256 preSourceChainID = sourceChainID;
        address destAddress;
        bytes memory destMassage;
        bytes memory ticketIncidentalInfo;
        (
            destAddress,
            destMassage,
            ticketIncidentalInfo,
            sourceSender,
            sourceChainID
        ) = abi.decode(_data, (address, bytes, bytes, address, uint256));

        if (destMassage.length > 0)
            require(destAddress.isContract(), "NO_CODE_AT_DEST");
        (bool success, ) = destAddress.call(destMassage);
        require(success, "WRONG_MSG");

        sourceSender = preSourceSender;
        sourceChainID = preSourceChainID;
    }

    // muti : FromBridge
    function _verifySenderAndDockPair() internal view virtual;
}
