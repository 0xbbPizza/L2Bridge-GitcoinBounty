```
/*
// DockL2
// fromDomain same    1
(destAddress,destMassage,destChainID) {
     onion1 = (destAddress,destMassage,sourceAddress,sourceChainID), 
     onion2 = (dockPairOnL1_address,dockPairOnL1_Function,destChainID,onion1)}
     
// out bridge         call.bridge.sendtx(onion2)


// from bridge  checkSenderIsBridgeAndPair 
// toDomain same
(destAddress,destMassage,sourceAddress,sourceChainID){
    context = {sourceAddress,sourceChainID}
    destAddress.call(destMassage)
    context = nil
}

// DockL1
// From bridge  checkSenderIsBridgeAndPair    2
// to ralay same   relay.in(destChainID,onion1)

// From ralay same 
checkIsComeFromRELAY
Onion3 = (dockPairL2Address,dockPairL2_function,onion1)

// to bridge 
bridge.function(Onion3)


// RELAY
// in   checkSenderIsTrustDock
// out  
(destChainID,onion1) {
    destDockAddress_onL1 = docks[inputData.destChainID]
    destDockAddress_onL1.fromRelay(onion1)
*/

```