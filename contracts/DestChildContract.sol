// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "./libraries/Data.sol";
import "./libraries/Fork.sol";

// import "./IDestChildContract.sol";
// import "./IDestinationContract.sol";

contract DestChildContract {
    uint256 forkKeyID;

    // x
    mapping(uint256 => Fork.Info) public hashOnionForks;
    mapping(bytes32 => mapping(uint256 => uint256)) public forkKeysMap; // Submitter's bond record

    // mapping(address => uint256) public lPBalance;

    // x
    mapping(bytes32 => bool) isRespondOnions; // Whether it is a Onion that is not responded to
    mapping(bytes32 => address) public onionsAddress; // !!! Conflict with using zk scheme, new scheme needs to be considered when using zk

    // x Move to NewDestination.hashOnions
    bytes32 public sourceHashOnion; // Used to store the sent hash
    bytes32 public onWorkHashOnion; // Used to store settlement hash

    // x
    address routerAddress;

    // x
    uint256 public ONEFORK_MAX_LENGTH = 5;

    constructor(address _routerAddress) {
        routerAddress = _routerAddress; // x

        forkKeysMap[bytes32(0)][0] = ++forkKeyID;
        hashOnionForks[1] = Fork.Info(
            bytes32(0),
            bytes32(0),
            0,
            ONEFORK_MAX_LENGTH,
            address(0),
            false
        );
    }

    // x
    modifier onlyRouter() {
        require(msg.sender == routerAddress, "NOT_ROUTER");
        _;
    }

    // Params: chainId, hashOnion
    function getFork(uint256 forkKeyNum)
        external
        view
        returns (Fork.Info memory fork)
    {
        fork = hashOnionForks[forkKeyNum];
    }

    // x
    function getForkKeyNum(bytes32 key, uint256 index)
        external
        view
        returns (uint256 keyNum)
    {
        keyNum = forkKeysMap[key][index];
    }

    // x
    function setForKeyNum(
        bytes32 key,
        uint256 index,
        uint256 keyNum
    ) external onlyRouter {
        forkKeysMap[key][index] = keyNum;
    }

    // Params: chainId, hashOnion, index, fork
    // Remove onlyRouter
    function setFork(
        bytes32 key,
        uint256 index,
        Fork.Info calldata fork
    ) external onlyRouter {
        forkKeysMap[key][index] = ++forkKeyID;
        hashOnionForks[forkKeyID] = fork;
    }

    function setForkWithForkKey(uint256 forkKeyNum, Fork.Info calldata fork)
        external
        onlyRouter
    {
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
    // x Move to NewDestination.bondSourceHashOnion
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
