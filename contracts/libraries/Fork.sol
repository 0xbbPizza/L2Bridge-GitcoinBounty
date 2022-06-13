// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "./Data.sol";

// import "hardhat/console.sol";

library HashOnions {
    struct Info {
        bytes32 sourceHashOnion;
        bytes32 onWorkHashOnion;
    }
}

library Fork {
    struct Info {
        uint16 workIndex; // 0: zFork, >0: mFork
        bytes32 onionHead;
        bytes32 destOnionHead;
        uint256 allAmount;
        uint256 length;
        address lastCommiterAddress;
        bool needBond; // true is need to settle
        uint8 verifyStatus; // 0: No verify, 1: Verified - fork is real, 2: Verified - fork is fake
    }

    /// @param forkKey fork's key
    function isExist(mapping(bytes32 => Info) storage self, bytes32 forkKey)
        internal
        view
        returns (bool)
    {
        return self[forkKey].length > 0;
    }

    /// @param forkKey fork's key
    function remove(mapping(bytes32 => Info) storage self, bytes32 forkKey)
        internal
    {
        delete self[forkKey];
    }

    /// @param forkKey fork's key
    /// @param forkInfo fork
    function update(
        mapping(bytes32 => Info) storage self,
        bytes32 forkKey,
        Info memory forkInfo
    ) internal {
        self[forkKey] = forkInfo;
    }

    /// Get fork by forkKey. When no exist, report error
    function getForkEnsure(
        mapping(bytes32 => Info) storage self,
        bytes32 forkKey
    ) internal view returns (Info memory) {
        Info memory fork = self[forkKey];

        require(fork.length > 0, "Fork is null"); //use length

        return fork;
    }

    /// @param chainId Chain's id
    /// @param hashOnion Equal to fork's first Info.onionHead
    /// @param index Fork's index
    function generateForkKey(
        uint256 chainId,
        bytes32 hashOnion,
        uint16 index
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(chainId, hashOnion, index));
    }

    /// @param prevOnionHead Prev onionHead
    /// @param transferData Transfer's data
    function generateOnionHead(
        bytes32 prevOnionHead,
        Data.TransferData memory transferData
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(prevOnionHead, keccak256(abi.encode(transferData)))
            );
    }

    /// @param prevDestOnionHead Prev fork destOnionHead
    /// @param onionHead Current fork onionHead
    /// @param committer Fork committer
    function generateDestOnionHead(
        bytes32 prevDestOnionHead,
        bytes32 onionHead,
        address committer
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(prevDestOnionHead, onionHead, committer));
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
            Info(0, bytes32(0), bytes32(0), 0, maxLength, address(0), false, 0)
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
        newFork.onionHead = generateOnionHead(
            workFork.onionHead,
            Data.TransferData(dest, amount, fee)
        );
        bytes32 newForkKey = generateForkKey(chainId, newFork.onionHead, 0);

        // Determine whether there is a fork with newForkKey
        require(isExist(self, newForkKey) == false, "c1");

        newFork.destOnionHead = generateDestOnionHead(
            workFork.destOnionHead,
            newFork.onionHead,
            msg.sender
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
        uint16 _index,
        Data.TransferData calldata _transferData
    ) internal returns (Info memory) {
        // Create a new Fork
        Info memory newFork;

        // set newFork
        newFork.onionHead = Fork.generateOnionHead(
            _lastOnionHead,
            _transferData
        );
        bytes32 newForkKey = generateForkKey(
            chainId,
            newFork.onionHead,
            _index
        );

        // Determine whether there is a fork with newFork.destOnionHead as the key
        require(isExist(self, newForkKey) == false, "c1");

        newFork.destOnionHead = generateDestOnionHead(
            _lastDestOnionHead,
            newFork.onionHead,
            msg.sender
        );

        newFork.workIndex = _index;
        newFork.allAmount = _transferData.amount + _transferData.fee;
        newFork.length = _index + 1;
        newFork.lastCommiterAddress = msg.sender;
        newFork.needBond = true;

        // storage
        update(self, newForkKey, newFork);

        return newFork;
    }

    /// @param _transferDatas [{destination, amount, fee}...]
    /// @param _committers committers
    function getMbondOnionHeads(
        Info memory preWorkFork,
        Data.TransferData[] calldata _transferDatas,
        address[] calldata _committers
    )
        internal
        pure
        returns (bytes32[] memory onionHeads, bytes32 destOnionHead)
    {
        onionHeads = new bytes32[](_transferDatas.length + 1);
        onionHeads[0] = preWorkFork.onionHead;
        destOnionHead = preWorkFork.destOnionHead;

        // repeat
        for (uint256 i; i < _transferDatas.length; i++) {
            onionHeads[i + 1] = generateOnionHead(
                onionHeads[i],
                _transferDatas[i]
            );

            destOnionHead = generateDestOnionHead(
                destOnionHead,
                onionHeads[i + 1],
                _committers[i]
            );
        }
    }
}
