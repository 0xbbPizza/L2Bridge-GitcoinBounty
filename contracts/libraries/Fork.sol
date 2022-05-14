// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "hardhat/console.sol";

library HashOnions {
    struct Info {
        bytes32 sourceHashOnion;
        bytes32 onWorkHashOnion;
    }
}

library Fork {
    struct Info {
        bytes32 onionHead;
        bytes32 destOnionHead;
        uint256 allAmount;
        uint256 length;
        address lastCommiterAddress;
        bool needBond; // true is need to settle
    }

    function isExist(
        mapping(bytes32 => Fork.Info) storage self,
        bytes32 forkKey
    ) internal view returns (bool) {
        return self[forkKey].length > 0;
    }

    function remove(mapping(bytes32 => Fork.Info) storage self, bytes32 forkKey)
        internal
    {
        delete self[forkKey];
    }

    function update(
        mapping(bytes32 => Fork.Info) storage self,
        bytes32 forkKey,
        Fork.Info memory forkInfo
    ) internal {
        self[forkKey] = forkInfo;
    }

    function findOne(
        mapping(bytes32 => Fork.Info) storage self,
        uint256 chainId,
        bytes32 hashOnion,
        uint8 index
    ) internal view returns (Fork.Info memory) {
        bytes32 forkKey = Fork.generateInfoKey(chainId, hashOnion, index);
        return self[forkKey];
    }

    /// @param chainId Chain's id
    /// @param hashOnion Equal to Fork.Info.onionHead
    /// @param index Fork's index
    function generateInfoKey(
        uint256 chainId,
        bytes32 hashOnion,
        uint8 index
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(chainId, hashOnion, index));
    }

    function zFork(
        mapping(bytes32 => Fork.Info) storage self,
        uint256 chainId,
        bytes32 hashOnion,
        address dest,
        uint256 amount,
        uint256 fee
    ) internal returns (Fork.Info memory _workFork, Fork.Info memory _newFork) {
        // Take out the Fork
        bytes32 workForkKey = Fork.generateInfoKey(chainId, hashOnion, 0);
        Fork.Info memory workFork = self[workForkKey];

        // Create a new Fork
        Fork.Info memory newFork;

        // set newFork
        newFork.onionHead = keccak256(
            abi.encode(
                workFork.onionHead,
                keccak256(abi.encode(dest, amount, fee))
            )
        );
        bytes32 newForkKey = Fork.generateInfoKey(
            chainId,
            newFork.onionHead,
            0
        );

        // Determine whether there is a fork with newForkKey
        require(Fork.isExist(self, newForkKey) == false, "c1");

        newFork.destOnionHead = keccak256(
            abi.encode(workFork.destOnionHead, newFork.onionHead, msg.sender)
        );

        newFork.allAmount += amount + fee;
        newFork.length = 1;
        newFork.lastCommiterAddress = msg.sender;
        newFork.needBond = true;

        // storage
        Fork.update(self, newForkKey, newFork);

        _workFork = workFork;
        _newFork = newFork;
    }
}
