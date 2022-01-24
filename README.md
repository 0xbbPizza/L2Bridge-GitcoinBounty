## [Rule of the Bounty](https://gitcoin.co/issue/gitcoinco/skunkworks/253/100027342)
> This is a bounty to implement @vbuterin's idea of a decentralized cross-layer-2 bridge.
> 
> Idea described in more detail here: https://notes.ethereum.org/@vbuterin/cross_layer_2_bridges
> 
> The prize for this bounty is one winner who gets 10 ETH and an introduction to the EF Grants Team. At our discretion, we may reward secondary prizes if (and only if) there are multiple high quality submissions.
> 
> How it works:
> 1. read the spec
> 2. create a cross layer 2 bridge prototype (ui, smart contract).
> 3. submit work on Gitcoin by 3/1/2022 (march 1 2022).

## work flow chart
![](https://user-images.githubusercontent.com/88087562/148637737-1165e43e-bf3b-43c8-a947-6699bf7ee389.jpg)



## Plan

MVP will include 1,2,3 functions as I listed below, and they will be completed first; if time is enough, I will finish 4,5,6 in order.

1. Source-domain-side smart contract (Source-domain will choose one from arbitrum, optimism, polygon)
2. Destination-domain-side smart contract (L1)
    2.1 Proof contract for Source-domain
    2.2 script for creat proof
3. UI

4. LP Node
5. Other Destination-domain-side smart contracts (arbitrum, optimism)
6. New Proof contract for Source-domain which runs on L2 (reduced gas consumption of proof)





# Design



Name:  Belt-Bridge



### Interface

##### bonder work on Source side :  

```
class TransferData():
    tokenAddress: address
    destination: address
    amount: uint256
    fee: uint256
    startTime: uint256
    feeRampup: uint256
    nonce: uint256
    
class RewardData():
    transferDataHash: bytes32
    tokenAddress: address
    claimer: address
    fee: uint256
```

iSourceContract.sol

```
 knownHashOnions
 processedRewardHashOnion

CONTRACT_FEE_BASIS_POINTS = 5

funtion:
- transfer(transferData)
- processClaims(RewardData[])
```

iDestinationContract.sol

```
uint256 rewardHashOnion
uint256 transferCount
mapping rewardHashOnionHistoryList(claimedTransferHashes[claimedTransferHashes.count%100 == 1])
mapping claimedTransferHashes(hash -> bool)

declareNewHashChainHead

- claim(transferData)
```



##### bonder work on Destination side:

Data: 

```
class TransferData():
    tokenAddress: address
    destination: address
    amount: uint256
    fee: uint256
    
class hashOnionFork():
		forkedFrom: [forkTxIndex,forkId] 
		forker: address
		forkBetAmount: uint256
		hashOnions: array<bytes32>
		transferDatas: array<TransferData>
		filter: uint256
		balanceDic: address->balance ?
```

iSourceContract.sol

```
uint256 txIndex
bytes32 hashOnion

CONTRACT_FEE_BASIS_POINTS = 5
BASE_BIND_FEE = x

funtion:
- transfer(transferData)
- extractHashOnionAndBalance()

```

iDestinationContract.sol

```
uint256 sourceTxIndex
bytes32 sourceHashOnion
mapping( forkTxIndex -> forkId -> hashOnionFork) hashOnionHistory

mapping( address -> balance) commiterDepositBalance

BASE_COMMIT_FEE = x

- claim(transferData,txIndex, forkTxIndex ,forkId)
- bonder(sourceHashOnion, forkTxIndex , forkId)
- commiterDeposit() 
- commiterWithdraw(amount)
```



### Role



Bonder's Rules:

1. Work flow:

   1. On source to call into L1.

   2. On L1 to call into dest.

   3. On dest.

2. Get rewarded by performing settlement procedures at dest.
3. rewards = (currentBindingHashOnionIndex - lastBindedHashOnionIndex) * BASE_BIND_FEE.
4. Anyone can be a bonder,no censorship.



Sender's Rules:

1. Work flow:

   1. Call source's function transfer(transferData),  paymentAmount = destAmout + Fees_to_market_makers + BASE_BIND_FEE.

   2. Wait a few time , market maker transfers destAmout back at dest.

      or 

   3. Wait source's withdraw time , receive the destAmout + Fees_to_market_makers from the dest contract.

2. As long as the sender places the transferData, his expectations will be fulfilled.



market_makers' Rules:

1. Work flow:
   1. Observe the newly added transferData in source off-chain.
   2. In dest:  Submit only new transferData or both submit and transfer to destination address.
   3. Wait source's withdraw time, get rewarded and amount paid for transferData

2. Anyone can be a market_makers, no censorship.
3. Market_makers can automate and serve the sender faster by running off-chain programs



## Waiting for design: 

1. Decentralized registration mechanism for multi-domain Token address 

2. Make the difference between bilateral balances work to improve the efficiency of fund use

3. Separating the roles of market maker and LP

   > The model can be abstracted as follows: the sender deposits 1 million USDC in the source, and at the same time withdraws the funds to the dest via the official bridge. In dest's view, this is a 7-day future. In the dest contract, maketmaker sent 1 million USDC to the sender, which can be regarded as taking ownership of the futures. Suppose we also have a loan contract, and LPs have deposited liquidity in the loan contract. If the loan contract can be convinced of the value of the 1 million USDC futures through some kind of credit mechanism, the maker will immediately obtain funds from the loan contract. , 7 days later, 1 million USDC reaches dest, and the loan contract is repaid.
   >
   > The benefits of this model are:
   >
   > 1. Maketmaker can complete more transactions with less capital
   > 2. The sender's funds are very safe
   > 3. The LP only needs to deposit funds into the contract and does not need to run a node. Lower the threshold for earning income
   >
   > The risks of this model are:
   >
   > 1. The security of LP's funds is highly related to the trust mechanism, If the contract believes in the wrong security mechanism, LP will not get paid
   >
   > 
   >
   > The credit mechanism is as follows:
   >
   > 1. In the loan contract, there is an open interface. Anyone can mortgage a txhash interval in the dest contract. The mortgage fund is 10% of the total amount of the interval. Wait for a dispute period. If you place a bet on fork, it is considered that if the credit reaches 100, you can borrow 100% and return the mortgage. The dispute period may be 30 minutes, or it may be calculated based on the total amount of the interval.
   >
   > 2. In the thread of mortgage for disagreement, the two can bet successively at a fixed amount to extend the dispute time. If both parties stop betting, after the dispute time is reached, the bet with more bet amount wins, and the winning fork reaches 100% 's credit. 60% of the total bet amount of the failed fork will be rewarded to the winner, 30% will be rewarded to the LP of the loan contract, and 10% will be destroyed or used for other purposes.
   > 3. The bet amount cannot exceed 120% of the total amount of the interval, and the longest dispute period cannot exceed the withdrawal time of the source
   > 4. During the dispute period, you can continue to pledge for the new txhash interval. The pledge in the same fork extension line can be added to the PK before the end of the dispute. If the fork extension line is not, it will not be included in the dispute competition.

   

1. Market Maker with Response Time Commitment with Deposit
2. Cross domain Dex, open protocal
3. Multi-Coin
4. Multi-Domain
