

interface IArbSys { 
    // from arbitrum
    function sendTxToL1(address destAddr, bytes calldata calldataForL1) external payable;
}