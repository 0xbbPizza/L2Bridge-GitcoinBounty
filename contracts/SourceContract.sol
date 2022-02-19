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
    address public tokenAddress;
    address public relayAddress;
    
    // !!! A base fee also needs to be set up for early billing
    uint8 BASE_BIND_FEE = 0;  // realy is x

    uint8 public ONEFORK_MAX_LENGTH = 5;

    bytes32 public hashOnion;
    // In order to adapt to dest's handling Onion
    bytes32 bringHashOnion; 
    // !!! do it later , if somebody dont want pay fee , will wait 7 day's withdraw time
    bytes32 noFeeHashOnion; // don't need fast
    // !!! The data structure also needs to consider multi-layer2 scenarios，multi destination domain

    constructor(address _relayAddress, address _tokenAddress){
        hashOnion = 0x0000000000000000000000000000000000000000000000000000000000000000;
        relayAddress = _relayAddress;
        tokenAddress = _tokenAddress;
    }

    function transfer(uint256 amount, uint256 fee) external payable override{
        uint256 allAmount = amount + fee + BASE_BIND_FEE;
        IERC20(tokenAddress).safeTransferFrom(msg.sender,address(this),allAmount);

        hashOnion = keccak256(abi.encode(hashOnion,keccak256(abi.encode(msg.sender,amount,fee))));
        txIndex += 1;
        
        // !!! Create a portable hashOnion, taking into account the fee reward for the bonder
        if(txIndex % ONEFORK_MAX_LENGTH == 0) {
            bringHashOnion = hashOnion;
        }
        // !!! can delete event function , but less gas , more offchain work
        emit newTransfer(txIndex,hashOnion); 
    }

    function transferWithDest(address dest, uint256 amount, uint256 fee) external payable {
        uint256 allAmount = amount + fee + BASE_BIND_FEE;
        IERC20(tokenAddress).safeTransferFrom(msg.sender,address(this),allAmount);
        hashOnion = keccak256(abi.encode(hashOnion,keccak256(abi.encode(dest,amount,fee))));
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