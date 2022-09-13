// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "../PToken.sol";
import "../DToken.sol";
import "../PTokenApprovable.sol";
import "../BasicToken.sol";
import "hardhat/console.sol";

contract PTokenTest is PTokenApprovable {
    function mintToken(uint256 amount) external payable returns (bool) {
        PToken(payable(pTokenAddress())).mint(amount);

        return true;
    }

    function borrowToken(DToken dTokenAddress, uint256 borrowAmount)
        external
        returns (bool)
    {
        dTokenAddress.borrow(borrowAmount);

        return true;
    }

    function repayBorrowToken(DToken dTokenAddress, uint256 repayAmount)
        external
        returns (bool)
    {
        dTokenAddress.repayBorrow(repayAmount);

        return true;
    }

    function approve(
        BasicToken basicTokenAddress,
        address spender,
        uint256 amount
    ) external returns (bool) {
        basicTokenAddress.approve(spender, amount);

        return true;
    }
}
