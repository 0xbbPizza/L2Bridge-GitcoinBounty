// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PToken is ERC20, Ownable {
    receive() external payable {}

    uint32 private _scale = 10;

    constructor(address owner_) ERC20("Orbiter Pool Token", "PToken") {
        Ownable.transferOwnership(owner_);
    }

    function scale() public view returns (uint32) {
        return _scale;
    }

    function mint(uint256 amount) external onlyOwner {
        _mint(msg.sender, amount);
    }
}
