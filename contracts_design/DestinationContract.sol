// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Data.sol";

interface IDestinationContract{
    
    struct HashOnionFork{
        // uint256 forkedFromTxIndex; 
        // uint256 forkedFromForkId;  // start at 1 not 0
        address forker;
        bytes32[] hashOnions;
        Data.TransferData[] transferDatas; //https://stackoverflow.com/questions/35743893/how-do-i-initialize-an-array-in-a-struct
        bytes32[] filter;
        mapping(address => uint256) balanceState;  //Use balancestate when bonding ？
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

        HashOnionFork storage newFork = creatNewFork();
        newFork.hashOnions.push(keccak256(abi.encode(zeroTransferData)));
        newFork.transferData.push(zeroTransferData);
        newFork.filter.push(Null);
        
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
        require(workFork.forker != Null,"fork is null");
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
            (firstFork, secondFork) = hashForkSplit(workFork, _workIndex, _forkKey, _forkId);
            
            HashOnionFork storage newFork = creatNewFork();
            // push to hashOnionForks
            firstFork.childCount += 1;
            hashOnionForks[_workIndex][firstFork.childCount] = newFork;
            workFork = newFork;

        
        // if workFork is full and "_workIndex == maxIndexInFork", it is same as "workIndex % ONEFORK_MAX_LENGTH == 0"
        }else if (workFork.hashOnions.length == ONEFORK_MAX_LENGTH){
            // if workfork have old childfork, Compared
            if(workFork.childCount){
                // obtain parentHashonion according to different situations
                bytes32 willInsertHashOnion = keccak256(abi.encode(parentHashonion,keccak256(abi.encode(_transferDatas[0]))));
                
                // Is it possible to do gas cost optimization?
                for (uint256 i = 1; i < workFork.childCount; i++){
                    require(hashOnionForks[_workIndex][i].hashOnions[0] != willInsertHashOnion, "d2");
                }
            }
            
            // automatically create a new fork if a special value is reached
            HashOnionFork storage newFork = creatNewFork();
            // push to hashOnionForks
            workFork.childCount += 1;
            hashOnionForks[_workIndex][workFork.childCount] = newFork;
            workFork = newFork;
        }

        // just append, Now workIndex meets the following conditions： workIndex == _forkKey + workFork.hashOnions.length + 1 
        for (uint256 i = 0; i < _transferDatas.length; i++){
            // Without doing more data checking, committers can only affect their own branches, What data should be checked if there is a fallback?
            preHashOnion = dealWith(workFork,_transferDatas[i],isRespond[i],parentHashonion)
        }
    }

    function creatNewFork(){
        mapping(address => uint256) storage balanceState;
        HashOnionFork storage newFork = {
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

        if(_isRespond){
            IERC20(_transferData.tokenAddress).safeTransferFrom(msg.sender,_transferData.destination,_transferData.amount);
            _workFork.balanceState[msg.sender] += _transferData.amount + _transferData.fee;
            _workFork.filter.push(msg.sender);
        }else{
            _workFork.balanceState[_transferData.destination] += transferData.amount + transferData.fee;
            _workFork.filter.push(Null);
        }

        _workFork.allAmount += _transferData.amount + _transferData.fee;

        return workHashOnion;
    }

    function hashForkSplit(HashOnionFork memory _workFork, uint8 _index, uint256 _forkKey, uint256 _forkId){
        
        uint8 a;
        uint8 b;
        HashOnionFork memory newFork = creatNewFork();

        if(2*_index <= _workFork.filter.length){
            // newFork_workFork
            a = 0;
            b = _index;

            newFork.childCount = 1;

            newFork.hashOnions = _workFork.hashOnions[:_index];
            _workFork.hashOnions = _workFork.hashOnions[_index:];

            newFork.transferDatas = _workFork.transferDatas[:_index];
            _workFork.transferDatas = _workFork.transferDatas[_index:];

            newFork.filter = _workFork.filter[:_index];
            _workFork.filter = _workFork.filter[_index:];

            newFork.filter = _workFork.filter[:_index];
            _workFork.filter = _workFork.filter[_index:];

            hashOnionForks[_forkKey][_forkId] = newFork;
            hashOnionForks[_forkKey + _index][newFork.childCount] = _workFork;

        }else {
            // workFork_newFork
            a = _index;
            b = _workFork.filter.length;

            newFork.childCount = _workFork.childCount;
            _workFork.childCount = 1;

            newFork.hashOnions = _workFork.hashOnions[_index:];
            _workFork.hashOnions = _workFork.hashOnions[:_index];

            newFork.transferDatas = _workFork.transferDatas[_index:];
            _workFork.transferDatas = _workFork.transferDatas[:_index];

            newFork.filter = _workFork.filter[_index:];
            _workFork.filter = _workFork.filter[:_index];

            newFork.filter = _workFork.filter[_index:];
            _workFork.filter = _workFork.filter[:_index];

            hashOnionForks[_forkKey + _index][_workFork.childCount] = newFork;
        }

            
        for (uint256 i = a; i < b; i++){
            if(_workFork.filter[i]){
                newFork.balanceState[_workFork.filter[i]] += _workFork.transferData[i].amount + _workFork.transferData[i].fee;
                _workFork.balanceState[_workFork.filter[i]] -= _workFork.transferData[i].amount + _workFork.transferData[i].fee;
            }else{
                newFork.balanceState[_workFork.transferData[i].destination] += _workFork.transferData[i].amount + _workFork.transferData[i].fee;
                _workFork.balanceState[_workFork.transferData[i].destination] -= _workFork.transferData[i].amount + _workFork.transferData[i].fee;
            }
            newFork.allAmount += _workFork.transferData[i].amount + _workFork.transferData[i].fee
            _workFork.allAmount -= _workFork.transferData[i].amount + _workFork.transferData[i].fee
        }
            
        if(2*_index <= _workFork.filter.length){
            return {newFork,_workFork}
        }else{
            return {_workFork,newFork}
        }
    }


    function bonder(uint256 _forkKey, uint256 _forkId, uint256 _index) external override{
        
    }
    
    function getHashOnion(address[] calldata _bonderList,bytes32 _sourceHashOnion, bytes32 _bonderListHash) external override{
        // judging only trust a target source

        // save sourceHashOnion
        sourceHashOnion = _sourceHashOnion;

        // Settlement for bond
    }
    // function buyOneFork(uint256 _forkKey, uint256 _forkId){

    // }
    // function buyOneOnion(uint256 _forkKey, uint256 _forkId, uint256 _index){

    // }
}   
