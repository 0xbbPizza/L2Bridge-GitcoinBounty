// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "../PToken.sol";
import "../DToken.sol";
import "../PTokenApprovable.sol";
import "hardhat/console.sol";

contract PTokenTest is PTokenApprovable {
    function mintToken(uint256 amount)
        external
        returns (bool)
    {
        PToken(pTokenAddress()).mint(amount);

        return true;
    }

    function borrowToken(DToken dTokenAddress,uint256 borrowAmount)
        external
        returns(bool)
    {
        dTokenAddress.borrow(borrowAmount);

        return true;
    }
}
