// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "./Data.sol";
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

    function isExist(mapping(bytes32 => Info) storage self, bytes32 forkKey)
        internal
        view
        returns (bool)
    {
        return self[forkKey].length > 0;
    }

    function remove(mapping(bytes32 => Info) storage self, bytes32 forkKey)
        internal
    {
        delete self[forkKey];
    }

    function update(
        mapping(bytes32 => Info) storage self,
        bytes32 forkKey,
        Info memory forkInfo
    ) internal {
        self[forkKey] = forkInfo;
    }

    function get(
        mapping(bytes32 => Info) storage self,
        uint256 chainId,
        bytes32 hashOnion,
        uint8 index
    ) internal view returns (Info memory) {
        bytes32 forkKey = generateForkKey(chainId, hashOnion, index);
        return self[forkKey];
    }

    /// @param chainId Chain's id
    /// @param hashOnion Equal to fork's first Info.onionHead
    /// @param index Fork's index
    function generateForkKey(
        uint256 chainId,
        bytes32 hashOnion,
        uint8 index
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(chainId, hashOnion, index));
    }

    /// @param chainId Chain's id
    /// @param maxLength OneFork max length
    function initialize(
        mapping(bytes32 => Info) storage self,
        uint256 chainId,
        uint256 maxLength
    ) internal {
        bytes32 forkKey = generateForkKey(chainId, bytes32(0), 0);
        require(isExist(self, forkKey) == false);

        update(
            self,
            forkKey,
            Info(bytes32(0), bytes32(0), 0, maxLength, address(0), false)
        );
    }

    /// @param workForkKey Current work fork's key
    function createZFork(
        mapping(bytes32 => Info) storage self,
        uint256 chainId,
        bytes32 workForkKey,
        address dest,
        uint256 amount,
        uint256 fee
    ) internal returns (Info memory _workFork, Info memory _newFork) {
        // Take out the Fork
        Info memory workFork = self[workForkKey];

        // Create a new Fork
        Info memory newFork;

        // set newFork
        newFork.onionHead = keccak256(
            abi.encode(
                workFork.onionHead,
                keccak256(abi.encode(dest, amount, fee))
            )
        );
        bytes32 newForkKey = generateForkKey(chainId, newFork.onionHead, 0);

        // Determine whether there is a fork with newForkKey
        require(isExist(self, newForkKey) == false, "c1");

        newFork.destOnionHead = keccak256(
            abi.encode(workFork.destOnionHead, newFork.onionHead, msg.sender)
        );

        newFork.allAmount += amount + fee;
        newFork.length = 1;
        newFork.lastCommiterAddress = msg.sender;
        newFork.needBond = true;

        // storage
        update(self, newForkKey, newFork);

        _workFork = workFork;
        _newFork = newFork;
    }

    /// @param _lastOnionHead Before wrong fork's onionHead
    /// @param _lastDestOnionHead Before wrong fork's destOnionHead
    function createMFork(
        mapping(bytes32 => Info) storage self,
        uint256 chainId,
        bytes32 _lastOnionHead,
        bytes32 _lastDestOnionHead,
        uint8 _index,
        Data.TransferData calldata _transferData
    ) internal returns (Info memory _newFork) {
        // Create a new Fork
        Fork.Info memory newFork;

        // set newFork
        newFork.onionHead = keccak256(
            abi.encode(_lastOnionHead, keccak256(abi.encode(_transferData)))
        );
        bytes32 newForkKey = Fork.generateForkKey(
            chainId,
            newFork.onionHead,
            _index
        );

        // Determine whether there is a fork with newFork.destOnionHead as the key
        require(isExist(self, newForkKey) == false, "c1");

        newFork.destOnionHead = keccak256(
            abi.encode(_lastDestOnionHead, newFork.onionHead, msg.sender)
        );

        newFork.allAmount += _transferData.amount + _transferData.fee;
        newFork.length = _index + 1;
        newFork.lastCommiterAddress = msg.sender;

        // storage
        update(self, newForkKey, newFork);

        _newFork = newFork;
    }

    function getMbondOnionHeads(
        Info memory preWorkFork,
        Data.TransferData[] calldata _transferDatas,
        address[] calldata _commiters
    )
        internal
        pure
        returns (bytes32[] memory onionHeads, bytes32 destOnionHead)
    {
        // Determine whether this fork exists
        require(preWorkFork.length > 0, "Fork is null"); //use length

        destOnionHead = preWorkFork.destOnionHead;
        onionHeads[0] = preWorkFork.onionHead;

        // repeat
        for (uint256 i; i < _transferDatas.length; i++) {
            onionHeads[i + 1] = keccak256(
                abi.encode(
                    onionHeads[i],
                    keccak256(abi.encode(_transferDatas[i]))
                )
            );

            destOnionHead = keccak256(
                abi.encode(destOnionHead, onionHeads[i + 1], _commiters[i])
            );
        }
    }
}
