// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;
import "./Data.sol";

interface IDestChildContract{
    
    event newClaim(address dest, uint256 amount, uint256 fee, uint256 txindex, bytes32 hashOnion);
    event newBond(uint256 txIndex,uint256 amount,bytes32 hashOnion);

    function zFork(uint256 forkKeyNum, address dest, uint256 amount, uint256 fee, bool _isRespond) external;
    function claim(uint256 forkKeyNum, uint256 _workIndex, Data.TransferData[] calldata _transferDatas,bool[] calldata _isResponds) external;
    function mFork(bytes32 _lastOnionHead, bytes32 _lastDestOnionHead, uint8 _index , Data.TransferData calldata _transferData, bool _isRespond) external;
    function zbond(uint256 forkKeyNum, uint256 _preForkKeyNum, Data.TransferData[] calldata _transferDatas, address[] calldata _commiters) external;
    function mbond(Data.MForkData[] calldata _mForkDatas,uint256 forkKeyNum, Data.TransferData[] calldata _transferDatas, address[] calldata _commiters) external;
    function buyOneOnion(bytes32 preHashOnion,Data.TransferData calldata _transferData) external;
    function buyOneFork(uint256 _forkKey, uint256 _forkId) external;

    function bondSourceHashOnion(bytes32 hashOnion) external;
}
