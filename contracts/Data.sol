// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

library Data {
    struct TransferData{
        address destination;
        uint256 amount;
        uint256 fee;
    }

    struct MForkData{
        uint256 forkIndex;
        uint256 forkKeyNum;
        bytes32[] wrongtxHash;
    }

    struct HashOnionFork{
        bytes32 onionHead;
        bytes32 destOnionHead;
        uint256 allAmount;
        uint256 length;  // !!! change to byte https://jeancvllr.medium.com/solidity-tutorial-all-about-bytes-9d88fdb22676
        address lastCommiterAddress;
        bool needBond; // true is need to settle 
    }
    
}