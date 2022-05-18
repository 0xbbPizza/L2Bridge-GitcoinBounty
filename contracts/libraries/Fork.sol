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
        bytes32 forkKey = generateInfoKey(chainId, hashOnion, index);
        return self[forkKey];
    }

    /// @param chainId Chain's id
    /// @param hashOnion Equal to fork's first Info.onionHead
    /// @param index Fork's index
    function generateInfoKey(
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
        bytes32 forkKey = generateInfoKey(chainId, bytes32(0), 0);
        require(isExist(self, forkKey) == false);

        update(
            self,
            forkKey,
            Info(bytes32(0), bytes32(0), 0, maxLength, address(0), false)
        );
    }

    /// @param hashOnion Current work fork's hash
    function createZFork(
        mapping(bytes32 => Info) storage self,
        uint256 chainId,
        bytes32 hashOnion,
        address dest,
        uint256 amount,
        uint256 fee
    ) internal returns (Info memory _workFork, Info memory _newFork) {
        // Take out the Fork
        bytes32 workForkKey = generateInfoKey(chainId, hashOnion, 0);
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
        bytes32 newForkKey = generateInfoKey(chainId, newFork.onionHead, 0);

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

    function settlementMbond(
        mapping(bytes32 => Info) storage self,
        uint256 chainId,
        Info memory preWorkFork,

    ) internal {

        require(_mForkDatas.length > 1, "a1");

        // incoming data length is correct
        require(_transferDatas.length == ONEFORK_MAX_LENGTH, "a1");
        require(_transferDatas.length == _commiters.length, "a2");

        bytes32 preWorkForkKey = Fork.generateInfoKey(chainId, hashOnion, 0);
        Fork.Info memory preWorkFork = hashOnionForks[preWorkForkKey];

        // Determine whether this fork exists
        require(preWorkFork.length > 0, "fork is null"); //use length

        bytes32 destOnionHead = preWorkFork.destOnionHead;
        bytes32 onionHead = preWorkFork.onionHead;
        uint256 y = 0;

        // repeat
        for (uint256 i; i < _transferDatas.length; i++) {
            bytes32 preForkOnionHead = onionHead;
            onionHead = keccak256(
                abi.encode(onionHead, keccak256(abi.encode(_transferDatas[i])))
            );

            /* 
                If this is a fork point, make two judgments
                1. Whether the parallel fork points of the fork point are the same, if they are the same, it means that the fork point is invalid, that is, the bond is invalid. And submissions at invalid fork points will not be compensated
                2. Whether the headOnion of the parallel fork point can be calculated by the submission of the bond, if so, the incoming parameters of the bond are considered valid
            */
            if (_mForkDatas[y].forkIndex == i) {
                // Determine whether the fork needs to be settled, and also determine whether the fork exists
                checkForkData(
                    _mForkDatas[y - 1],
                    _mForkDatas[y],
                    preForkOnionHead,
                    onionHead,
                    i,
                    chainId
                );
                y += 1;
                // !!! Calculate the reward, and reward the bond at the end, the reward fee is the number of forks * margin < margin equal to the wrongtx gaslimit overhead brought by 50 Wrongtx in this method * common gasPrice>
            }
            if (isRespondOnions[chainId][onionHead]) {
                address onionAddress = onionsAddress[onionHead];
                if (onionAddress != address(0)) {
                    IERC20(tokenAddress).safeTransfer(
                        onionAddress,
                        _transferDatas[i].amount + _transferDatas[i].fee
                    );
                } else {
                    IERC20(tokenAddress).safeTransfer(
                        _transferDatas[i].destination,
                        _transferDatas[i].amount + _transferDatas[i].fee
                    );
                }
            } else {
                IERC20(tokenAddress).safeTransfer(
                    _commiters[i],
                    _transferDatas[i].amount + _transferDatas[i].fee
                );
            }
            destOnionHead = keccak256(
                abi.encode(destOnionHead, onionHead, _commiters[i])
            );
        }
    }
}
