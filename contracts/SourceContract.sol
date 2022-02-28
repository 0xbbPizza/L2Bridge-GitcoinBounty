// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ISourceContract{
    
    struct DomainStruct{
        uint256 txIndex;
        bytes32 hashOnion;
        bytes32 bringHashOnion;   // In order to adapt to dest's handling Onion
        address destAddress;
    }

    event newTransfer(uint256 indexed txindex, bytes32 hashOnion, address dest, uint256 amount, uint256 fee, uint256 indexed chainId);
    event extract(uint256 txIndex,uint256 amount,bytes32 hashOnion);

    function transfer(uint256 chainId,uint256 amount, uint256 fee) external payable;
    function extractHashOnion() external;
}


contract SourceContract is ISourceContract, Ownable{
    using SafeERC20 for IERC20;

    // relay need data
    address public tokenAddress;
    
    // record transaction
    mapping(uint256 => DomainStruct) public chainId_Onions; 
    
    // TODO For the convenience of demonstration.
    // in the real case it is 50~100, a relatively low number is used.
    uint8 public ONEFORK_MAX_LENGTH = 5;
    
    // A base fee also needs to be set up for early billing
    // TODO realy is x = The gas cost of a bond * 1.2 / ONEFORK_MAX_LENGTH
    uint8 BASE_BIND_FEE = 0;  

    constructor(address _tokenAddress){
        tokenAddress = _tokenAddress;
    }

    function addDestDomain(uint256 chainId, address destContract) external onlyOwner {
        require(chainId_Onions[chainId].destAddress == address(0));
        
        chainId_Onions[chainId] = DomainStruct(
            0,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            destContract
        );
    }

    function transfer(uint256 chainId, uint256 amount, uint256 fee) external payable override{
        require(chainId_Onions[chainId].destAddress != address(0));

        uint256 allAmount = amount + fee + BASE_BIND_FEE;
        IERC20(tokenAddress).safeTransferFrom(msg.sender,address(this),allAmount);

        chainId_Onions[chainId].hashOnion = keccak256(abi.encode(chainId_Onions[chainId].hashOnion,keccak256(abi.encode(msg.sender,amount,fee))));
        chainId_Onions[chainId].txIndex += 1;
        
        if(chainId_Onions[chainId].txIndex % ONEFORK_MAX_LENGTH == 0) {
            chainId_Onions[chainId].bringHashOnion = chainId_Onions[chainId].hashOnion;
        }
        
        emit newTransfer(chainId_Onions[chainId].txIndex,chainId_Onions[chainId].hashOnion,msg.sender,amount,fee,chainId); 
    }

    function transferWithDest(uint256 chainId, address dest, uint256 amount, uint256 fee) external payable {
        require(chainId_Onions[chainId].destAddress != address(0));

        uint256 allAmount = amount + fee + BASE_BIND_FEE;
        IERC20(tokenAddress).safeTransferFrom(msg.sender,address(this),allAmount);
        chainId_Onions[chainId].hashOnion = keccak256(abi.encode(chainId_Onions[chainId].hashOnion,keccak256(abi.encode(dest,amount,fee))));
        chainId_Onions[chainId].txIndex += 1;
        
        if(chainId_Onions[chainId].txIndex % ONEFORK_MAX_LENGTH == 0) {
            chainId_Onions[chainId].bringHashOnion = chainId_Onions[chainId].hashOnion;
        }
        
        emit newTransfer(chainId_Onions[chainId].txIndex,chainId_Onions[chainId].hashOnion,dest,amount,fee,chainId); 
    }

    function extractHashOnion() external override {
        // !!! Create a portable chainId_Onions[chainId].hashOnion, taking into account the fee reward for the bonder
        // emit extract(chainId_Onions[chainId].txIndex,amount,chainId_Onions[chainId].hashOnion);
    }
}


