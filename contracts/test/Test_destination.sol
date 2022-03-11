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

contract Test_destination is CrossDomainHelper, Ownable {
    uint256 public chainId;
    string public message;

    mapping(address => uint256) public sourc_chainIds;

    constructor(
        address _dockAddr
    )
        CrossDomainHelper(_dockAddr)
    {}

    function addDomain(uint256 _chainId, address _source) external onlyOwner {
        require(sourc_chainIds[_source] == 0);
        sourc_chainIds[_source] = _chainId;
    }

    function getMessage(uint256 _chainId, string calldata _message) external sourceSafe {
        chainId = _chainId;
        message = _message;
    }

    function _onlyApprovedSources(address _sourceSender, uint256 _sourChainId) internal override view {
        require(_sourChainId != 0, "ZERO_CHAINID");
        require(sourc_chainIds[_sourceSender] == _sourChainId, "NOTAPPROVE");
    }
}