// SPDX-License-Identifier: Apache-2.0

/*
 * Copyright 2019-2021, Offchain Labs, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


 pragma solidity 0.8.4;

 import "@openzeppelin/contracts/utils/Address.sol";

interface IDock_L1{
    function callOtherDomainFuntion(address _destAddress, uint256 _destChainID, bytes calldata _destMassage) external;
    function getSourceChainID() external view returns (uint256);
    function getSourceSender() external view returns (address);
}

abstract contract Dock_L2 is IDock_L1{
    using Address for address;

     struct SourceContext {
        uint256 sourceChainID;
        address sender;
    }

     address public immutable l1PairAddress;
     address public immutable bridgeAddress;

    // Note, these variables are set and then wiped during a single transaction.
    // Therefore their values don't need to be maintained, and their slots will
    // be empty outside of transactions
    uint256 internal sourceChainID;
    address internal sourceSender;

    constructor(
        address _l1PairAddress,
        address _bridgeAddress
    ){
        l1PairAddress = _l1PairAddress;
        bridgeAddress = _bridgeAddress;
    }

    function getSourceChainID() external view override returns (uint256) {
        return sourceChainID;
    }
    function getSourceSender() external view override returns (address) {
        return sourceSender;
    }

    // fromDomain
    function callOtherDomainFuntion(address _destAddress, uint256 _destChainID, bytes calldata _destMassage) external {
        bytes memory onions1 = abi.encode(_destAddress, _destMassage, msg.sender, block.chainid);
        bytes memory onions2 = abi.encodeWithSignature("fromL2Pair(uint256,bytes)",_destChainID,onions1);
        sendToBridge(onions2);
    }

    // muti : call bridge
    function sendToBridge(bytes memory _data) internal {
        
    }

    // fromBridge 
    function fromL1Pair(bytes calldata _data) external checkSenderIsBridgeAndL1Pair{
        address preSourceSender = sourceSender;
        uint256 preSourceChainID = sourceChainID;
        address destAddress;
        bytes memory destMassage;
        (destAddress,destMassage,sourceSender,sourceChainID) = abi.decode(_data, (address, bytes, address, uint256));
        
        if (destMassage.length > 0) require(destAddress.isContract(), "NO_CODE_AT_DEST");
        destAddress.call(destMassage);

        sourceSender = preSourceSender;
        sourceChainID = preSourceChainID;
    }

    // muti : FromBridge
    modifier checkSenderIsBridgeAndL1Pair {

        _;
    }
}

abstract contract CrossDomainHelper {
    address public immutable dockAddr;
    
    constructor(
        address _dockAddr
    ){
        dockAddr = _dockAddr;
    }

    modifier checkSenderIsBridgeAndL1Pair {
        require(msg.sender == dockAddr, "NOT_DOCK");
        uint256 sourceChainID_DOCK = IDock_L1(msg.sender).getSourceChainID();
        address sourceSender_DOCK = IDock_L1(msg.sender).getSourceSender();
        _;
    }

    function crossDomainMassage(address _destAddress, uint256 _destChainID, bytes calldata _destMassage) internal {
        IDock_L1(dockAddr).callOtherDomainFuntion(_destAddress, _destChainID, _destMassage);
    }
}


/*
// DockL2
// fromDomain same    
(destAddress,destMassage,destChainID) {
     onion1 = (destAddress,destMassage,sourceAddress,sourceChainID), 
     onion2 = (dockPairOnL1_address,dockPairOnL1_Function,destChainID,onion1)}
     
// out bridge         call.bridge.sendtx(onion2)


// from bridge  checkSenderIsBridgeAndPair 
// toDomain same
(destAddress,destMassage,sourceAddress,sourceChainID){
    context = {sourceAddress,sourceChainID}
    destAddress.call(destMassage)
    context = nil
}
*/
