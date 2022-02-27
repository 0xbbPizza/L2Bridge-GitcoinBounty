// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;
import "./Data.sol";

interface IDestChildContract{
    
    struct HashOnionFork{
        bytes32 onionHead;
        bytes32 destOnionHead;
        uint256 allAmount;
        uint256 length;  // !!! change to byte https://jeancvllr.medium.com/solidity-tutorial-all-about-bytes-9d88fdb22676
        address lastCommiterAddress;
        bool needBond; // true is need to settle 
    }
    
    struct MForkData{
        bytes32 forkKey;
        uint256 forkIndex;
        bytes32[] wrongtxHash;
    }

    event newClaim(address dest, uint256 amount, uint256 fee, uint256 txindex, bytes32 hashOnion);
    event newBond(uint256 txIndex,uint256 amount,bytes32 hashOnion);

    function zFork(uint256 forkKeyNum, address dest, uint256 amount, uint256 fee, bool _isRespond) external;
    function claim(uint256 forkKeyNum, uint256 _workIndex, Data.TransferData[] calldata _transferDatas,bool[] calldata _isResponds) external;
    function mFork(bytes32 _lastOnionHead, bytes32 _lastDestOnionHead, uint8 _index , Data.TransferData calldata _transferData, bool _isRespond) external;
    function zbond(uint256 forkKeyNum, bytes32 _preForkKey, uint256 _preForkIndex, Data.TransferData[] calldata _transferDatas, address[] calldata _commiters) external;
    function mbond(MForkData[] calldata _mForkDatas,bytes32 _preForkKey, uint256 _preForkIndex, Data.TransferData[] calldata _transferDatas, address[] calldata _commiters) external;
    function buyOneOnion(bytes32 preHashOnion,Data.TransferData calldata _transferData) external;
    function buyOneFork(uint256 _forkKey, uint256 _forkId) external;
}
