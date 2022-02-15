// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Data.sol";


interface ISourceContract{
    event newTransfer(uint256 txindex, bytes32 hashOnion);
    event extract(uint256 txIndex,uint256 amount,bytes32 hashOnion);

    function transfer(uint256 amount, uint256 fee) external payable;
    function extractHashOnionAndBalance() external payable;
}


contract SourceContract is ISourceContract{
    using SafeERC20 for IERC20;

    uint256 txIndex;
    // relay need data
    address tokenAddress;
    address relayAddress;
    
    // !!! A base fee also needs to be set up for early billing
    uint8 BASE_BIND_FEE = 100;

    uint8 ONEFORK_MAX_LENGTH = 5;

    bytes32 hashOnion;
    // In order to adapt to dest's handling Onion
    bytes32 bringHashOnion; 
    // !!! do it later , if somebody dont want pay fee , will wait 7 day's withdraw time
    bytes32 noFeeHashOnion; // don't need fast
    // !!! The data structure also needs to consider multi-layer2 scenarios，multi destination domain

    constructor(address _relayAddress, address _tokenAddress){
        Data.TransferData memory zeroTransferData = Data.TransferData({
            destination: address(0),
            amount: 0,
            fee: 0
        });
        hashOnion = keccak256(abi.encode(zeroTransferData));
        relayAddress = _relayAddress;
        tokenAddress = _tokenAddress;
    }

    function transfer(uint256 amount, uint256 fee) external payable override{
        uint256 allAmount = amount + fee + BASE_BIND_FEE;
        IERC20(tokenAddress).safeTransferFrom(msg.sender,address(this),allAmount);
        
        Data.TransferData memory transferData = Data.TransferData({
            destination: msg.sender,
            amount: amount,
            fee: fee
        });

        hashOnion = keccak256(abi.encode(hashOnion,keccak256(abi.encode(transferData))));
        txIndex += 1;
        
        // !!! Create a portable hashOnion, taking into account the fee reward for the bonder
        if(txIndex % ONEFORK_MAX_LENGTH == 0) {
            bringHashOnion = hashOnion;
        }
        // !!! can delete event function , but less gas , more offchain work
        emit newTransfer(txIndex,hashOnion); 
    }

    function transferWithDest(Data.TransferData memory transferData) external payable {
        uint256 allAmount = transferData.amount + transferData.fee + BASE_BIND_FEE;
        IERC20(tokenAddress).safeTransferFrom(msg.sender,address(this),allAmount);
        
        hashOnion = keccak256(abi.encode(hashOnion,keccak256(abi.encode(transferData))));
        txIndex += 1;
        
        // !!! Create a portable hashOnion, taking into account the fee reward for the bonder
        if(txIndex % ONEFORK_MAX_LENGTH == 0) {
            bringHashOnion = hashOnion;
        }
        // !!! can delete event function , but less gas , more offchain work
        emit newTransfer(txIndex,hashOnion); 
    }

    function extractHashOnionAndBalance() external payable override{
    //     // !!! Determine whether the index at the moment is greater than the last withdrawal index, and determine whether the index is at zero
    //     // !!! Make a settlement for the bond
    //     // !!! Send onion to Relay, each step will be settled to bonder
    //     uint256 amount = IERC20(tokenAddress).balanceOf(address(this));
    //     IERC20(tokenAddress).safeTransfer(relayAddress,amount);

    //     Relay(relayAddress).getHashOnion(txIndex,hashOnion,tokenAddress,msg.sender);

    //     emit extract(txIndex,amount,hashOnion);
    }
}