// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "./DestinationContract.sol";
// import "https://github.com/ethereum-optimism/contracts/blob/master/contracts/optimistic-ethereum/iOVM/bridge/messaging/iOVM_L2CrossDomainMessenger.sol"

interface IArb_Outbox {
    function l2ToL1Sender() external view returns (address);
}

interface IArb_bridge{
     function activeOutbox() external view returns (address);
}

contract Relay {
    // using SafeERC20 for IERC20;

    address arbBridge;
    address l2Sender;
    address destAddress;
    bytes32 hashOnion;
    // uint256 txIndex;
    // mapping(address => mapping(uint256 => address)) public bonderList;

    modifier onlyLegalSource(){
        require(msg.sender == arbBridge, "a1");
        IArb_Outbox outbox = IArb_Outbox(IArb_bridge(arbBridge).activeOutbox());
        require(outbox.l2ToL1Sender() == l2Sender, "a2");
        _;
    }

    constructor(address _arbBridge, address _l2Sender){
        arbBridge = _arbBridge;
        l2Sender = _l2Sender;
    }

    // !!! /* onlyLegalSource */
    function getHashOnion(bytes32 _hashOnion) external {
        hashOnion =  _hashOnion;
    }

    function sendHashOnion(address _tokenAddress) public { 
        // uint256 amount = IERC20(_tokenAddress).balanceOf(address(this));
        // IERC20(_tokenAddress).safeTransfer(destAddress,amount);
    }

}