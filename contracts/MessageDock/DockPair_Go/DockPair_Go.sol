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
import "../../libraries/ExitPayloadReader.sol";
import {RLPReader} from "../../libraries/RLPReader.sol";
import {MerklePatriciaProof, Merkle} from "../../libraries/MerklePatriciaProof.sol";

interface IFxStateSender {
    function sendMessageToChild(address _receiver, bytes calldata _data)
        external;
}

contract ICheckpointManager {
    struct HeaderBlock {
        bytes32 root;
        uint256 start;
        uint256 end;
        uint256 createdAt;
        address proposer;
    }

    /**
     * @notice mapping of checkpoint header numbers to block details
     * @dev These checkpoints are submited by plasma contracts
     */
    mapping(uint256 => HeaderBlock) public headerBlocks;
}

abstract contract FxBaseRootTunnel {
    using RLPReader for RLPReader.RLPItem;
    using Merkle for bytes32;
    using ExitPayloadReader for bytes;
    using ExitPayloadReader for ExitPayloadReader.ExitPayload;
    using ExitPayloadReader for ExitPayloadReader.Log;
    using ExitPayloadReader for ExitPayloadReader.LogTopics;
    using ExitPayloadReader for ExitPayloadReader.Receipt;

    // keccak256(MessageSent(bytes))
    bytes32 public constant SEND_MESSAGE_EVENT_SIG =
        0x8c5261668696ce22758910d05bab8f186d6eb247ceac2af2e82c7dc17669b036;

    // state sender contract
    IFxStateSender public fxRoot;
    // root chain manager
    ICheckpointManager public checkpointManager;
    // child tunnel contract which receives and sends messages
    address public fxChildTunnel;

    // storage to avoid duplicate exits
    mapping(bytes32 => bool) public processedExits;

    constructor(
        address _checkpointManager,
        address _fxRoot,
        address _fxChildTunnel
    ) {
        checkpointManager = ICheckpointManager(_checkpointManager);
        fxRoot = IFxStateSender(_fxRoot);
        fxChildTunnel = _fxChildTunnel;
    }

    function _sendMessageToChild(bytes memory message) internal {
        fxRoot.sendMessageToChild(fxChildTunnel, message);
    }

    function _validateAndExtractMessage(bytes memory inputData)
        internal
        returns (bytes memory)
    {
        ExitPayloadReader.ExitPayload memory payload = inputData
            .toExitPayload();

        bytes memory branchMaskBytes = payload.getBranchMaskAsBytes();
        uint256 blockNumber = payload.getBlockNumber();
        // checking if exit has already been processed
        // unique exit is identified using hash of (blockNumber, branchMask, receiptLogIndex)
        bytes32 exitHash = keccak256(
            abi.encodePacked(
                blockNumber,
                // first 2 nibbles are dropped while generating nibble array
                // this allows branch masks that are valid but bypass exitHash check (changing first 2 nibbles only)
                // so converting to nibble array and then hashing it
                MerklePatriciaProof._getNibbleArray(branchMaskBytes),
                payload.getReceiptLogIndex()
            )
        );
        require(
            processedExits[exitHash] == false,
            "FxRootTunnel: EXIT_ALREADY_PROCESSED"
        );
        processedExits[exitHash] = true;

        ExitPayloadReader.Receipt memory receipt = payload.getReceipt();
        ExitPayloadReader.Log memory log = receipt.getLog();

        // check child tunnel
        require(
            fxChildTunnel == log.getEmitter(),
            "FxRootTunnel: INVALID_FX_CHILD_TUNNEL"
        );

        bytes32 receiptRoot = payload.getReceiptRoot();
        // verify receipt inclusion
        require(
            MerklePatriciaProof.verify(
                receipt.toBytes(),
                branchMaskBytes,
                payload.getReceiptProof(),
                receiptRoot
            ),
            "FxRootTunnel: INVALID_RECEIPT_PROOF"
        );

        // verify checkpoint inclusion
        _checkBlockMembershipInCheckpoint(
            blockNumber,
            payload.getBlockTime(),
            payload.getTxRoot(),
            receiptRoot,
            payload.getHeaderNumber(),
            payload.getBlockProof()
        );

        ExitPayloadReader.LogTopics memory topics = log.getTopics();

        require(
            bytes32(topics.getField(0).toUint()) == SEND_MESSAGE_EVENT_SIG, // topic0 is event sig
            "FxRootTunnel: INVALID_SIGNATURE"
        );

        // received message data
        bytes memory message = abi.decode(log.getData(), (bytes)); // event decodes params again, so decoding bytes to get message
        return message;
    }

    function _checkBlockMembershipInCheckpoint(
        uint256 blockNumber,
        uint256 blockTime,
        bytes32 txRoot,
        bytes32 receiptRoot,
        uint256 headerNumber,
        bytes memory blockProof
    ) private view returns (uint256) {
        (
            bytes32 headerRoot,
            uint256 startBlock,
            ,
            uint256 createdAt,

        ) = checkpointManager.headerBlocks(headerNumber);

        require(
            keccak256(
                abi.encodePacked(blockNumber, blockTime, txRoot, receiptRoot)
            ).checkMembership(blockNumber - startBlock, headerRoot, blockProof),
            "FxRootTunnel: INVALID_HEADER"
        );
        return createdAt;
    }

    function receiveMessage(bytes memory inputData) public virtual {
        bytes memory message = _validateAndExtractMessage(inputData);
        _processMessageFromChild(message);
    }

    function _processMessageFromChild(bytes memory message) internal virtual;
}

contract DockL1_Go is Dock_L1, FxBaseRootTunnel {
    constructor(
        address _l2CallInAddress,
        address _l2OutAddress,
        address _relayAddress,
        address _checkpointManager
    )
        Dock_L1(_l2CallInAddress, _l2OutAddress, _relayAddress)
        FxBaseRootTunnel(_checkpointManager, _l2OutAddress, _l2CallInAddress)
    {}

    function _processMessageFromChild(bytes memory data) internal override {
        bytes memory _message;
        (_message) = abi.decode(data, (bytes));
        (bool success, ) = address(this).call(_message);
        require(success, "WRONG_MSG");
    }

    function _callBridge(bytes[2] memory _data) internal override {
        // If abi.encodeWithSignature is used here, data cannot be transmitted, so abi.encode is used for transmission on this basis.
        bytes memory _message = abi.encode(_data[0]);
        _sendMessageToChild(_message);
    }

    // From bridge
    function _verifySenderAndDockPair() internal view override {
        // Todo
    }
}
