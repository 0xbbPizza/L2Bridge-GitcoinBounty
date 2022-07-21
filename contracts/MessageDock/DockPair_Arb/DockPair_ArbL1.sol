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

interface IInbox {
    function createRetryableTicket(
        address destAddr,
        uint256 arbTxCallValue,
        uint256 maxSubmissionCost,
        address submissionRefundAddress,
        address valueRefundAddress,
        uint256 maxGas,
        uint256 gasPriceBid,
        bytes calldata data
    ) external payable returns (uint256);

    function bridge() external view returns (IBridge);
}

interface IBridge {
    function activeOutbox() external view returns (address);
}

interface IOutbox {
    function l2ToL1Sender() external view returns (address);
}

contract DockL1_Arb is Dock_L1 {
    bytes[] public Messagebox;

    bool internal locked;

    modifier noReentrant() {
        require(!locked, "No re-entrancy");
        locked = true;
        _; // re-entrancy
        locked = false;
    }

    constructor(
        address _l2CallInAddress,
        address _l2OutAddress,
        address _relayAddress
    ) Dock_L1(_l2CallInAddress, _l2OutAddress, _relayAddress) {}

    function addMessageToMessagebox(bytes calldata _messageData)
        internal
        returns (uint256)
    {
        uint256 count = Messagebox.length;
        Messagebox.push(_messageData);
        return count;
    }

    function getDockBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // send eth to account
    function sendValue(uint256 boxId, uint256 usedGas)
        external
        payable
        noReentrant
    {
        address excessFeeRefundAddress;
        uint256 amountGas;
        (, excessFeeRefundAddress, , , , ) = abi.decode(
            Messagebox[boxId],
            (address, address, bytes, address, uint256, uint256)
        );
        uint256 amount = amountGas - usedGas;
        require(
            address(this).balance >= amount,
            "Address: insufficient balance"
        );

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = payable(excessFeeRefundAddress).call{value: amount}(
            ""
        );
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }

    function _callBridge(bytes[2] memory _data) internal override {
        address excessFeeRefundAddress;
        uint256 maxGas;
        uint256 gasPriceBid;
        uint256 maxSubmissionCost;
        bytes memory _ticketIncidentalInfo;
        (, , _ticketIncidentalInfo, , ) = abi.decode(
            _data[1],
            (address, bytes, bytes, address, uint256)
        );
        (excessFeeRefundAddress, maxGas, gasPriceBid, maxSubmissionCost) = abi
            .decode(
                _ticketIncidentalInfo,
                (address, uint256, uint256, uint256)
            );
        IInbox(l2OutAddress).createRetryableTicket{value: msg.value}(
            l2CallInAddress,
            0,
            maxSubmissionCost,
            excessFeeRefundAddress,
            address(0),
            maxGas,
            gasPriceBid,
            _data[0]
        );
    }

    // From bridge
    function _verifySenderAndDockPair() internal view override {
        IBridge arbBridge = IInbox(l2OutAddress).bridge();
        IOutbox outbox = IOutbox(arbBridge.activeOutbox());

        require(msg.sender == address(outbox), "DOCK1");
        // Verify that sender
        require(outbox.l2ToL1Sender() == l2CallInAddress, "DOCK2");
    }
}
