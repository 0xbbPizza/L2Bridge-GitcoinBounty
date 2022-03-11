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
import "../IDock_L1.sol";
import "../IDock_L2.sol";
import "../IRelay.sol";

contract Dock_MainNet is IDock_L1, IDock_L2{
    using Address for address;

    address public immutable relayAddress;

    // Note, these variables are set and then wiped during a single transaction.
    // Therefore their values don't need to be maintained, and their slots will
    // be empty outside of transactions
    uint256 internal sourceChainID;
    address internal sourceSender;

    modifier onlyRelay {
        require(msg.sender == relayAddress);
        _;
    }

    constructor(
        address _relayAddress
    ){
        relayAddress = _relayAddress;
    }
    
    function fromRelay(bytes calldata _data) external override onlyRelay {
        address preSourceSender = sourceSender;
        uint256 preSourceChainID = sourceChainID;
        address destAddress;
        bytes memory destMassage;
        (destAddress,destMassage,sourceSender,sourceChainID) = abi.decode(_data, (address, bytes, address, uint256));
        
        if (destMassage.length > 0) require(destAddress.isContract(), "NO_CODE_AT_DEST");
        (bool success,) = destAddress.call(destMassage);
        require(success, "WRONG_MSG");
            
        sourceSender = preSourceSender;
        sourceChainID = preSourceChainID;
    }

    function callOtherDomainFunction(address _destAddress, uint256 _destChainID, bytes calldata _destMassage) external override {
        bytes memory onions1 = abi.encode(_destAddress, _destMassage, msg.sender, block.chainid);
        IRelay(relayAddress).relayCall(_destChainID, onions1);
    }
    
    function getSourceChainID() external view override returns (uint256){
        return sourceChainID;
    }
    
    function getSourceSender() external view override returns (address){
        return sourceSender;
    }
}