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


import "../MessageDock/CrossDomainHelper.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Test_source is CrossDomainHelper, Ownable {
    mapping(uint256 => address) public chainId_dests;
    
    constructor(
        address _dockAddr
    )
        CrossDomainHelper(_dockAddr)
    {}

    function sendMessage(uint256 _chainId, string calldata _message) external {
        address destAddress = chainId_dests[_chainId];
        require(destAddress != address(0));
        bytes memory callMessage = abi.encodeWithSignature("getMessage(uint256,string)",_chainId,_message);
        crossDomainMassage(destAddress , _chainId, callMessage);
    }

    function addDestDomain(uint256 _chainId, address _source) external onlyOwner {
        require(chainId_dests[_chainId] == address(0));
        chainId_dests[_chainId] = _source;
    }

    function _onlyApprovedSources(address _sourceSender, uint256 _sourChainId) internal view override{}
}