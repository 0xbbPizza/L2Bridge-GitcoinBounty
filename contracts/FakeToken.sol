//SPDX-License-Identifier: Unlicense

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Example class - a mock class using delivering from ERC20
contract BasicToken is ERC20 {
  constructor(uint256 initialBalance) ERC20("Pizza", "Pizza") public {
      _mint(msg.sender, 800000000000000000000000000);
  }
}