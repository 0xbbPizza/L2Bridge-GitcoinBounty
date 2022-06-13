// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

library ForkDeposit {
    uint256 internal constant DEPOSIT_SCALE = 10;
    // uint256 internal constant DEPOSIT_BLOCK_NUMBER = 2; // During this number
    uint256 internal constant DEPOSIT_BLOCK_NUMBER = 0; // TODO Debug. During this number
    uint16 internal constant MFORK_UNITED_WORK_INDEX = 2**16 - 1;

    struct Info {
        address endorser;
        address denyer;
        uint256 amount;
        uint256 prevBlockNumber; // Prev deposit block number
    }

    function getDepositEnsure(
        mapping(bytes32 => Info) storage self,
        bytes32 forkKey
    ) internal view returns (Info memory) {
        Info memory forkDeposit = self[forkKey];

        require(
            forkDeposit.endorser != address(0) ||
                forkDeposit.denyer != address(0),
            "ForkDeposit is null"
        );

        return forkDeposit;
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
                isBlockNumberArrive(info.prevBlockNumber) == false,
                "More than block number"
            );
        }

        if (deny) {
            require(info.endorser != address(0), "No exist endorser");
            require(info.denyer == address(0), "Exist denyer");

            info.denyer = msg.sender;
        } else {
            require(info.endorser == address(0), "Exist endorser");

            info.endorser = msg.sender;
        }

        info.amount = amount;
        info.prevBlockNumber = block.number;
        self[forkKey] = info;
    }

    function isBlockNumberArrive(uint256 prevBlockNumber)
        internal
        view
        returns (bool)
    {
        return block.number - prevBlockNumber >= DEPOSIT_BLOCK_NUMBER;
    }
}
