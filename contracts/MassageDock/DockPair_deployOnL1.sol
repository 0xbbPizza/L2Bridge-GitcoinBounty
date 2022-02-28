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

interface IDock_L1{
    function fromRelay(bytes calldata data) external;
}

interface IRelay{
    function relayCall(uint256 destChainID,bytes calldata data) external;

    event addedDock(uint256 indexed chainId, address dock);
}

abstract contract Dock_L1 is IDock_L1{
    address public immutable l2CallInAddress;
    address public immutable l2OutAddress;
    address public immutable relayAddress;

    constructor(
        address _l2CallInAddress,
        address _l2OutAddress,
        address _relayAddress
    ){
        l2CallInAddress = _l2CallInAddress;
        l2OutAddress = _l2OutAddress;
        relayAddress = _relayAddress;
    }

    function fromL2Pair(
        uint256 destChainID, 
        bytes calldata data
    ) external checkSenderIsBridgeAndL2Pair{
        IRelay(relayAddress).relayCall(destChainID, data);
    }

    function fromRelay(bytes calldata _data) external override onlyRelay{
        bytes memory newData = abi.encodeWithSignature("fromL1Pair(bytes)", _data);
        _callBridge(newData);
    }

    // muti to bridge 
    function _callBridge(bytes memory _data) internal {

    }

    // muti  From bridge
    modifier checkSenderIsBridgeAndL2Pair {

        _;
    }
    
    modifier onlyRelay {
        require(msg.sender == relayAddress);
        _;
    }
    
}


/*
// From bridge 
// to ralay same

// From ralay same
// to bridge


// DockL1
// From bridge  checkSenderIsBridgeAndPair 
// to ralay same   relay.in(destChainID,onion1)

// From ralay same 
checkIsComeFromRELAY
Onion3 = (dockPairL2Address,dockPairL2_function,onion1)

// to bridge 
bridge.function(Onion3)
*/

