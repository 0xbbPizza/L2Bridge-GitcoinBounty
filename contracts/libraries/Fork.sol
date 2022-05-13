// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

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

    /// @param chainId Chain's id
    /// @param hashOnion Equal to Fork.Info.onionHead
    /// @param index Fork's index
    function generateInfoKey(
        uint256 chainId,
        bytes32 hashOnion,
        uint256 index
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(chainId, hashOnion, index));
    }
}
