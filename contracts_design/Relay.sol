// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./DestinationContract.sol";

contract Relay {
    using SafeERC20 for IERC20;

    address sourceAddress;
    address destAddress;
    bytes32 hashOnion;
    uint256 txIndex;
    mapping(address => mapping(uint256 => address)) public bonderList;

     modifier onlyLegalContract(){
        require(msg.sender == sourceAddress, "Not Allowed");
        _;
    }

    function getHashOnion(uint256 _txIndex,bytes32 _hashOnion, address _tokenAddress, address _bonder) external  onlyLegalContract{
        hashOnion = _hashOnion;
        bonderList[_tokenAddress][_txIndex]=_bonder;
        txIndex = _txIndex;
    }

    function sendHashOnion(address _tokenAddress) public { 
        uint256 amount = IERC20(_tokenAddress).balanceOf(address(this));
        IERC20(_tokenAddress).safeTransfer(destAddress,amount);

        // IDestinationContract(destAddress).getHashOnion(bonderList[_tokenAddress],hashOnion,hashOnion);
    }

}