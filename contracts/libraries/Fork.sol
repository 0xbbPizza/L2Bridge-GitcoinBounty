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

    function clear(mapping(uint256 => Fork.Info) storage self, uint256 forkId)
        internal
    {
        delete self[forkId];
    }

    // function create(mapping(uint256 => Fork.Info) storage self, uint256 forkId)
    //     internal
    //     pure
    //     returns (Info memory forkInfo)
    // {}

    function updata(mapping(uint256 => Fork.Info) storage self, uint256 forkId)
        internal
    {}

    function creatInfoKey(
        uint256 chainId,
        bytes32 hashOnion,
        uint256 index
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(chainId, hashOnion, index));
    }
}
