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

    // Deprecated, move to Fork.Info
    struct HashOnionFork {
        bytes32 onionHead;
        bytes32 destOnionHead;
        uint256 allAmount; // can delete
        uint256 length; // can add new length to mean needBond
        address lastCommiterAddress; // can storage by uint256 ID
        bool needBond; // true is need to settle
    }
}
