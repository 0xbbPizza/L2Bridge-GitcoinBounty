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

import "../Dock_L2.sol";

interface IArbSys {
    function sendTxToL1(address destAddr, bytes calldata calldataForL1)
        external
        payable;
}

contract DockL2_Arb is Dock_L2 {
    constructor(address _bridgeAddress) Dock_L2(_bridgeAddress) {}

    function bindDock_L1(address _l1PairAddress) external override {
        l1PairAddress = _l1PairAddress;
    }

    function _callBridge(bytes memory _data) internal override {
        IArbSys(bridgeAddress).sendTxToL1(l1PairAddress, _data);
    }

    function _verifySenderAndDockPair() internal view override {
        // TODO
    }
}
