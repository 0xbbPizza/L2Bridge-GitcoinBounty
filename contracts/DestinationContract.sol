// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Data.sol";
import "./DestChildContract.sol";
import "./IDestinationContract.sol";
import "./MessageDock/CrossDomainHelper.sol";



contract DestinationContract is IDestinationContract, CrossDomainHelper , Ownable {
    using SafeERC20 for IERC20;

    address tokenAddress;

    mapping(uint256 => address) public chainId_childs;
    mapping(address => uint256) public sourc_chainIds;
    
    mapping(address => bool) private _commiterDeposit;   // Submitter's bond record

    uint256 public ONEFORK_MAX_LENGTH = 5;  // !!! The final value is 50 , the higher the value, the longer the wait time and the less storage consumption
    uint256 DEPOSIT_AMOUNT = 1 * 10**18;  // !!! The final value is 2 * 10**17

    /*
	1. every LP need deposit `DEPOSIT_AMOUNT` ETH, DEPOSIT_AMOUNT = OnebondGaslimit * max_fork.length * Average_gasPrice 
	2. when LP call zfork()、mfork()、claim(). lock deposit, and unlock the preHashOnions LP's deposit. 
	3. When bonder is settling `middle fork`, will get `DEPOSIT_AMOUNT` ETH back from destContract. 
	4. LP's deposit can only be withdrawn if they are unlocked.
	5. No one wants to pay for someone else's mistakes, so the perpetrator's deposit will never be unlocked
    */

    constructor(
        address _tokenAddress,
        address _dockAddr
    )
        CrossDomainHelper(_dockAddr)
    {
        tokenAddress = _tokenAddress;
    }

    function _onlyApprovedSources(address _sourceSender, uint256 _sourChainId) internal view override{
        require(_sourChainId != 0, "ZERO_CHAINID");
        require(sourc_chainIds[_sourceSender] == _sourChainId, "NOTAPPROVE");
    }

    /*
        call from source 
    */
    function bondSourceHashOnion(uint256 chainId, bytes32 hashOnion) external sourceSafe {
        DestChildContract(chainId_childs[chainId]).bondSourceHashOnion(hashOnion);
        // Settlement for bond
    }

    /*
        set
    */
    // TODO change to factory function or change data struct 
    function addDomain(uint256 chainId, address source , address dest) external onlyOwner {
        require(chainId_childs[chainId] == address(0));
        chainId_childs[chainId] = dest;
        // chainId_childs[chainId] = address(new DestChildContract(address(this)));
        sourc_chainIds[source] = chainId;
    }
    
    // TODO need deposit ETH 
    function becomeCommiter() external{
        _commiterDeposit[msg.sender] = true;
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


    // if index % ONEFORK_MAX_LENGTH == 0 
    function zFork(uint256 chainId, uint256 forkKeyNum, address dest, uint256 amount, uint256 fee, bool _isRespond) external override {
        
        DestChildContract child = DestChildContract(chainId_childs[chainId]);

        // Take out the Fork
        Data.HashOnionFork memory workFork = child.getFork(forkKeyNum);
        
        if (_commiterDeposit[msg.sender] == false){
            // If same commiter, don't need deposit
            require(msg.sender == workFork.lastCommiterAddress, "a2");
        }

        // Create a new Fork
        Data.HashOnionFork memory newFork;

        // set newFork
        newFork.onionHead = keccak256(abi.encode(workFork.onionHead,keccak256(abi.encode(dest,amount,fee))));
        // Determine whether there is a fork with newFork.destOnionHead as the key
        require(child.getForkKeyNum(newFork.onionHead, 0) == 0, "c1");

        newFork.destOnionHead = keccak256(abi.encode(workFork.destOnionHead, newFork.onionHead , msg.sender));
        
        // Determine whether the maker only submits or submits and responds
        if(_isRespond){
            IERC20(tokenAddress).safeTransferFrom(msg.sender,dest,amount); 
        }else{
            // !!! Whether to add the identification position of the index
            child.setIsRepondOnion(newFork.onionHead,true);
        }
        
        newFork.allAmount += amount + fee;
        newFork.length = 1;
        newFork.lastCommiterAddress = msg.sender;
        newFork.needBond = true;

        // storage
        child.setFork(newFork.onionHead, 0, newFork);

        // Locks the new committer's bond, unlocks the previous committer's bond state
        if (workFork.lastCommiterAddress != msg.sender){
            _commiterDeposit[workFork.lastCommiterAddress] = true;
            _commiterDeposit[msg.sender] = false;
        }

        emit newClaim(dest,amount,fee,0,newFork.onionHead);
    }
    // just deppend
    function claim(uint256 chainId, uint256 forkKeyNum, uint256 _workIndex, Data.TransferData[] calldata _transferDatas,bool[] calldata _isResponds) external override {
        // incoming data length is correct
        require(_transferDatas.length > 0, "a1");

        DestChildContract child = DestChildContract(chainId_childs[chainId]);

        // positioning fork
        Data.HashOnionFork memory workFork = child.getFork(forkKeyNum);
        
        // Determine whether this fork exists
        require(workFork.length > 0,"fork is null"); //use length

        // Determine the eligibility of the submitter
        if (_commiterDeposit[msg.sender] == false){
            require(msg.sender == workFork.lastCommiterAddress, "a3");
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
                IERC20(tokenAddress).safeTransferFrom(msg.sender, _transferDatas[i].destination, _transferDatas[i].amount); 
            }else{
                // TODO need change to transferData hash
                child.setIsRepondOnion(onionHead,true);
            }
            destOnionHead = keccak256(abi.encode(destOnionHead,onionHead,msg.sender));
            allAmount += _transferDatas[i].amount + _transferDatas[i].fee;

            emit newClaim(_transferDatas[i].destination,_transferDatas[i].amount,_transferDatas[i].fee,_workIndex+i,onionHead); 
        }
        
        // change deposit , deposit token is ETH , need a function to deposit and with draw
        if (workFork.lastCommiterAddress != msg.sender){
            _commiterDeposit[workFork.lastCommiterAddress] = true;
            _commiterDeposit[msg.sender] = false;
        }

        workFork = Data.HashOnionFork({
            onionHead: onionHead, 
            destOnionHead: destOnionHead,
            allAmount: allAmount + workFork.allAmount,
            length: _workIndex + _transferDatas.length,
            lastCommiterAddress: msg.sender,
            needBond: workFork.needBond
        });
        
        // storage
        child.setForkWithForkKey(forkKeyNum,workFork);
    }
    // if source index % ONEFORK_MAX_LENGTH != 0
    function mFork(uint256 chainId, bytes32 _lastOnionHead, bytes32 _lastDestOnionHead, uint8 _index , Data.TransferData calldata _transferData, bool _isRespond) external override {
        
        
        // Determine whether tx.origin is eligible to submit
        require(_commiterDeposit[msg.sender] == true, "a3");
        
        DestChildContract child = DestChildContract(chainId_childs[chainId]);

        // Create a new Fork
        Data.HashOnionFork memory newFork;

        // set newFork
        newFork.onionHead = keccak256(abi.encode(_lastOnionHead,keccak256(abi.encode(_transferData))));
        // Determine whether there is a fork with newFork.destOnionHead as the key
        require(child.getForkKeyNum(newFork.onionHead, _index) == 0, "c1");

        newFork.destOnionHead = keccak256(abi.encode(_lastDestOnionHead, newFork.onionHead , msg.sender));

        // Determine whether the maker only submits or submits and also responds, so as to avoid the large amount of unresponsiveness of the maker and block subsequent commints
        if(_isRespond){
            IERC20(tokenAddress).safeTransferFrom(msg.sender, _transferData.destination, _transferData.amount); 
        }else{
            child.setIsRepondOnion(newFork.onionHead, true);
        }
        
        newFork.allAmount += _transferData.amount + _transferData.fee;
        newFork.length = _index;
        newFork.lastCommiterAddress = msg.sender;

        // storage
        child.setFork(newFork.onionHead, _index, newFork);

        // Freeze Margin
        _commiterDeposit[msg.sender] = false;
    }

    // clearing zfork
    function zbond(uint256 chainId, uint256 forkKeyNum, uint256 _preForkKeyNum, Data.TransferData[] calldata _transferDatas, address[] calldata _commiters) external override {
        // incoming data length is correct
        require(_transferDatas.length > 0, "a1");
        require(_commiters.length == _transferDatas.length, "a2");
        
        DestChildContract child = DestChildContract(chainId_childs[chainId]);

        Data.HashOnionFork memory workFork = child.getFork(forkKeyNum);
        
        // Judging whether this fork exists && Judging that the fork needs to be settled
        require(workFork.needBond, "a3");

        // Determine whether the onion of the fork has been recognized
        require(workFork.onionHead == child.onWorkHashOnion(),"a4"); //use length
        
        Data.HashOnionFork memory preWorkFork = child.getFork(_preForkKeyNum);

        // Determine whether this fork exists
        require(preWorkFork.length > 0,"fork is null"); //use length

        bytes32 onionHead = preWorkFork.onionHead;
        bytes32 destOnionHead = preWorkFork.destOnionHead;
        // repeat
        for (uint256 i; i < _transferDatas.length; i++){
            onionHead = keccak256(abi.encode(onionHead,keccak256(abi.encode(_transferDatas[i]))));
            if (child.getIsRepondOnion(onionHead)){
                address onionAddress = child.onionsAddress(onionHead);
                if (onionAddress != address(0)){
                    IERC20(tokenAddress).safeTransfer(onionAddress, _transferDatas[i].amount + _transferDatas[i].fee); 
                }else{
                    IERC20(tokenAddress).safeTransfer(_transferDatas[i].destination, _transferDatas[i].amount + _transferDatas[i].fee); 
                }
            }else{
                IERC20(tokenAddress).safeTransfer(_commiters[i], _transferDatas[i].amount + _transferDatas[i].fee); 
            }
            destOnionHead = keccak256(abi.encode(destOnionHead,onionHead,_commiters[i]));
        }
        
        // Assert that the replay result is equal to the stored value of the fork, which means that the incoming _transferdatas are valid
        require(destOnionHead == workFork.destOnionHead,"a5");

        // storage workFork
        workFork.needBond = false;
        child.setForkWithForkKey(forkKeyNum,workFork);

        // If the prefork also needs to be settled, push the onWorkHashOnion forward a fork
        child.setOnWorkHashOnion(preWorkFork.onionHead, preWorkFork.needBond);

        // !!! Reward bonder
    }
    // Settlement non-zero fork
    function mbond(uint256 chainId, Data.MForkData[] calldata _mForkDatas, uint256 forkKeyNum, Data.TransferData[] calldata _transferDatas, address[] calldata _commiters) external override {
        require( _mForkDatas.length > 1, "a1");
        
        // incoming data length is correct
        require(_transferDatas.length == ONEFORK_MAX_LENGTH, "a1");
        require(_transferDatas.length == _commiters.length, "a2");

        DestChildContract child = DestChildContract(chainId_childs[chainId]);

        Data.HashOnionFork memory preWorkFork = child.getFork(forkKeyNum);

        // Determine whether this fork exists
        require(preWorkFork.length > 0,"fork is null"); //use length

        
        bytes32 destOnionHead = preWorkFork.destOnionHead;
        bytes32 onionHead = preWorkFork.onionHead;
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
                // TODO
                // checkForkData(_mForkDatas[y-1],_mForkDatas[y],preForkOnionHead,onionHead,i,chainId);
                y += 1;
                // !!! Calculate the reward, and reward the bond at the end, the reward fee is the number of forks * margin < margin equal to the wrongtx gaslimit overhead brought by 50 Wrongtx in this method * common gasPrice>
            }
            if (child.getIsRepondOnion(onionHead)){
                address onionAddress = child.onionsAddress(onionHead);
                if (onionAddress != address(0)){
                    IERC20(tokenAddress).safeTransfer(onionAddress, _transferDatas[i].amount + _transferDatas[i].fee); 
                }else{
                    IERC20(tokenAddress).safeTransfer(_transferDatas[i].destination, _transferDatas[i].amount + _transferDatas[i].fee); 
                }
            }else{
                IERC20(tokenAddress).safeTransfer(_commiters[i], _transferDatas[i].amount + _transferDatas[i].fee); 
            }
            destOnionHead = keccak256(abi.encode(destOnionHead,onionHead,_commiters[i]));
        }

        // Assert the replay result, indicating that the fork is legal
        require(onionHead == child.onWorkHashOnion(),"a2");
        // Assert that the replay result is equal to the stored value of the fork, which means that the incoming _transferdatas are valid

        require(destOnionHead == child.getFork(_mForkDatas[y].forkKeyNum).destOnionHead,"a4");

        // If the prefork also needs to be settled, push the onWorkHashOnion forward a fork
        child.setOnWorkHashOnion(preWorkFork.onionHead, preWorkFork.needBond);

        // !!! Reward bonder
    }

    // function checkForkData (Data.MForkData calldata preForkData, Data.MForkData calldata forkData, bytes32 preForkOnionHead, bytes32 onionHead) internal {

    //     // Calculate the onionHead of the parallel fork based on the preonion and the tx of the original path
    //     preForkOnionHead = keccak256(abi.encode(preForkOnionHead, forkData.wrongtxHash[0]));
    //     // If the parallel Onion is equal to the key of forkOnion, it means that forkOnion is illegal
    //     require(preForkOnionHead != onionHead,"a2");
    //     // After passing, continue to calculate AFok
    //     uint256 x = 1;
    //     while (x < forkData.wrongtxHash.length) {
    //         preForkOnionHead = keccak256(abi.encode(preForkOnionHead,forkData.wrongtxHash[x]));
    //         x++;
    //     }
    // }

    function checkForkData (Data.MForkData calldata preForkData, Data.MForkData calldata forkData, bytes32 preForkOnionHead, bytes32 onionHead,uint256 i,uint256 chainId) internal {
        
        DestChildContract child = DestChildContract(chainId_childs[chainId]);

        require(child.getFork(forkData.forkKeyNum).needBond == true, "b1");
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
            require(preForkOnionHead == child.getFork(preForkData.forkKeyNum).onionHead);
        }

        child.setNeedBond(forkData.forkKeyNum, false);
    }

    // function checkForkData (Data.MForkData calldata preForkData, Data.MForkData calldata forkData, bytes32 preForkOnionHead, bytes32 onionHead,uint256 i,uint256 chainId) internal {
        
    //     DestChildContract child = DestChildContract(chainId_childs[chainId]);

    //     require(child.getFork(forkData.forkKeyNum).needBond == true, "b1");
    //     if(i != 0 ){
    //         // Calculate the onionHead of the parallel fork based on the preonion and the tx of the original path
    //         preForkOnionHead = keccak256(abi.encode(preForkOnionHead, forkData.wrongtxHash[0]));
    //         // If the parallel Onion is equal to the key of forkOnion, it means that forkOnion is illegal
    //         require(preForkOnionHead != onionHead,"a2");
    //         // After passing, continue to calculate AFok
    //         uint256 x = 1;
    //         while (x < forkData.wrongtxHash.length) {
    //             preForkOnionHead = keccak256(abi.encode(preForkOnionHead,forkData.wrongtxHash[x]));
    //             x++;
    //         }
    //         // Judging that the incoming _wrongTxHash is in line with the facts, avoid bond forgery AFork.nextOnion == BFork.nextOnion
    //         require(preForkOnionHead == child.getFork(preForkData.forkKeyNum).onionHead);
    //     }

    //     child.setNeedBond(forkData.forkKeyNum, false);
    // }

    function buyOneOnion(uint256 chainId, bytes32 preHashOnion,Data.TransferData calldata _transferData) external override {
        
        DestChildContract child = DestChildContract(chainId_childs[chainId]);

        bytes32 key = keccak256(abi.encode(preHashOnion,keccak256(abi.encode(_transferData))));
        require( child.getIsRepondOnion(key), "a1");
        address onionAddress = child.onionsAddress(key);
        require( onionAddress == address(0), "a1");
        
        IERC20(tokenAddress).safeTransferFrom(msg.sender, _transferData.destination, _transferData.amount); 

        child.setOnionAddress(key, msg.sender);
    }


    // max deposit block Limit
    // min deposit funds rate 
    // max deposit funds 

    // deposit and 
    function depositWithOneFork (uint256 chainId , uint256 forkKeyNum) external {
        DestChildContract child = DestChildContract(chainId_childs[chainId]);
        // fork is deposit = true
    }
    // block Depostit one fork 
    function blockDepositOneFork (uint256 chainId , uint256 forkKeyNum) external {
        // fork is block = true
    }
    // create bond token
    function creatBondToken (uint256 chainId , uint256 forkKeyNum) external {
        

    }
    function settlement (uint256 chainId , uint256 forkKeyNum) external {
        // if fork.deposit = true and fork.isblock = false and fork.depositValidBlockNum >= nowBlockNum
        // if token.balanceof(this) < forkAmount do creatBondToken count to self
        // if token.balanceof(lpcontract) >= forkAmount send bondToken to lpContract , and claim token to this
        // if token.balanceof(lpcontract) < forkAmount share token is change to bondToken
        // do zfork , send token to user 
        // // if token.balanceof(this) >= forkAmount  do  zfork 
    }

    function loanFromLPPool (uint256 amount) internal {
        // send bondToken to LPPool 
        // LPPool send real token to dest
    }

    // buy bond token 
    function buyOneFork(uint256 chainId, uint256 _forkKey, uint256 _forkId) external override {
        
    } 

}   



