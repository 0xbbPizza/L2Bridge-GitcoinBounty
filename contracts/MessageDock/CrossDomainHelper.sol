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

import "./IDock_L2.sol";

// TODO: splite CrossDomainHelper, to be sourceCrossDomainHelper and destCrossDomainHelper

abstract contract CrossDomainHelper {
    address public immutable dockAddr;
    
    constructor(
        address _dockAddr
    ){
        dockAddr = _dockAddr;
    }

    modifier sourceSafe {
        require(msg.sender == dockAddr, "NOT_DOCK");
        _onlyApprovedSources(IDock_L2(msg.sender).getSourceSender(),IDock_L2(msg.sender).getSourceChainID());
        _;
    }

    function _onlyApprovedSources(address _sourceSender, uint256 _sourChainId) internal view virtual;

    function crossDomainMassage(address _destAddress, uint256 _destChainID, bytes memory _destMassage) internal {
        IDock_L2(dockAddr).callOtherDomainFunction(_destAddress, _destChainID, _destMassage);
    }
}