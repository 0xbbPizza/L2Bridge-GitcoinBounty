// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/ethereum-optimism/optimism/blob/master/packages/contracts/contracts/L1/messaging/IL1StandardBridge.sol";
import "https://github.com/ethereum-optimism/contracts/blob/master/contracts/optimistic-ethereum/iOVM/bridge/messaging/iOVM_L2CrossDomainMessenger.sol"    

contract Caller {
    event Response(bool success, bytes data);

    // Let's imagine that contract B does not have the source code for
    // contract A, but we do know the address of A and the function to call.
    
    function testCallFoo(address payable _addr) public payable {
        // You can send ether and specify a custom gas amount
        (bool success, bytes memory data) = _addr.call{value: msg.value, gas: 5000}(
            abi.encodeWithSignature("foo(string,uint256)", "call foo", 123)
        );

        emit Response(success, data);
    }

    

    function calldepositERC20To() public payable{
        address _addr = 0x22F24361D548e5FaAfb36d1437839f080363982B;
        address _tokenAddress = 0xa36085F69e2889c224210F603D836748e7dC0088;
        address l2tokenAddress = 0x4911b761993b9c8c0d14Ba2d86902AF6B0074F5B;
        address l2Address = 0x93071d0c48bb3417A30fE7070184194D3f03944d;
        uint256 amount = 10*10**18;
        uint32 maxGas = 2000000;

        // Approve
        IERC20(_tokenAddress).approve(_addr, amount);

        // Deposit
        IL1StandardBridge(_addr).depositERC20To(
            _tokenAddress, 
            l2tokenAddress, 
            l2Address, 
            amount, 
            maxGas, 
            ''
        );

        bytes memory _calldata = abi.encodeWithSignature("foo(string,uint256)", "call foo", 123);
        
        uint256 l2GasLimit = l2GasLimitForCalldata(_calldata);

        iOVM_L2CrossDomainMessenger(l1MessengerAddress).sendMessage(
            l2BridgeAddress,
            _calldata,
            uint32(l2GasLimit)
        );
    }

    function l2GasLimitForCalldata(bytes memory _calldata) private view returns (uint256) {
        uint256 l2GasLimit;

        if (_calldata.length >= 4) {
            bytes4 functionSignature = bytes4(toUint32(_calldata, 0));
            l2GasLimit = l2GasLimitForSignature[functionSignature];
        }

        if (l2GasLimit == 0) {
            l2GasLimit = 200000;
        }

        return l2GasLimit;
    }
    

    // Calling a function that does not exist triggers the fallback function.
    function testCallDoesNotExist(address _addr) public {
        (bool success, bytes memory data) = _addr.call(
            abi.encodeWithSignature("doesNotExist()")
        );

        emit Response(success, data);
    }
}