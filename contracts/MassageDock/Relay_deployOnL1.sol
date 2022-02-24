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

import "@openzeppelin/contracts/access/Ownable.sol";

interface IDock_L1{
    function fromRelay(bytes calldata data) external;
}

interface IRelay{
    function relayCall(uint256 destChainID,bytes calldata data) external returns (bool success);
    function docksAddressKey(address dock) external view returns (uint256);
    function docksChainIdKey(uint256 chainId) external view returns (uint256);

    event addedDock(uint256 indexed chainId, address dock);
}

contract Relay is IRelay, Ownable{

    mapping(uint256 => address) private docksMap_addressKey;
    mapping(address => uint256) private docksMap_chainIdKey;
    
    address[] public allowedDockList;
    
    function docksAddressKey(address dock) external view override returns (uint256) {
        return docksMap_addressKey[dock];
    }
    
    function docksChainIdKey(uint256 chainId) external view override returns (uint256) {
        return docksMap_chainIdKey[chainId];
    }
      
    function addDock(address dock, uint256 chainId) external onlyOwner {
        docksMap_addressKey[dock] = chainId;
        docksMap_chainIdKey[chainId] = dock;
        emit addedDock(chainId, dock);
    }

    /*
        // RELAY
        // in   checkSenderIsTrustDock

        // out  
        (destChainID,onion1) {
            destDockAddress_onL1 = docks[inputData.destChainID]
            destDockAddress_onL1.fromRelay(onion1)
    */
    function relayCall(
        uint256 destChainID,
        bytes calldata data
    ) external override returns (bool success) {
        require(docksMap_addressKey[msg.sender] > 0, "NOT_FROM_Dock");
        address destDock = docksMap_chainIdKey[destChainID];
        require(destDock != address(0));
        IDock_L1(destDock).fromRelay(data);
        success = true;
    }
}



