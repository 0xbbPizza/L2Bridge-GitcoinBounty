// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Data.sol";

interface IDestinationContract{
    
    struct HashOnionFork{
        uint256 forkedFromTxIndex; 
        uint256 forkedFromForkId;  // start at 1 not 0
        address forker;
        bytes32[] hashOnions;
        Data.TransferData[] transferDatas; //https://stackoverflow.com/questions/35743893/how-do-i-initialize-an-array-in-a-struct
        bool[] filter;
        mapping(address => uint256) balanceState;
        uint256 childCount;
        uint256 allAmount;
    }

    event newClaim(Data.TransferData transferData, uint256 txindex, bytes32 hashOnion);
    event newBond(uint256 txIndex,uint256 amount,bytes32 hashOnion);

    function claim(uint256 _txIndex, uint256 _forkId, Data.TransferData memory _transferData) external;
    function bonder(bytes32 sourceHashOnion, uint256 _txIndex, uint256 _forkId) external;
    function getHashOnion(address[] calldata _bonderList,bytes32 _sourceHashOnion, bytes32 _bonderListHash) external;
}

contract DestinationContract is IDestinationContract{
    using SafeERC20 for IERC20;

    mapping(uint256 => mapping(uint256 => HashOnionFork)) hashOnionForks;  // key1 start at 0, key2 start at 1

    uint256 sourceTxIndex;
    bytes32 sourceHashOnion;

    uint8 ONEFORK_MAX_LENGTH = 50;

    constructor(address _tokenAddress){
        // Such initialization requires the help of factory contracts to support multiple currencies, and cannot demonstrate censorship resistance.
        TransferData storage zeroTransferData = {
            _tokenAddress,
            address(0),
            0,
            0
        };

        HashOnionFork storage newFork = creatNewFork(0,1);
        newFork.hashOnions.push(keccak256(abi.encode(zeroTransferData)));
        newFork.transferData.push(zeroTransferData);
        newFork.filter.push(true);
        
        hashOnionForks[0][1] = newFork;
    }

    function claim(uint256 _forkKey, uint256 _forkId, uint256 _workIndex, Data.TransferData[] memory _transferDatas, bool[] isRespond) external override{
        
        // incoming data length is correct
        require(_transferDatas.length > 0, "a1")
        require(_transferDatas.length == isRespond.length, "a2")
        // can't do anything to tx with index 0
        require(_workIndex != 0, "b")
        // positioning fork
        HashOnionFork storage workFork = hashOnionForks[_forkKey][_forkId];
        // fork must exist
        require(workFork.forkedFromForkId != 0,"fork is null");
        // the maximum index of the current Fork
        uint256 maxIndexInFork = _forkKey + workFork.hashOnions.length;
        // _workIndex must in the right range
        require(_workIndex > _forkKey && _workIndex <= maxIndexInFork, "c");

        /* 
        * under this scheme, in the event of competing submissions between market makers, 
        * all submissions from latecomers will be rejected. 
        * If we want to have higher compatibility and check every commit, 
        * we can put the judgment condition in the for loop.
        */
        
        // parentHashonion 
        bytes32 parentHashonion;
        parentHashonion = workFork.hashOnions[_workIndex - _forkKey - 1];

        // when intent is insert
        if (_workIndex != maxIndexInFork ){
            // determine whether the first inserted transferDatas exists
            bytes32 existingHashOnion = workFork.hashOnions[_workIndex - _forkKey];
            // obtain parentHashonion according to different situations
            bytes32 willInsertHashOnion = keccak256(abi.encode(parentHashonion,keccak256(abi.encode(_transferDatas[0]))));
            // determine whether to repeat, If repeated, exit
            require(willInsertHashOnion != existingHashOnion, "d1")

            // if different, create new fork , and work on new fork
            (workFork, _forkKey, _forkId) = hashForkSplit(workFork, _workIndex, willInsertHashOnion);
        
        // if workFork is full and "_workIndex == maxIndexInFork", it is same as "workIndex % ONEFORK_MAX_LENGTH == 0"
        }else if (workFork.hashOnions.length == ONEFORK_MAX_LENGTH){
            // if workfork have old childfork, Compared
            if(workFork.childCount){
                // obtain parentHashonion according to different situations
                bytes32 willInsertHashOnion = keccak256(abi.encode(parentHashonion,keccak256(abi.encode(_transferDatas[0]))));

                for (uint256 i = 1; i < workFork.childCount; i++){
                    require(hashOnionForks[_forkKey][_forkId].hashOnions[0] != willInsertHashOnion, "d2");
                }
            }
            
            // automatically create a new fork if a special value is reached
            HashOnionFork storage newFork = creatNewFork(_forkKey , _forkId);
            // push to hashOnionForks
            workFork.childCount += 1;
            hashOnionForks[workIndex][workFork.childCount] = newFork;
            workFork = newFork;
        }

        // just append
        for (uint256 i = 0; i < _transferDatas.length; i++){
            
            // Now workIndex meets the following conditions： workIndex == _forkKey + workFork.hashOnions.length + 1 ?
            workIndex = _workIndex + i;

            // Without doing more data checking, committers can only affect their own branches, What data should be checked if there is a fallback?
            preHashOnion = dealWith(workFork,_transferDatas[i],isRespond[i],parentHashonion)
        }
    }

    function creatNewFork(uint256 forkedFromTxIndex,uint256 forkedFromForkId){
        mapping(address => uint256) storage balanceState;
        HashOnionFork storage newFork = {
            forkedFromTxIndex,
            forkedFromForkId,
            msg.sender, 
            [],
            [],
            [],
            balanceState,
            0,
            0
        };
        return newFork;
    }

    function dealWith(HashOnionFork memory _workFork, Data.TransferData memory _transferData, bool _isRespond, bytes32 _parentHashonion){
        workHashOnion = keccak256(abi.encode(_parentHashonion,keccak256(abi.encode(transferData))));
        _workFork.hashOnions.push(workHashOnion);

        _workFork.transferDatas.push(_transferData);
        
        _workFork.filter.push(_isRespond);

        if(_isRespond){
            IERC20(_transferData.tokenAddress).safeTransferFrom(msg.sender,_transferData.destination,_transferData.amount);
            _workFork.balanceState[msg.sender] += _transferData.amount + _transferData.fee;
        }else{
            _workFork.balanceState[_transferData.destination] += transferData.amount + transferData.fee;
        }

        _workFork.allAmount += _transferData.amount + _transferData.fee;

        return workHashOnion;
    }

    function hashForkSplit(destHashOnionFork, index){

        


        // warning: Determine whether the first hashonion of workFork is duplicated with other fork[0]
        (_workFork, parallelFork, parentFork) = hashForkSplit(workFork, _insertIndex);
        workFork = _workFork;
        parentFork.childCount += 1;
        hashOnionForks[_insertIndex][parentFork.childCount] = parallelFork;
        parentFork.childCount += 1;
        hashOnionForks[_insertIndex][parentFork.childCount] = workFork;
        return {
            newParentFork,
            parallelFork,
            workFork
        }
    }
    function hashForkSplicing(destHashOnionFork, transferDatas, index){
        
        return {
            newParentFork,
            parallelFork
        }
    }


    function bonder(bytes32 sourceHashOnion, uint256 _txIndex, uint256 _forkId) external override{

    }
    function getHashOnion(address[] calldata _bonderList,bytes32 _sourceHashOnion, bytes32 _bonderListHash) external override{

    }
    function buyOneFork(){

    }
    function buyOneOnion(){

    }
}   
