// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "../PoolToken.sol";

contract PoolTokenTest {
    function exchangeBasicToken(
        address poolToken,
        address exToken,
        uint256 amount
    ) external returns (bool) {
        PoolToken(poolToken).mint(address(this), amount);

        PoolToken(poolToken).exchange(exToken, amount);

        return true;
    }
}
