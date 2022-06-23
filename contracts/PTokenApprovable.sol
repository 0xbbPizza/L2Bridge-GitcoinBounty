// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./PToken.sol";

contract PTokenApprovable is Ownable {
    address private _pTokenAddress;

    function bindPTokenAddress(address pTokenAddress_) external onlyOwner {
        require(
            pTokenAddress_ != address(0),
            "pTokenAddress_ is zero"
        );

        _pTokenAddress = pTokenAddress_;
    }

    function pTokenAddress() public view returns (address) {
        require(
            _pTokenAddress != address(0),
            "_pTokenAddress is zero"
        );

        return _pTokenAddress;
    }
}
