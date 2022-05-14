// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

library Data {
    struct TransferData {
        address destination;
        uint256 amount;
        uint256 fee;
    }

    struct MForkData {
        uint256 forkIndex;
        uint256 forkKeyNum;
        bytes32[] wrongtxHash;
    }
}
