// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Data.sol";
import "./Relay.sol";

interface ISourceContract{
    event newTransfer(Data.TransferData transferData, uint256 txindex, bytes32 hashOnion);
    event extract(uint256 txIndex,uint256 amount,bytes32 hashOnion);

    function transfer(Data.TransferData memory transferData) external payable;
    function extractHashOnionAndBalance() external payable;
}


contract SourceContract is ISourceContract{
    using SafeERC20 for IERC20;

    uint256 txIndex;
    // relay need data
    address tokenAddress;
    address relayAddress;
    
    uint8 BASE_BIND_FEE = 100;

    bytes32 hashOnion;
    
    function transfer(Data.TransferData memory transferData) external payable override {
        uint256 allAmount = transferData.amount + transferData.fee + BASE_BIND_FEE;
        IERC20(tokenAddress).safeTransferFrom(msg.sender,address(this),allAmount);
        
        hashOnion = keccak256(abi.encode(transferData),hashOnion);
        txIndex += 1;

        emit newTransfer(transferData,txIndex,hashOnion);
    }

    function extractHashOnionAndBalance() external payable{
        uint256 amount = IERC20(tokenAddress).balanceOf(address(this));
        IERC20(tokenAddress).safeTransfer(relayAddress,amount);

        Relay(relayAddress).getHashOnion(txIndex,hashOnion,tokenAddress,msg.sender);

        emit extract(txIndex,amount,hashOnion);
    }

}