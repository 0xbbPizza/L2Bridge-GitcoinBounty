// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

library ForkDeposit {
    struct Info {
        address depositter;
        bool accept; // true: Accept, false: Deny
        uint256 amount;
        uint256 timestamp; // block timestamp
    }

    /// @param forkKey Fork's key
    function deposit(mapping(bytes32 => Info[]) storage self, bytes32 forkKey, uint256 amount)
        internal
    {
        if (self[forkKey].length > 0) {

        } else {
            
        }
    }

    /// @param forkKey Fork's key
    function denyDeposit(mapping(bytes32 => Info[]) storage self, bytes32 forkKey, uint256 amount)
        internal
    {}
}
