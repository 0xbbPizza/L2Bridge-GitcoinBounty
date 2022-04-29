// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "./Data.sol";

// import "./IDestChildContract.sol";
// import "./IDestinationContract.sol";

contract DestChildContract {
    uint256 forkKeyID;
    mapping(uint256 => Data.HashOnionFork) public hashOnionForks;
    mapping(bytes32 => mapping(uint256 => uint256)) public forkKeysMap; // Submitter's bond record

    // mapping(address => uint256) public lPBalance;

    mapping(bytes32 => bool) isRespondOnions; // Whether it is a Onion that is not responded to
    mapping(bytes32 => address) public onionsAddress; // !!! Conflict with using zk scheme, new scheme needs to be considered when using zk

    bytes32 public sourceHashOnion; // Used to store the sent hash
    bytes32 public onWorkHashOnion; // Used to store settlement hash

    address routerAddress;

    uint256 public ONEFORK_MAX_LENGTH = 5;

    constructor(address _routerAddress) {
        routerAddress = _routerAddress;
        forkKeysMap[
            0x0000000000000000000000000000000000000000000000000000000000000000
        ][0] = ++forkKeyID;
        hashOnionForks[1] = Data.HashOnionFork(
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0,
            ONEFORK_MAX_LENGTH,
            address(0),
            false
        );
    }

    modifier onlyRouter() {
        require(msg.sender == routerAddress, "NOT_ROUTER");
        _;
    }

    function getFork(uint256 forkKeyNum)
        external
        view
        returns (Data.HashOnionFork memory fork)
    {
        fork = hashOnionForks[forkKeyNum];
    }

    function getForkKeyNum(bytes32 key, uint256 index)
        external
        view
        returns (uint256 keyNum)
    {
        keyNum = forkKeysMap[key][index];
    }

    function setForKeyNum(
        bytes32 key,
        uint256 index,
        uint256 keyNum
    ) external onlyRouter {
        forkKeysMap[key][index] = keyNum;
    }

    function setFork(
        bytes32 key,
        uint256 index,
        Data.HashOnionFork calldata fork
    ) external onlyRouter {
        forkKeysMap[key][index] = ++forkKeyID;
        hashOnionForks[forkKeyID] = fork;
    }

    function setForkWithForkKey(
        uint256 forkKeyNum,
        Data.HashOnionFork calldata fork
    ) external onlyRouter {
        hashOnionForks[forkKeyNum] = fork;
    }

    function setIsRepondOnion(bytes32 onion, bool state) external onlyRouter {
        isRespondOnions[onion] = state;
    }

    function setOnionAddress(bytes32 onion, address addr) external onlyRouter {
        onionsAddress[onion] = addr;
    }

    function getIsRepondOnion(bytes32 onion)
        external
        view
        returns (bool state)
    {
        state = isRespondOnions[onion];
    }

    function setOnWorkHashOnion(bytes32 onion, bool equal) external onlyRouter {
        if (equal) {
            onWorkHashOnion = onion;
        } else {
            // If no settlement is required, it means that the previous round of settlement is completed, and a new value is set
            onWorkHashOnion = sourceHashOnion;
        }
    }

    function setNeedBond(uint256 forkKeyNum, bool state) external onlyRouter {
        hashOnionForks[forkKeyNum].needBond = state;
    }

    // TODO it is not already ok
    function bondSourceHashOnion(bytes32 _sourceHashOnion) external {
        if (onWorkHashOnion == "" || onWorkHashOnion == sourceHashOnion) {
            onWorkHashOnion = _sourceHashOnion;
        }
        sourceHashOnion = _sourceHashOnion;
    }

    // TODO add reset function set onworkonion

    function buyOneFork(uint256 _forkKey, uint256 _forkId) external {
        // Unfinished hashOnions can be purchased
    }
}
