// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

contract TransferHelper {
    using SafeERC20 for IERC20;
    uint256 private tokenStatus; // 0:unInit   1:ETH  2:ERC20
    address private tokenAddress;
    address private sameDomainDestAddress;

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

    function bindDestAddress(address _sameDomainDestAddress) internal onlyInit {
        sameDomainDestAddress = _sameDomainDestAddress;
    }

    function getBalance(address from) public view onlyInit returns (uint256) {
        uint256 balance;
        if (tokenStatus == 1) {
            balance = from.balance;
        } else if (tokenStatus == 2) {
            balance = IERC20(tokenAddress).balanceOf(from);
        }
        return balance;
    }

    function transferToDestWithSafeForm(
        address from,
        address to,
        uint256 value
    ) internal onlyInit {
        if (tokenStatus == 1) {
            ethTransfer(to, value);
        } else if (tokenStatus == 2) {
            IERC20(tokenAddress).safeTransferFrom(
                payable(from),
                payable(to),
                value
            );
        }
    }

    function transferToDest(address to, uint256 value) internal onlyInit {
        if (tokenStatus == 1) {
            ethTransfer(to, value);
        } else if (tokenStatus == 2) {
            IERC20(tokenAddress).transfer(payable(to), value);
        }
    }

    function transferToDestWithSafe(address to, uint256 value)
        internal
        onlyInit
    {
        if (tokenStatus == 1) {
            ethTransfer(to, value);
        } else if (tokenStatus == 2) {
            IERC20(tokenAddress).safeTransfer(payable(to), value);
        }
    }

    function ethTransfer(address to, uint256 amount) internal onlyInit {
        if (to == address(this) || to == sameDomainDestAddress) {
            require(msg.value == amount, "Inconsistent transfer amount");
        }
        payable(to).transfer(amount);
    }
}
