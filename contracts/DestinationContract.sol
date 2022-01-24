// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;
import "./Data.sol";

interface IDestinationContract{
    
    struct HashOnionFork{
        uint256 forkedFromTxIndex; 
        uint256 forkedFromForkId;
        address forker;
        bytes32[] hashOnions;
        Data.TransferData[] transferDatas;
        bool[] filter;
        mapping(address => uint256) forkState;
    }

    mapping(uint256 => mapping(uint256 => HashOnionFork)) hashOnionForks;

    uint256 sourceTxIndex;
    bytes32 sourceHashOnion;

    event newClaim(Data.TransferData transferData, uint256 txindex, bytes32 hashOnion);
    event newBond(uint256 txIndex,uint256 amount,bytes32 hashOnion);

    function claim(uint256 _txIndex, uint256 _forkId, Data.TransferData memory _transferData) external;
    function bonder(bytes32 sourceHashOnion, uint256 _txIndex, uint256 _forkId) external;
    function getHashOnion(address[] calldata _bonderList,bytes32 _sourceHashOnion, bytes32 _bonderListHash) external;
}

contract DestinationContract is IDestinationContract{
    function claim(uint256 _txIndex, uint256 _forkId, Data.TransferData memory _transferData) external{
        HashOnionFork storage destHashOnionFork = hashOnionForks[_txIndex][_forkId];
        require(destHashOnionFork.forkedFromForkId != 0,"fork is null");
        // hashOnions 

    }
    function bonder(bytes32 sourceHashOnion, uint256 _txIndex, uint256 _forkId) external{

    }
    function getHashOnion(address[] calldata _bonderList,bytes32 _sourceHashOnion, bytes32 _bonderListHash) external{

    }
}   
