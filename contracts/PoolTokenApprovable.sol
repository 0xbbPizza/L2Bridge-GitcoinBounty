// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./PoolToken.sol";

contract PoolTokenApprovable is Ownable {
    address private _poolTokenAddress;

    function bindPoolTokenAddress(address poolTokenAddress_)
        external
        onlyOwner
    {
        require(
            poolTokenAddress_ != address(0),
            "PoolTokenApprovable bindPoolTokenAddress: poolTokenAddress_ is zero"
        );

        _poolTokenAddress = poolTokenAddress_;
    }

    function poolToken() public view returns (PoolToken) {
        require(
            _poolTokenAddress != address(0),
            "PoolTokenApprovable poolToken: _poolTokenAddress is zero"
        );

        return PoolToken(_poolTokenAddress);
    }
}
