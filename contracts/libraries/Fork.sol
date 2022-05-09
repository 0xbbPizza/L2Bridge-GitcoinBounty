// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

contract NewDestinationContract {
    using HashOnions for mapping(uint256 => HashOnions.Info);
    using Fork for mapping(bytes32 => Fork.Info);

    mapping(bytes32 => Fork.Info) public hashOnionForks;
    mapping(uint256 => HashOnions.Info) public hashOnions;
    mapping(bytes32 => address) public onionsAddress;
    mapping(address => bool) private commiterDeposit;

    // uint256 public ONEFORK_MAX_LENGTH = 5; // !!! The final value is 50 , the higher the value, the longer the wait time and the less storage consumption
    // uint256 DEPOSIT_AMOUNT = 1 * 10**18; // !!! The final value is 2 * 10**17

    function _oneforkMaxLength() internal pure returns (uint8) {
        // !!! The final value is 50 , the higher the value, the longer the wait time and the less storage consumption
        return 5;
    }

    function _depositAmount() internal pure returns (uint256) {
        // !!! The final value is 2 * 10**17
        return 1 * 10**18;
    }
}

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
