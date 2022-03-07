// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;
import "./Data.sol";
import "./IDestChildContract.sol";
import "./IDestinationContract.sol";


contract DestChildContract is IDestChildContract{
    
    uint256 forkKeyID;
    mapping(uint256 => Data.HashOnionFork) public hashOnionForks;
    mapping(bytes32 => mapping(uint256 => uint256)) public forkKeysMap; // Submitter's bond record

    // mapping(address => uint256) public lPBalance;

    mapping(bytes32 => bool) isRespondOnions;   // Whether it is a Onion that is not responded to
    mapping(bytes32 => address) onionsAddress;  // !!! Conflict with using zk scheme, new scheme needs to be considered when using zk

    bytes32 public sourceHashOnion;   // Used to store the sent hash
    bytes32 public onWorkHashOnion;   // Used to store settlement hash

    address routerAddress;

    uint256 public ONEFORK_MAX_LENGTH = 5;  // !!! The final value is 50 , the higher the value, the longer the wait time and the less storage consumption
    uint256 DEPOSIT_AMOUNT = 1 * 10**18;  // !!! The final value is 2 * 10**17

    constructor(address _routerAddress){
        routerAddress = _routerAddress;
        forkKeysMap[0x0000000000000000000000000000000000000000000000000000000000000000][0] = forkKeyID++;
        hashOnionForks[0] = Data.HashOnionFork(
                0x0000000000000000000000000000000000000000000000000000000000000000,
                0x0000000000000000000000000000000000000000000000000000000000000000,
                0,
                ONEFORK_MAX_LENGTH,
                address(0),
                false
            );
    }

    modifier onlyRouter {
        require(msg.sender == routerAddress, "NOT_ROUTER");
        _;
    }

    /* 
        A. Ensure that a single correct fork link is present:
        There are three behaviors of commiters related to fork:
        1. Create a 0-bit fork
        2. Create a non-zero fork
        3. Add OnionHead to any Fork

        The rules are as follows:
        1. Accept any submission, zero-bit Fork needs to pass in PreForkkey
        2. Fork starting with non-zero bits, length == ONEFORK_MAX_LENGTH - index (value range 1-49)

        B. Ensure that only the only correct fork link will be settled:
        1. onWorkHashOnion's index % ONEFORK_MAX_LENGTH == ONEFORK_MAX_LENGTH
        2. When bonding, the bond is the bond from the back to the front. If the fork being bonded is a non-zero fork, you need to provide preForkKey, onions1, onions2, and the parameters must meet the following conditions:
           2.1 f(onions) == preFork.onionHead
           2.2 onions[0] != fork.key //If there is an equal situation, then give the allAmount of the fork to onions[0].address . The bonder gets a deposit to compensate the gas fee.
           2.3 fork.onionHead == onWorkHashOnion

        C. Guarantee that bad commits will be penalized:
        1. CommiterA deposits the deposit, initiates a commit or fork, and the deposit is locked
        2. The margin can only be unlocked by the addition of another Committer  
    */

    // if fork index % ONEFORK_MAX_LENGTH == 0 
    // !!! Can be used without getting the previous fork
    function zFork(uint256 forkKeyNum, address dest, uint256 amount, uint256 fee, bool _isRespond) external override onlyRouter{

        // Take out the Fork
        Data.HashOnionFork storage workFork = hashOnionForks[forkKeyNum];
        
        if (IDestinationContract(routerAddress).getCommiterDeposit() == false){
            // If same commiter, don't need deposit
            require(tx.origin == workFork.lastCommiterAddress, "a2");
        }

        // Create a new Fork
        Data.HashOnionFork memory newFork;

        // set newFork
        newFork.onionHead = keccak256(abi.encode(workFork.onionHead,keccak256(abi.encode(dest,amount,fee))));
        // Determine whether there is a fork with newFork.destOnionHead as the key
        require(forkKeysMap[newFork.onionHead][0] == 0, "c1");

        newFork.destOnionHead = keccak256(abi.encode(workFork.destOnionHead, newFork.onionHead , tx.origin));
        
        // Determine whether the maker only submits or submits and responds
        if(_isRespond){
            IDestinationContract(routerAddress).transferFrom(dest,amount);
        }else{
            // !!! Whether to add the identification position of the index
            isRespondOnions[newFork.onionHead] = true; 
        }
        
        newFork.allAmount += amount + fee;
        newFork.length = 1;
        newFork.lastCommiterAddress = tx.origin;
        newFork.needBond = true;

        // storage
        forkKeysMap[newFork.onionHead][0] = forkKeyID++;
        hashOnionForks[forkKeyID] = newFork;
        

        // Locks the new committer's bond, unlocks the previous committer's bond state
        if (workFork.lastCommiterAddress != tx.origin){
            IDestinationContract(routerAddress).changeDepositState(workFork.lastCommiterAddress,true);
            IDestinationContract(routerAddress).changeDepositState(tx.origin,false);
        }

        emit newClaim(dest,amount,fee,0,newFork.onionHead); 
    }

    // just append
    function claim(uint256 forkKeyNum, uint256 _workIndex, Data.TransferData[] calldata _transferDatas,bool[] calldata _isResponds) external override onlyRouter{
        
        // incoming data length is correct
        require(_transferDatas.length > 0, "a1");

        // positioning fork
        Data.HashOnionFork memory workFork = hashOnionForks[forkKeyNum];
        
        // Determine whether this fork exists
        require(workFork.length > 0,"fork is null"); //use length

        // Determine the eligibility of the submitter
        if (IDestinationContract(routerAddress).getCommiterDeposit() == false){
            require(tx.origin == workFork.lastCommiterAddress, "a3");
        }
        
        // Determine whether someone has submitted it before. If it has been submitted by the predecessor, tx.origin thinks that the submission is incorrect and can be forked and resubmitted through forkFromInput
        // !!! Avoid duplicate submissions
        require(_workIndex == workFork.length, "b2");
        
        // Judge _transferDatas not to exceed the limit
        require(_workIndex + _transferDatas.length <= ONEFORK_MAX_LENGTH, "a2");
        
        bytes32 onionHead = workFork.onionHead;
        bytes32 destOnionHead = workFork.destOnionHead;
        uint256 allAmount = 0;
        // just append
        for (uint256 i; i < _transferDatas.length; i++){
            onionHead = keccak256(abi.encode(onionHead,keccak256(abi.encode(_transferDatas[i]))));
            if(_isResponds[i]){
                IDestinationContract(routerAddress).transferFrom(_transferDatas[i].destination,_transferDatas[i].amount);
            }else{
                isRespondOnions[onionHead] = true;
            }
            destOnionHead = keccak256(abi.encode(destOnionHead,onionHead,tx.origin));
            allAmount += _transferDatas[i].amount + _transferDatas[i].fee;

            emit newClaim(_transferDatas[i].destination,_transferDatas[i].amount,_transferDatas[i].fee,_workIndex+i,onionHead); 
        }
        
        // change deposit , deposit token is ETH , need a function to deposit and with draw
        if (workFork.lastCommiterAddress != tx.origin){
            IDestinationContract(routerAddress).changeDepositState(workFork.lastCommiterAddress,true);
            IDestinationContract(routerAddress).changeDepositState(tx.origin,false);
        }

        workFork = Data.HashOnionFork({
            onionHead: onionHead, 
            destOnionHead: destOnionHead,
            allAmount: allAmount + workFork.allAmount,
            length: _workIndex + _transferDatas.length,
            lastCommiterAddress: tx.origin,
            needBond: workFork.needBond
        });
        
        hashOnionForks[forkKeyNum] = workFork;
    }

    // if fork index % ONEFORK_MAX_LENGTH != 0
    function mFork(bytes32 _lastOnionHead, bytes32 _lastDestOnionHead, uint8 _index , Data.TransferData calldata _transferData, bool _isRespond) external override onlyRouter {
        // Determine whether tx.origin is eligible to submit
        require(IDestinationContract(routerAddress).getCommiterDeposit() == true, "a3");

        // Create a new Fork
        Data.HashOnionFork memory newFork;

        // set newFork
        newFork.onionHead = keccak256(abi.encode(_lastOnionHead,keccak256(abi.encode(_transferData))));
        // Determine whether there is a fork with newFork.destOnionHead as the key
        require(forkKeysMap[newFork.onionHead][_index] == 0, "c1");

        newFork.destOnionHead = keccak256(abi.encode(_lastDestOnionHead, newFork.onionHead , tx.origin));

        // Determine whether the maker only submits or submits and also responds, so as to avoid the large amount of unresponsiveness of the maker and block subsequent commints
        if(_isRespond){
            IDestinationContract(routerAddress).transferFrom(_transferData.destination,_transferData.amount);
        }else{
            isRespondOnions[newFork.onionHead] = true;
        }
        
        newFork.allAmount += _transferData.amount + _transferData.fee;
        newFork.length = _index;
        newFork.lastCommiterAddress = tx.origin;

        // storage
        forkKeysMap[newFork.onionHead][_index] = forkKeyID++;
        hashOnionForks[forkKeyID] = newFork;

        // Freeze Margin
        IDestinationContract(routerAddress).changeDepositState(tx.origin,false);
    }

    // clearing zfork
    // !!! how to clearing the first zfork that have no preFork
    function zbond(
        uint256 forkKeyNum,
        uint256 _preForkKeyNum, 
        Data.TransferData[] calldata _transferDatas, address[] calldata _commiters
        ) external override onlyRouter{ 

        // incoming data length is correct
        require(_transferDatas.length > 0, "a1");
        require(_commiters.length == _transferDatas.length, "a2");
        
        Data.HashOnionFork memory workFork = hashOnionForks[forkKeyNum];
        
        // Judging whether this fork exists && Judging that the fork needs to be settled
        require(workFork.needBond, "a3"); 
        workFork.needBond = false;

        // Determine whether the onion of the fork has been recognized
        require(workFork.onionHead == onWorkHashOnion,"a4"); //use length
        
        Data.HashOnionFork memory preWorkFork = hashOnionForks[_preForkKeyNum];
        // Determine whether this fork exists
        require(preWorkFork.length > 0,"fork is null"); //use length

        bytes32 onionHead = preWorkFork.onionHead;
        bytes32 destOnionHead = preWorkFork.destOnionHead;
        // repeat
        for (uint256 i; i < _transferDatas.length; i++){
            onionHead = keccak256(abi.encode(onionHead,keccak256(abi.encode(_transferDatas[i]))));
            if (isRespondOnions[onionHead]){
                if (onionsAddress[onionHead] != address(0)){
                    IDestinationContract(routerAddress).transfer(onionsAddress[onionHead],_transferDatas[i].amount + _transferDatas[i].fee);
                }else{
                    IDestinationContract(routerAddress).transfer(_transferDatas[i].destination,_transferDatas[i].amount + _transferDatas[i].fee);
                }
            }else{
                IDestinationContract(routerAddress).transfer(_commiters[i],_transferDatas[i].amount + _transferDatas[i].fee);
            }
            destOnionHead = keccak256(abi.encode(destOnionHead,onionHead,_commiters[i]));
        }
        
        // Assert that the replay result is equal to the stored value of the fork, which means that the incoming _transferdatas are valid
        require(destOnionHead == workFork.destOnionHead,"a5");

        // If the prefork also needs to be settled, push the onWorkHashOnion forward a fork
        if (preWorkFork.needBond){
            onWorkHashOnion = preWorkFork.onionHead;
        }else{ 
            // If no settlement is required, it means that the previous round of settlement is completed, and a new value is set
            onWorkHashOnion = sourceHashOnion;
        }

        // !!! Reward bonder
    }
    

    // Settlement non-zero fork
    function mbond(
        Data.MForkData[] calldata _mForkDatas,
        uint256 forkKeyNum,
        Data.TransferData[] calldata _transferDatas, address[] calldata _commiters
        ) external override onlyRouter{
        
        require( _mForkDatas.length > 1, "a1");
        
        // incoming data length is correct
        require(_transferDatas.length == ONEFORK_MAX_LENGTH, "a1");
        require(_transferDatas.length == _commiters.length, "a2");

        Data.HashOnionFork memory preWorkFork = hashOnionForks[forkKeyNum];
        // Determine whether this fork exists
        require(preWorkFork.length > 0,"fork is null"); //use length

        bytes32 onionHead = preWorkFork.onionHead;
        bytes32 destOnionHead = preWorkFork.destOnionHead;
        uint256 y = 0;

        // repeat
        for (uint256 i; i < _transferDatas.length; i++){
            bytes32 preForkOnionHead = onionHead;
            onionHead = keccak256(abi.encode(onionHead,keccak256(abi.encode(_transferDatas[i]))));
            
            /* 
                If this is a fork point, make two judgments
                1. Whether the parallel fork points of the fork point are the same, if they are the same, it means that the fork point is invalid, that is, the bond is invalid. And submissions at invalid fork points will not be compensated
                2. Whether the headOnion of the parallel fork point can be calculated by the submission of the bond, if so, the incoming parameters of the bond are considered valid
            */
            if(_mForkDatas[y].forkIndex == i){
                // Determine whether the fork needs to be settled, and also determine whether the fork exists
                checkForkData(_mForkDatas[y-1],_mForkDatas[y],preForkOnionHead,onionHead,i);
                y += 1;
                // !!! Calculate the reward, and reward the bond at the end, the reward fee is the number of forks * margin < margin equal to the wrongtx gaslimit overhead brought by 50 Wrongtx in this method * common gasPrice>
            }

            if (isRespondOnions[onionHead]){
                if (onionsAddress[onionHead] != address(0)){
                    IDestinationContract(routerAddress).transfer(onionsAddress[onionHead],_transferDatas[i].amount + _transferDatas[i].fee);
                }else{
                    IDestinationContract(routerAddress).transfer(_transferDatas[i].destination,_transferDatas[i].amount + _transferDatas[i].fee);
                }
            }else{
                IDestinationContract(routerAddress).transfer(_commiters[i],_transferDatas[i].amount + _transferDatas[i].fee);
            }
            destOnionHead = keccak256(abi.encode(destOnionHead,onionHead,_commiters[i]));
        }
        
        // Assert the replay result, indicating that the fork is legal
        require(onionHead == onWorkHashOnion,"a2");
        // Assert that the replay result is equal to the stored value of the fork, which means that the incoming _transferdatas are valid
        require(destOnionHead == hashOnionForks[_mForkDatas[y].forkKeyNum].destOnionHead,"a4");

        // If the prefork also needs to be settled, push the onWorkHashOnion forward a fork
        if (preWorkFork.needBond){
            onWorkHashOnion = preWorkFork.onionHead;
        }else{ 
            // If no settlement is required, it means that the previous round of settlement is completed, and a new value is set
            onWorkHashOnion = sourceHashOnion;
        }
    }

    function checkForkData (Data.MForkData calldata preForkData, Data.MForkData calldata forkData, bytes32 preForkOnionHead, bytes32 onionHead,uint256 i) internal {
        require(hashOnionForks[forkData.forkKeyNum].needBond == true, "b1");
        if(i != 0 ){
            // Calculate the onionHead of the parallel fork based on the preonion and the tx of the original path
            preForkOnionHead = keccak256(abi.encode(preForkOnionHead, forkData.wrongtxHash[0]));
            // If the parallel Onion is equal to the key of forkOnion, it means that forkOnion is illegal
            require(preForkOnionHead != onionHead,"a2");
            // After passing, continue to calculate AFok
            uint256 x = 1;
            while (x < forkData.wrongtxHash.length) {
                preForkOnionHead = keccak256(abi.encode(preForkOnionHead,forkData.wrongtxHash[x]));
                x++;
            }
            // Judging that the incoming _wrongTxHash is in line with the facts, avoid bond forgery AFork.nextOnion == BFork.nextOnion
            require(preForkOnionHead == hashOnionForks[preForkData.forkKeyNum].onionHead);
        }
        hashOnionForks[forkData.forkKeyNum].needBond = false;
    }
    
    function bondSourceHashOnion(bytes32 _sourceHashOnion) external override onlyRouter{
        if (onWorkHashOnion == "" || onWorkHashOnion == sourceHashOnion) {
            onWorkHashOnion = _sourceHashOnion;
        }
        sourceHashOnion = _sourceHashOnion;
        // Settlement for bond
    }

    function buyOneOnion(bytes32 preHashOnion,Data.TransferData calldata _transferData) external override onlyRouter{
        bytes32 key = keccak256(abi.encode(preHashOnion,keccak256(abi.encode(_transferData))));
        require( isRespondOnions[key], "a1");
        require( onionsAddress[key] == address(0), "a1");

        IDestinationContract(routerAddress).transferFrom(_transferData.destination,_transferData.amount);
        onionsAddress[key] = tx.origin;
    }

    function buyOneFork(uint256 _forkKey, uint256 _forkId) external override onlyRouter{
        // Unfinished hashOnions can be purchased
    }
}   



