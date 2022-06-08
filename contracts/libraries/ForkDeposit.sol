// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

library ForkDeposit {
    uint256 internal constant DEPOSIT_SCALE = 10;
    uint256 internal constant DEPOSIT_BLOCK_NUMBER = 2; // During this number

    struct Info {
        address endorser;
        address denyer;
        uint256 amount;
        uint256 prevBlockNumber; // Prev deposit block number
    }

    /// @param forkKey Fork's key
    function deposit(
        mapping(bytes32 => Info) storage self,
        bytes32 forkKey,
        uint256 amount,
        bool deny
    ) internal {
        Info memory info = self[forkKey];

        if (info.prevBlockNumber > 0) {
            require(
                block.number - info.prevBlockNumber < DEPOSIT_BLOCK_NUMBER,
                "ForkDeposit deposit: more than block number"
            );
        }

        if (deny) {
            require(
                info.denyer == address(0),
                "ForkDeposit deposit: exist denyer"
            );

            info.denyer = msg.sender;
        } else {
            require(
                info.endorser == address(0),
                "ForkDeposit deposit: exist endorser"
            );

            info.endorser = msg.sender;
        }

        info.amount = amount;
        info.prevBlockNumber = block.number;
        self[forkKey] = info;
    }
}
