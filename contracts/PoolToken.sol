// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PoolToken is ERC20, Ownable {
    uint32 private _scale = 10;

    constructor(address owner_) ERC20("Orbiter Pool Token", "PToken") {
        Ownable.transferOwnership(owner_);
    }

    function scale() public view returns (uint32) {
        return _scale;
    }

    function exchange(address exToken, uint256 amount) external onlyOwner {
        require(exToken != address(0), "PoolToken: exchange zero exToken");
        require(amount != 0, "PoolToken: exchange zero amount");

        _burn(owner(), amount);

        IERC20(exToken).transfer(owner(), amount * scale());
    }

    // TODO For debug
    function mint(uint256 amount) external onlyOwner {
        _mint(_msgSender(), amount);
    }
}
