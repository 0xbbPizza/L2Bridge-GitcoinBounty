// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Data.sol";

interface IDestinationContract{
    
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

    event newClaim(Data.TransferData transferData, uint256 txindex, bytes32 hashOnion);
    event newBond(uint256 txIndex,uint256 amount,bytes32 hashOnion);

    function claim(bytes32 _forkKey,uint256 _forkIndex, uint256 _workIndex, Data.TransferData[] calldata _transferDatas,bool[] calldata _isResponds) external;
    function zbond(bytes32 _forkKey,bytes32 _preForkKey, uint256 _preForkIndex, Data.TransferData[] calldata _transferDatas, address[] calldata _commiters) external;
    
    function mbond(
        MForkData[] calldata _mForkDatas,
        bytes32 _preForkKey, uint256 _preForkIndex, 
        Data.TransferData[] calldata _transferDatas, address[] calldata _commiters
        ) external; 

    // function getHashOnion(address[] calldata _bonderList,bytes32 _sourceHashOnion, bytes32 _bonderListHash) external;
}

contract DestinationContract is IDestinationContract{
    using SafeERC20 for IERC20;

    mapping(address => bool) commiterDeposit;   // Submitter's bond record
    mapping(bytes32 => mapping(uint256 => HashOnionFork)) hashOnionForks; // Submitter's bond record

    mapping(bytes32 => bool) isRespondOnions;   // Whether it is a Onion that is not responded to
    mapping(bytes32 => address) onionsAddress;  // !!! Conflict with using zk scheme, new scheme needs to be considered when using zk

    bytes32 sourceHashOnion;   // Used to store the sent hash
    bytes32 onWorkHashOnion;   // Used to store settlement hash

    address tokenAddress;

    address trustAddress;

    uint256 ONEFORK_MAX_LENGTH = 5;  // !!! The final value is 50 , the higher the value, the longer the wait time and the less storage consumption
    uint256 DEPOSIT_AMOUNT = 1 * 10**18;  // !!! The final value is 2 * 10**17

    constructor(address _tokenAddress, address _trustAddress){
        tokenAddress = _tokenAddress;
        trustAddress = _trustAddress;
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
    function zFork(bytes32 _forkKey, uint8 _index, Data.TransferData calldata _transferData, bool _isRespond) external{
        // Determine whether msg.sender is eligible to submit
        require(commiterDeposit[msg.sender] == true, "a3");

        // Take out the Fork
        HashOnionFork storage workFork = hashOnionForks[_forkKey][_index];
        
        // Determine if the previous fork is full
        // !!! use length use length is missing to consider that the last fork is from forkFromInput, you need to modify the usage of length to index
        require(workFork.length == ONEFORK_MAX_LENGTH,"fork is null"); 

        // !!! Deposit is only required for additional, and a new fork does not require deposit, but how to ensure that the correct sourceOnionHead is occupied by the next submitter, but the wrong destOnionHead is submitted
        // Determine the eligibility of the submitter
        if (commiterDeposit[msg.sender] == false){
            // If same commiter, don't need deposit
            require(msg.sender == workFork.lastCommiterAddress, "a3");
        }

        // Create a new Fork
        HashOnionFork memory newFork;

        // set newFork
        newFork.onionHead = keccak256(abi.encode(workFork.onionHead,keccak256(abi.encode(_transferData))));
        // Determine whether there is a fork with newFork.destOnionHead as the key
        require(hashOnionForks[newFork.onionHead][0].length == 0, "c1");

        newFork.destOnionHead = keccak256(abi.encode(workFork.destOnionHead, newFork.onionHead , msg.sender));
        
        // Determine whether the maker only submits or submits and responds
        if(_isRespond){
            IERC20(tokenAddress).safeTransferFrom(msg.sender,_transferData.destination,_transferData.amount);
        }else{
            // !!! Whether to add the identification position of the index
            isRespondOnions[newFork.onionHead] = true; 
        }
        
        newFork.allAmount += _transferData.amount + _transferData.fee;
        newFork.length = 1;
        newFork.lastCommiterAddress = msg.sender;

        // storage
        hashOnionForks[newFork.onionHead][0] = newFork;

        // Locks the new committer's bond, unlocks the previous committer's bond state
        if (workFork.lastCommiterAddress != msg.sender){
            (commiterDeposit[workFork.lastCommiterAddress], commiterDeposit[msg.sender]) = (commiterDeposit[msg.sender], commiterDeposit[workFork.lastCommiterAddress]);
        }
    }

    // if fork index % ONEFORK_MAX_LENGTH != 0
    function mFork(bytes32 _lastOnionHead, bytes32 _lastDestOnionHead, uint8 _index , Data.TransferData calldata _transferData, bool _isRespond) external{
        // Determine whether msg.sender is eligible to submit
        require(commiterDeposit[msg.sender] == true, "a3");

        // Create a new Fork
        HashOnionFork memory newFork;

        // set newFork
        newFork.onionHead = keccak256(abi.encode(_lastOnionHead,keccak256(abi.encode(_transferData))));
        // Determine whether there is a fork with newFork.destOnionHead as the key
        require(hashOnionForks[newFork.onionHead][_index].length == 0, "c1");

        newFork.destOnionHead = keccak256(abi.encode(_lastDestOnionHead, newFork.onionHead , msg.sender));

        // Determine whether the maker only submits or submits and also responds, so as to avoid the large amount of unresponsiveness of the maker and block subsequent commints
        if(_isRespond){
            IERC20(tokenAddress).safeTransferFrom(msg.sender,_transferData.destination,_transferData.amount);
        }else{
            isRespondOnions[newFork.onionHead] = true;
        }
        
        newFork.allAmount += _transferData.amount + _transferData.fee;
        newFork.length = _index;
        newFork.lastCommiterAddress = msg.sender;

        // storage
        hashOnionForks[newFork.onionHead][_index] = newFork;

        // Freeze Margin
        commiterDeposit[msg.sender] = false;
    }

    /* 
        !!! fork from input， Because there is a deposit, I am not afraid of witch attack. Do I need to design a mechanism that the deposit cannot be retrieved?
        Can the deposit mechanism be made more concise?
    */

    // !!! depend  should be split and _forkKey should use destOnionHead
    function claim(bytes32 _forkKey, uint256 _forkIndex, uint256 _workIndex, Data.TransferData[] calldata _transferDatas,bool[] calldata _isResponds) external override{
        
        // incoming data length is correct
        require(_transferDatas.length > 0, "a1");

        // positioning fork
        HashOnionFork memory workFork = hashOnionForks[_forkKey][_forkIndex];
        
        // Determine whether this fork exists
        require(workFork.length > 0,"fork is null"); //use length

        // Determine the eligibility of the submitter
        if (commiterDeposit[msg.sender] == false){
            require(msg.sender == workFork.lastCommiterAddress, "a3");
        }
        
        // Determine whether someone has submitted it before. If it has been submitted by the predecessor, msg.sender thinks that the submission is incorrect and can be forked and resubmitted through forkFromInput
        // !!! Avoid duplicate submissions
        require(_workIndex == workFork.length, "b1");
        
        // Judge _transferDatas not to exceed the limit
        require(_workIndex + _transferDatas.length <= ONEFORK_MAX_LENGTH, "a2");
        
        bytes32 onionHead = workFork.onionHead;
        bytes32 destOnionHead = workFork.destOnionHead;
        uint256 allAmount = 0;
        // just append
        for (uint256 i; i < _transferDatas.length; i++){
            onionHead = keccak256(abi.encode(onionHead,keccak256(abi.encode(_transferDatas[i]))));
            if(_isResponds[i]){
                IERC20(tokenAddress).safeTransferFrom(msg.sender,_transferDatas[i].destination,_transferDatas[i].amount);
            }else{
                isRespondOnions[onionHead] = true;
            }
            destOnionHead = keccak256(abi.encode(destOnionHead,onionHead,msg.sender));
            allAmount += _transferDatas[i].amount + _transferDatas[i].fee;
        }

        // change deposit , deposit token is ETH , need a function to deposit and with draw
        if (workFork.lastCommiterAddress != msg.sender){
            (commiterDeposit[workFork.lastCommiterAddress], commiterDeposit[msg.sender]) = (commiterDeposit[msg.sender], commiterDeposit[workFork.lastCommiterAddress]);
        }

        workFork = HashOnionFork({
            onionHead: onionHead, 
            destOnionHead: destOnionHead,
            allAmount: allAmount + workFork.allAmount,
            length: _workIndex + _transferDatas.length,
            lastCommiterAddress: msg.sender,
            needBond: workFork.needBond
        });
    
    }

    // clearing zfork
    // !!! how to clearing the first zfork that have no preFork
    function zbond(
        bytes32 _forkKey,
        bytes32 _preForkKey, uint256 _preForkIndex, 
        Data.TransferData[] calldata _transferDatas, address[] calldata _commiters
        ) external override{

        // incoming data length is correct
        require(_transferDatas.length > 0, "a1");
        require(_commiters.length == _transferDatas.length, "a2");

        HashOnionFork memory workFork = hashOnionForks[_forkKey][0];
        
        // Judging whether this fork exists && Judging that the fork needs to be settled
        require(workFork.needBond ,"a4"); 
        workFork.needBond = false;

        // Determine whether the onion of the fork has been recognized
        require(workFork.onionHead == onWorkHashOnion,"a2"); //use length

        HashOnionFork memory preWorkFork = hashOnionForks[_preForkKey][_preForkIndex];
        // Determine whether this fork exists
        require(preWorkFork.length > 0,"fork is null"); //use length

        bytes32 onionHead = preWorkFork.onionHead;
        bytes32 destOnionHead = preWorkFork.destOnionHead;
        // repeat
        for (uint256 i; i < _transferDatas.length; i++){
            onionHead = keccak256(abi.encode(onionHead,keccak256(abi.encode(_transferDatas[i]))));
            if (isRespondOnions[onionHead]){
                if (onionsAddress[onionHead] != address(0)){
                    IERC20(tokenAddress).safeTransfer(onionsAddress[onionHead],_transferDatas[i].amount + _transferDatas[i].fee);
                }else{
                    IERC20(tokenAddress).safeTransfer(_transferDatas[i].destination,_transferDatas[i].amount + _transferDatas[i].fee);
                }
            }else{
                IERC20(tokenAddress).safeTransfer(_commiters[i],_transferDatas[i].amount + _transferDatas[i].fee);
            }
            destOnionHead = keccak256(abi.encode(destOnionHead,onionHead,_commiters[i]));
        }
        
        // Assert that the replay result is equal to the stored value of the fork, which means that the incoming _transferdatas are valid
        require(destOnionHead == workFork.destOnionHead,"a4");

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
        MForkData[] calldata _mForkDatas,
        bytes32 _preForkKey, uint256 _preForkIndex, 
        Data.TransferData[] calldata _transferDatas, address[] calldata _commiters
        ) external override{
        
        require( _mForkDatas.length > 1, "a1");
        
        // incoming data length is correct
        require(_transferDatas.length == ONEFORK_MAX_LENGTH, "a1");
        require(_transferDatas.length == _commiters.length, "a2");

        HashOnionFork memory preWorkFork = hashOnionForks[_preForkKey][_preForkIndex];
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
                    IERC20(tokenAddress).safeTransfer(onionsAddress[onionHead],_transferDatas[i].amount + _transferDatas[i].fee);
                }else{
                    IERC20(tokenAddress).safeTransfer(_transferDatas[i].destination,_transferDatas[i].amount + _transferDatas[i].fee);
                }
            }else{
                IERC20(tokenAddress).safeTransfer(_commiters[i],_transferDatas[i].amount + _transferDatas[i].fee);
            }
            destOnionHead = keccak256(abi.encode(destOnionHead,onionHead,_commiters[i]));
        }
        
        // Assert the replay result, indicating that the fork is legal
        require(onionHead == onWorkHashOnion,"a2");
        // Assert that the replay result is equal to the stored value of the fork, which means that the incoming _transferdatas are valid
        require(destOnionHead == hashOnionForks[_mForkDatas[y].forkKey][_mForkDatas[y].forkIndex].destOnionHead,"a4");

        // If the prefork also needs to be settled, push the onWorkHashOnion forward a fork
        if (preWorkFork.needBond){
            onWorkHashOnion = preWorkFork.onionHead;
        }else{ 
            // If no settlement is required, it means that the previous round of settlement is completed, and a new value is set
            onWorkHashOnion = sourceHashOnion;
        }
    }

    function checkForkData (MForkData calldata preForkData, MForkData calldata forkData, bytes32 preForkOnionHead, bytes32 onionHead,uint256 i) internal {
        require(hashOnionForks[forkData.forkKey][forkData.forkIndex].needBond == true, "b1");
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
            require(preForkOnionHead == hashOnionForks[preForkData.forkKey][preForkData.forkIndex].onionHead);
        }
        hashOnionForks[forkData.forkKey][forkData.forkIndex].needBond = false;
    }
    
    // !!!
    // function getHashOnion(address[] calldata _bonderList,bytes32 _sourceHashOnion, bytes32 _bonderListHash) external override{
    //     // judging only trust a target source

    //     // save sourceHashOnion
    //     sourceHashOnion = _sourceHashOnion;

    //     // Settlement for bond
    // }

    function buyOneFork(uint256 _forkKey, uint256 _forkId) external{
        // Unfinished hashOnions can be purchased
    }

    function buyOneOnion(bytes32 preHashOnion,Data.TransferData calldata _transferData) external{
        bytes32 key = keccak256(abi.encode(preHashOnion,keccak256(abi.encode(_transferData))));
        require( isRespondOnions[key], "a1");
        require( onionsAddress[key] == address(0), "a1");

        IERC20(tokenAddress).safeTransferFrom(msg.sender,_transferData.destination,_transferData.amount);
        onionsAddress[key] = msg.sender;
    }
}   



