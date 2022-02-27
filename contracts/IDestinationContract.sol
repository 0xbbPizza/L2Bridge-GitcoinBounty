// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;
import "./Data.sol";

interface IDestinationContract{
    
    struct MForkData{
        bytes32 forkKey;
        uint256 forkIndex;
        bytes32[] wrongtxHash;
    }

    event newClaim(address dest, uint256 amount, uint256 fee, uint256 txindex, bytes32 hashOnion);
    event newBond(uint256 txIndex,uint256 amount,bytes32 hashOnion);

    function getMsgSender() external view returns (address);
    function transfer(address dest, uint256 amount) external;
    function transferFrom(address dest,uint256 amount) external;
    function getCommiterDeposit() external view returns (bool);

    function zFork(uint256 chainId, bytes32 _forkKey, uint8 _index, address dest, uint256 amount, uint256 fee, bool _isRespond) external;
    function claim(uint256 chainId, bytes32 _forkKey, uint256 _forkIndex, uint256 _workIndex, Data.TransferData[] calldata _transferDatas,bool[] calldata _isResponds) external;
    function mFork(uint256 chainId, bytes32 _lastOnionHead, bytes32 _lastDestOnionHead, uint8 _index , Data.TransferData calldata _transferData, bool _isRespond) external;
    function zbond(uint256 chainId, bytes32 _forkKey,bytes32 _preForkKey, uint256 _preForkIndex, Data.TransferData[] calldata _transferDatas, address[] calldata _commiters) external;
    function mbond(uint256 chainId, MForkData[] calldata _mForkDatas,bytes32 _preForkKey, uint256 _preForkIndex, Data.TransferData[] calldata _transferDatas, address[] calldata _commiters) external;
    function buyOneOnion(uint256 chainId, bytes32 preHashOnion,Data.TransferData calldata _transferData) external;
    function buyOneFork(uint256 chainId, uint256 _forkKey, uint256 _forkId) external;
    
    // function getHashOnion(uint256 chainId, address[] calldata _bonderList,bytes32 _sourceHashOnion, bytes32 _bonderListHash) external;
}