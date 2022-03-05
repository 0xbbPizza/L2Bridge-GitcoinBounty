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

import "../Dock_L1.sol";

interface iOVM_BaseCrossDomainMessenger {
    /**********************
    * Contract Variables *
    **********************/
    function xDomainMessageSender() external view returns (address);
    
    /**
     * Sends a cross domain message to the target messenger.
     * @param _target Target contract address.
     * @param _message Message to send to the target.
     * @param _gasLimit Gas limit for the provided message.
     */
    function sendMessage(
        address _target,
        bytes calldata _message,
        uint32 _gasLimit
    ) external;
}

contract DockL1_OP is Dock_L1 {
    uint256 public immutable defaultGasLimit;

    constructor(
        address _l2CallInAddress,
        address _l2OutAddress,
        address _relayAddress, 
        uint256 _defaultGasLimit
    )
        Dock_L1(_l2CallInAddress,_l2OutAddress,_relayAddress)
    {
        defaultGasLimit = _defaultGasLimit;
    }

    function _callBridge(bytes memory _data) internal override {
        iOVM_BaseCrossDomainMessenger(l2OutAddress).sendMessage(
            l2CallInAddress,
            _data,
            uint32(defaultGasLimit)
        );
    }

    // From bridge
    function _verifySenderAndDockPair () internal view override {
        require(msg.sender == l2OutAddress, "DOCK1");
        require(iOVM_BaseCrossDomainMessenger(l2OutAddress).xDomainMessageSender() == l2CallInAddress,"DOCK2");
    }

}