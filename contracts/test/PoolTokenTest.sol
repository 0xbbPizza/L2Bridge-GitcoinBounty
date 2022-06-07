// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "../PoolToken.sol";
import "../PoolTokenApprovable.sol";
import "hardhat/console.sol";

contract PoolTokenTest is PoolTokenApprovable {
    function exchangeBasicToken(
        address exToken,
        uint256 amount
    ) external returns (bool) {
        poolToken().mint(amount);

        poolToken().exchange(exToken, amount);

        return true;
    }
}
