 
 
    //     // !!! Determine whether the index at the moment is greater than the last withdrawal index, and determine whether the index is at zero
    //     // !!! Make a settlement for the bond
    //     // !!! Send onion to Relay, each step will be settled to bonder
    //     uint256 amount = IERC20(tokenAddress).balanceOf(address(this));
    //     IERC20(tokenAddress).safeTransfer(relayAddress,amount);

    //     Relay(relayAddress).getHashOnion(txIndex,hashOnion,tokenAddress,msg.sender);

interface IArbSys { 
    // from arbitrum
    function sendTxToL1(address destAddr, bytes calldata calldataForL1) external payable;
}


 // send to L1 dest
        bytes memory message = abi.encodeWithSignature(
            "getHashOnion(bytes32)",
            bringHashOnion
        );

        IArbSys(l2Messenger).sendTxToL1(
            raley,
            message
        );



    