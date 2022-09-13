// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

contract TransferHelper {
    using SafeERC20 for IERC20;
    uint256 private tokenStatus; // 0:unInit   1:ETH  2:ERC20
    address private tokenAddress;

    modifier onlyInit() {
        require(tokenStatus != 0, "Only Init");
        _;
    }

    function initialize(address _tokenAddress) internal {
        if (_tokenAddress == address(0x0)) {
            tokenStatus = 1;
        } else {
            IERC20(_tokenAddress).totalSupply();
            tokenStatus = 2;
        }
        tokenAddress = _tokenAddress;
    }

    function getBalance(address from) internal view onlyInit returns (uint256) {
        uint256 balance;
        if (tokenStatus == 1) {
            balance = from.balance;
        } else if (tokenStatus == 2) {
            balance = IERC20(tokenAddress).balanceOf(from);
        }
        return balance;
    }

    function getContractBalance() external view onlyInit returns (uint256) {
        return address(this).balance;
    }

    function transferToDestWithSafeForm(address payable to, uint256 value)
        internal
        onlyInit
    {
        if (tokenStatus == 1) {
            require(msg.value == value, "Inconsistent transfer amount");
        } else if (tokenStatus == 2) {
            IERC20(tokenAddress).safeTransferFrom(msg.sender, to, value);
        }
    }

    function transferToDest(address payable to, uint256 value)
        internal
        onlyInit
    {
        if (tokenStatus == 1) {
            to.transfer(value);
        } else if (tokenStatus == 2) {
            //

            IERC20(tokenAddress).transfer(to, value);
        }
    }

    function transferToDestWithSafe(address payable to, uint256 value)
        internal
        onlyInit
    {
        if (tokenStatus == 1) {
            //
        } else if (tokenStatus == 2) {
            IERC20(tokenAddress).safeTransfer(to, value);
        }
    }
}
