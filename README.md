# Pizza 🍕Bridge

A decentralized L222 bridge , see in [website ](https://pizza.orbiter.finance/)，development still in progress.

https://user-images.githubusercontent.com/88087562/156006812-c3e6b0d2-04a5-4c9c-a203-63d7af24f325.mp4

## Project resources

- 🌊 [Contract code](https://github.com/0xbbPizza/L2Bridge-GitcoinBounty/tree/main/contracts)
- 🏄 [ Front-end Project ](https://github.com/0xbbPizza/OrbiterFE-V2/tree/main)
- 🏄‍♀️ [ LPClient Project ](https://github.com/0xbbPizza/PizzaBridge-MakerNode)

## Deploy Address

> The contract is being updated all the time, and the code for deploying the contract may not be exactly the same as the code in the main branch

| chain       |                                                                sourceContract                                                                 |                                                                 destContract                                                                 |
| :---------- | :-------------------------------------------------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------: |
| Goerli      |         [0xeF301C3a142A0a20310b1bf98e9b9af5e56f52F1 ](https://goerli.etherscan.io/address/0x912a53c752842Cf807E6dd802b19C386fa361bDB)         |        [ 0xb1e19241A5b7fF57d66e2fd57a02d8c10F92b452 ](https://goerli.etherscan.io/address/0xCA7384815D65bDf058382330B3e3848553597980)        |
| Arbitrum(G) | [ 0x42cbE44636aEb019402Eae2808131a5E858E8636 ](https://goerli-rollup-explorer.arbitrum.io/address/0x0caAE6dfA4A8e57008153Bd41343b04dD8884E92) | [0xC7Ea534F4831f2D96Ee59770cA3Bf4681890E4EF ](https://goerli-rollup-explorer.arbitrum.io/address/0xD72e2Da199292d0B59D6962caFEb58ca02d48539) |

---

## Eat Pizza

This scheme is based on the design in vitalik's article ["Easy Decentralized cross-layer-2 bridge"](https://notes.ethereum.org/@vbuterin/cross_layer_2_bridges), and his further discussion of the scheme in telegram . The basic structure of the program and the realization of the goal, vitalik has a very refined description.

![image-20220227043842424](https://tva1.sinaimg.cn/large/e6c9d24egy1gzrkxj394ej20u00je0vt.jpg)

Next, I will introduce the implementation details of Pizza according to the order of contract interaction.

- There are two contracts: Source and Dest
- three roles: User, LP, Bonder

### 1. On source domain User transfer token to SourceContract [code](https://github.com/0xbbPizza/L2Bridge-GitcoinBounty/blob/main/contracts/SourceContract.sol)

The following settings are made in the source contract of pizza bridge. The keyPoint is to better cooperate with the subsequent steps related to Dest.

1. Data structure: In order to reduce the size of the input data on L1, reduce the gas fee, and dest, bind the tokenAddress to the smart contract address. There are only destination, amount, and fee in TransferData.

   ```solidity
   library Data {
       struct TransferData{
           address destination;
           uint256 amount;
           uint256 fee;
       }
   }
   ```

2. full amount，involved fee and BASE_BIND_FEE

   ```solidity
   uint256 allAmount = amount + fee + BASE_BIND_FEE;
   ```

   - fee: The bounty for the LP is directly passed in by the User. As long as the two conditions are met, the user can get the payment immediately, so the method of calculating the revenue according to the response time in the contract can be omitted.

     > 1. Fee is approximately equal to 0.15%. It is based on the unit time of LP's minimum annualized expectation (8%)/365 days/withdrawtime 7 days.
     > 2. dest is an open system, and LPs know that it is impossible to rule out that someone will serve the user.

   - BASE_BIND_FEE: Bounty for Bonder, preset in the contract, equal to (a normal L2-L1-L2 information transfer GasLimit/ONEFORK_MAX_LENGTH ) x average price

3. There is a transfer function, which can further reduce the transfer data when the user does not need to set the destination address

   ```solidity
   function transfer(
           uint256 chainId,
           uint256 amount,
           uint256 fee
       ) external payable;
   ```

4. Support muti domain, the advantage of using mapping(uint256 => DomainStruct) is to allow liquidity to be concentrated in the same contract.

   ```solidity
   struct DomainStruct{
           uint256 txIndex;
           bytes32 hashOnion;
           bytes32 bringHashOnion;
           address destAddress;     //destContract
       }
   ```

### 2. On dest domain LP cross DestContract transfer token to user [code](https://github.com/0xbbPizza/L2Bridge-GitcoinBounty/blob/main/contracts/NewDestination.sol)

1. LP run a offchain client , see this link [ LPClient github ](https://github.com/0xbbPizza/PizzaBridge-MakerNode)

2. There are three ways to transfer money for users zfork(), claim(), mfork()，The reason there are multiple function under:

   > openness is more than other future in this contract, Because only then will there be enough competition, LP's service will be cheaper and faster.
   >
   > but Openness allows bad behavior to have a chance. only one hashOnion is not safe, Map save every hashOnion spent too much gas.
   >
   > so , I make a data struct "Fork" , It is both safe and cheap，every fork just spend 2 x byte32 + unit 256 , the multiple of saving over full storage is fork.length, after the official launch, the number will be 100，If zero-knowledge proof is used in settlement, fork.length will > 500

   ```solidity
   library Fork {
         struct Info{
            uint16 workIndex; // 0: zFork, >0: mFork
            bytes32 onionHead;
            bytes32 destOnionHead;
            uint256 allAmount;
            uint256 length;
            address lastCommiterAddress;
            bool needBond; // true is need to settle
            uint8 verifyStatus; // 0: No verify, 1: Verified - fork is real, 2: Verified - fork is fake
       }
   }
   ```

   The following are the submission rules for LPs

   ```solidity
     /*
           A. Ensure that a single correct fork link is present:
           There are three behaviors of commiters(LP) related to fork:
           1. Create a 0-bit fork : zfork()
           2. Create a non-zero fork:  mfork()
           3. Add OnionHead to any Fork :  claim()

           The rules are as follows:
           1. Accept any submission, zero-bit Fork needs to pass in PreForkkey
           2. Fork starting with non-zero bits, length == ONEFORK_MAX_LENGTH - index (value range 1-49)

           B. Ensure that only the only correct fork link will be settled:
           1. onWorkHashOnion's index % ONEFORK_MAX_LENGTH == ONEFORK_MAX_LENGTH
           2. When bonding, the bond is the bond from the back to the front. If the fork being bonded is a non-zero fork, you need to provide preForkKey, onions1, onions2, and the parameters must meet the following conditions:
              2.1 f(onions) == preFork.onionHead
              2.2 onions[0] != fork.key //If there is an equal situation, then give the allAmount of the fork to onions[0].address . The bonder gets a deposit to compensate the gas fee.
              2.3 fork.onionHead == onWorkHashOnion

           C. Guarantee that bad commits will be penalized:
           1. CommiterA deposits the deposit, initiates a commit or fork, and the deposit is locked
           2. The margin can only be unlocked by the addition of another Committer
       */
   ```

   All of the above is to ensure that there must be only one correct link from the initial to the latest source.hashOnion in Dest, no double spending 、 no blocking attacks、no dust attack.

3. in the design of number 2, If there is no penalty, data will like A style, too many "uncle fork".

   ![IMG_0208](https://tva1.sinaimg.cn/large/e6c9d24egy1gztba52m3yj21r00hb401.jpg)

   - so , make A become B , the deposit rule is :

     ```solidity
     /*
      1. every LP need deposit `DEPOSIT_AMOUNT` ETH, DEPOSIT_AMOUNT = OnebondGaslimit * max_fork.length * Average_gasPrice
      2. when LP call zfork()、mfork()、claim(). lock deposit, and unlock the preHashOnions LP's deposit.
      3. When bonder is settling `middle fork`, will get `DEPOSIT_AMOUNT` ETH back from destContract.
      4. LP's deposit can only be withdrawn if they are unlocked.
      5. No one wants to pay for someone else's mistakes, so the perpetrator's deposit will never be unlocked
     */
     ```

4. for muti Domain , We use chainId this parameter to make the funds in a contract.

   ```solidity
   function zFork(
           uint256 chainId,
           bytes32 hashOnion,
           address dest,
           uint256 amount,
           uint256 fee,
           bool _isRespond
       ) external;
   ```

### 3. cross L2 domain send HashOnion or fund

1. When the two domains can be transferred to each other, the settlement will be smoother, the fund will only be transferred once after a long time, and the LP's fund settlement efficiency is still normal.

   > There are two domains, A and B.

   1. Just A-source to B-dest : two contract，one-way ：

      - **Settled in source**： The time for LP to restore the capital limit in B takes **two weeks**: one week B->hashOnion->A，one week A->fund-> B.

      - **Settled in dest**：The time for LP to restore the capital limit in B takes **one weeks**.

   2. Deployed A-source -> B-dest + B-source -> A-dest : four contract，two-way

      - Whether settled in source or dest contracts，LP to restore fund just need one week, no need to move funds between domains。（As in the picture, B-dest can settle with the funds in B-source after obtaining the hashOnion of A-source, and vice versa）

        ![image-20220228175458488](https://tva1.sinaimg.cn/large/e6c9d24egy1gztdkbftosj21ks0dgwg0.jpg)

        Some people worry about a situation，when B-source fund is less than A-source, Balance cannot be supported B-dest settlement . As in the picture, Whenever dest is to be settled, the balance in source is accumulated after seven days. no need to move funds between domains.

        ![image-20220228175812041](https://tva1.sinaimg.cn/large/e6c9d24egy1gztdno8ce9j21ko0jstav.jpg)

      - Based on my follow-up design to improve the efficiency of fund use, I prefer hashOnion from source to dest.

2. very time N txs are generated ，cross domain only happens once.

   > one_tx_spend_gasLimit = (l2-L1gaslimit + L1-L2 gaslimit) \* 1 / N
   >
   > when Arb -> OP, cost 30K gaslimit，when OP -> Arb, cost 100K gaslimit. set N = 50
   >
   > one_tx_spend_gasLimit = 1k ~ 2k

   Detail:

   ```
   1. Arb -> OP， gaslimit = 30K

      1. source -> Arb_bridge     759259(l2)
      2. Arb_bridge -> L1relayContract   161754
      3. L1relayContract -> Op_bridge     150829
      4. Op_bridge -> destContract   4536(L2)

   2. OP -> Arb， gaslimit = 100K ：

      1. source -> Op_bridge    5186(L2)
      2. Op_bridge -> L1relayContract   776662
      3. L1relayContract -> Arb_bridge   207106
      4. Arb_bridge -> destContract   900995(l2)

   ```

3. Build standard contracts on cross domains, [code](https://github.com/0xbbPizza/L2Bridge-GitcoinBounty/tree/main/contracts/MessageDock)

   > Just finished the architecture design，need more work

   1. Because the interfaces of each bridge are not uniform, it is necessary to design the forwarding system slightly to keep the dest contract and the source contract clear. This code shows the API

      ```solidity
      abstract contract CrossDomainHelper {
          address public immutable dockAddr;

          constructor(address _dockAddr) {
              dockAddr = _dockAddr;
          }

          modifier sourceSafe() {
              require(msg.sender == dockAddr, "NOT_DOCK");
              _onlyApprovedSources(
                  IDock_L2(msg.sender).getSourceSender(),
                  IDock_L2(msg.sender).getSourceChainID()
              );
              _;
          }

          function _onlyApprovedSources(address _sourceSender, uint256 _sourChainId)
              internal
              view
              virtual;

          function crossDomainMassage(
              address _destAddress,
              uint256 _destChainID,
              uint256 _msgValue,
              bytes memory _destMassage,
              bytes memory _ticketIncidentalInfo
          ) internal {
              IDock_L2(dockAddr).callOtherDomainFunction{value: _msgValue}(
                  _destAddress,
                  _destChainID,
                  _destMassage,
                  _ticketIncidentalInfo
              );
          }
      }
      ```

      The current information transmission between L2 <-> L2 needs to go through L1, and the Merkle proof needs to be done in the bridge contract of L1 in the middle.
      The bottom layer can be replaced if necessary in the future. The message no longer passes through L1, but is proved on L2, which can save the gas cost of the calculation process. In the future, zero-knowledge proof can be used to reduce the gas consumption of input on L1.

   2. Here, in order to support various types of bridges and multiple destinations, we further separate the logical layer from the physical layer of the cross-domain part, so we have designed a pair of pairing contracts called "Dock_L1 and Dock_L2". The role is to implement the interface of various types of bridges without involving specific data. At the same time, we store the contract address and chainId of the various bridge interfaces implemented in the contract named "Relay".

      - This is a Relay contract, which can be understood as a "Relay" contract is a courier transfer station.

        ```solidity
        contract Relay is IRelay, Ownable {
            mapping(uint256 => address) private docksMap_chainIdKey;
            mapping(address => uint256) private docksMap_addressKey;

            address[] public allowedDockList;

            function docksAddressKey(address dock)
                external
                view
                override
                returns (uint256)
            {
                return docksMap_addressKey[dock];
            }

            function docksChainIdKey(uint256 chainId)
                external
                view
                override
                returns (address)
            {
                return docksMap_chainIdKey[chainId];
            }

            function addDock(address dock, uint256 chainId) external onlyOwner {
                docksMap_addressKey[dock] = chainId;
                docksMap_chainIdKey[chainId] = dock;
                emit addedDock(chainId, dock);
            }

            function relayCall(uint256 destChainID, bytes calldata data)
                external
                payable
                override
                returns (bool success)
            {
                require(docksMap_addressKey[msg.sender] > 0, "NOT_FROM_Dock");
                address destDock = docksMap_chainIdKey[destChainID];
                require(destDock != address(0));
                IDock_L1(destDock).fromRelay{value: msg.value}(data);
                success = true;
            }
        }
        ```

      - This is a Dock_L1 contract based on which L1 parts of various bridges are implemented.

        ```solidity
        abstract contract Dock_L1 is IDock_L1 {
           address public immutable l2CallInAddress;
           address public immutable l2OutAddress;
           address public immutable relayAddress;

           constructor(
              address _l2CallInAddress,
              address _l2OutAddress,
              address _relayAddress
           ) {
              l2CallInAddress = _l2CallInAddress;
              l2OutAddress = _l2OutAddress;
              relayAddress = _relayAddress;
           }

           function fromL2Pair(uint256 _destChainID, bytes calldata _data) external {
              _verifySenderAndDockPair();
              IRelay(relayAddress).relayCall(_destChainID, _data);
           }

           function fromRelay(bytes calldata _data)
              external
              payable
              override
              onlyRelay
           {
              bytes memory newData = abi.encodeWithSignature(
                    "fromL1Pair(bytes)",
                    _data
              );
              bytes[2] memory dataArray = [newData, _data];
              _callBridge(dataArray);
           }

           // muti to bridge
           function _callBridge(bytes[2] memory _data) internal virtual;

           // muti  From bridge
           function _verifySenderAndDockPair() internal view virtual;

           modifier onlyRelay() {
              require(msg.sender == relayAddress);
              _;
           }
        }
        ```

      - The contract is consistent with the role of contract Dock_L1, and is also based on the contract to realize the L2 part of the various bridges.

        ```solidity
        abstract contract Dock_L2 is IDock_L2 {
           using Address for address;

           address public l1PairAddress;
           address public immutable bridgeAddress;

           // Note, these variables are set and then wiped during a single transaction.
           // Therefore their values don't need to be maintained, and their slots will
           // be empty outside of transactions
           uint256 internal sourceChainID;
           address internal sourceSender;

           constructor(address _bridgeAddress) {
              bridgeAddress = _bridgeAddress;
           }

           function bindDock_L1(address _l1PairAddress) external virtual;

           function getSourceChainID() external view override returns (uint256) {
              return sourceChainID;
           }

           function getSourceSender() external view override returns (address) {
              return sourceSender;
           }

           // fromDomain
           function callOtherDomainFunction(
              address _destAddress,
              uint256 _destChainID,
              bytes memory _destMassage,
              bytes memory _ticketIncidentalInfo
           ) external payable override {
              bytes memory onions1 = abi.encode(
                    _destAddress,
                    _destMassage,
                    msg.sender,
                    block.chainid
              );
              bytes memory onions2 = abi.encodeWithSignature(
                    "fromL2Pair(uint256,bytes)",
                    _destChainID,
                    onions1
              );
              _callBridge(onions2);
           }

           // muti : call bridge
           function _callBridge(bytes memory _data) internal virtual;

           // fromBridge
           function fromL1Pair(bytes calldata _data) external payable {
              _verifySenderAndDockPair();
              address preSourceSender = sourceSender;
              uint256 preSourceChainID = sourceChainID;
              address destAddress;
              bytes memory destMassage;
              bytes memory ticketIncidentalInfo;
              (
                    destAddress,
                    destMassage,
                    ticketIncidentalInfo,
                    sourceSender,
                    sourceChainID
              ) = abi.decode(_data, (address, bytes, bytes, address, uint256));

              if (destMassage.length > 0)
                    require(destAddress.isContract(), "NO_CODE_AT_DEST");
              (bool success, ) = destAddress.call(destMassage);
              require(success, "WRONG_MSG");

              sourceSender = preSourceSender;
              sourceChainID = preSourceChainID;
           }

           // muti : FromBridge
           function _verifySenderAndDockPair() internal view virtual;
        }
        ```

### 4. all the LPs can now be compensated

1. Funtion: zBond

   ```solidity
   interface IDestinationContract{
         function zbond(
         uint256 chainId,
         bytes32 hashOnion,
         bytes32 _preHashOnion,
         Data.TransferData[] calldata _transferDatas,
         address[] calldata _commiters
         ) external;
   }
   ```

   > The input data in L1 is too large, and I am considering using starkNet's Cairo to generate account status through transfer information:
   >
   > input: sourceTxs , destMakerAddress
   >
   > change to
   >
   > input: [{address, balance},...]
   >
   > but，need wait [keccak](https://github.com/starkware-libs/cairo-lang/blob/master/src/starkware/cairo/common/keccak.cairo) more safe
   >
   > ```
   > # Computes the keccak hash.
   > # This function is unsafe (not sound): there is no validity enforcement that the result is indeed
   > # keccak, but an honest prover will compute the keccak.
   > # Args:
   > # data - an array of words representing the input data. Each word in the array is 16 bytes of the
   > # input data, except the last word, which may be less.
   > # length - the number of bytes in the input.
   > ```

2. Break the one-week capital efficiency limit, early settlement mechanism

   The model can be abstracted as follows: the sender deposits 1 million USDC in the source, and at the same time withdraws the funds to the dest via the official bridge. In dest's view, this is a 7-day future. In the dest contract, maketmaker sent 1 million USDC to the sender, which can be regarded as taking ownership of the futures. Suppose we also have a loan contract, and LPs have deposited liquidity in the loan contract. If the loan contract can be convinced of the value of the 1 million USDC futures through some kind of credit mechanism, the maker will immediately obtain funds from the loan contract. , 7 days later, 1 million USDC reaches dest, and the loan contract is repaid.

   The benefits of this model are:

   1. Maketmaker can complete more transactions with less capital
   2. The sender's funds are very safe
   3. The LP only needs to deposit funds into the contract and does not need to run a node. Lower the threshold for earning income

   The risks of this model are:

   1. The security of LP's funds is highly related to the trust mechanism, If the contract believes in the wrong security mechanism, LP will not get paid

   The credit mechanism is as follows:

   1. In the loan contract, there is an open interface. Anyone can mortgage a txhash interval in the dest contract. The mortgage fund is 10% of the total amount of the interval. Wait for a dispute period. If you place a bet on fork, it is considered that if the credit reaches 100, you can borrow 100% and return the mortgage. The dispute period may be 30 minutes, or it may be calculated based on the total amount of the interval.
   2. In the thread of mortgage for disagreement, the two can bet successively at a fixed amount to extend the dispute time. If both parties stop betting, after the dispute time is reached, the bet with more bet amount wins, and the winning fork reaches 100% 's credit. 60% of the total bet amount of the failed fork will be rewarded to the winner, 30% will be rewarded to the LP of the loan contract, and 10% will be destroyed or used for other purposes.
   3. The bet amount cannot exceed 120% of the total amount of the interval, and the longest dispute period cannot exceed the withdrawal time of the source
   4. During the dispute period, you can continue to pledge for the new txhash interval. The pledge in the same fork extension line can be added to the PK before the end of the dispute. If the fork extension line is not, it will not be included in the dispute competition.

---

OLD README

## [Rule of the Bounty](https://gitcoin.co/issue/gitcoinco/skunkworks/253/100027342)

> This is a bounty to implement @vbuterin's idea of a decentralized cross-layer-2 bridge.
>
> Idea described in more detail here: https://notes.ethereum.org/@vbuterin/cross_layer_2_bridges
>
> The prize for this bounty is one winner who gets 10 ETH and an introduction to the EF Grants Team. At our discretion, we may reward secondary prizes if (and only if) there are multiple high quality submissions.
>
> How it works:
>
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

Name: Belt-Bridge

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
3. rewards = (currentBindingHashOnionIndex - lastBindedHashOnionIndex) \* BASE_BIND_FEE.
4. Anyone can be a bonder,no censorship.

Sender's Rules:

1. Work flow:

   1. Call source's function transfer(transferData), paymentAmount = destAmout + Fees_to_market_makers + BASE_BIND_FEE.

   2. Wait a few time , market maker transfers destAmout back at dest.

      or

   3. Wait source's withdraw time , receive the destAmout + Fees_to_market_makers from the dest contract.

2. As long as the sender places the transferData, his expectations will be fulfilled.

market_makers' Rules:

1. Work flow:

   1. Observe the newly added transferData in source off-chain.
   2. In dest: Submit only new transferData or both submit and transfer to destination address.
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
   > The credit mechanism is as follows:
   >
   > 1. In the loan contract, there is an open interface. Anyone can mortgage a txhash interval in the dest contract. The mortgage fund is 10% of the total amount of the interval. Wait for a dispute period. If you place a bet on fork, it is considered that if the credit reaches 100, you can borrow 100% and return the mortgage. The dispute period may be 30 minutes, or it may be calculated based on the total amount of the interval.
   >
   > 2. In the thread of mortgage for disagreement, the two can bet successively at a fixed amount to extend the dispute time. If both parties stop betting, after the dispute time is reached, the bet with more bet amount wins, and the winning fork reaches 100% 's credit. 60% of the total bet amount of the failed fork will be rewarded to the winner, 30% will be rewarded to the LP of the loan contract, and 10% will be destroyed or used for other purposes.
   > 3. The bet amount cannot exceed 120% of the total amount of the interval, and the longest dispute period cannot exceed the withdrawal time of the source
   > 4. During the dispute period, you can continue to pledge for the new txhash interval. The pledge in the same fork extension line can be added to the PK before the end of the dispute. If the fork extension line is not, it will not be included in the dispute competition.

4. Market Maker with Response Time Commitment with Deposit

5. Cross domain Dex, open protocal

6. Multi-Coin

7. Multi-Domain

---

To accomplish this 4-step function, there are some general design principles:

1. Try to optimize the gas consumption in each process
2. Maintain maximum openness
3. Reduce governance and scrutiny
4. The rules set can promote the motivation of each role, and make the process smooth and safe
5. Set rules against malicious behavior that do not burden normal behavior
6. Establish to overcome the 7-day withdrawalTime waiting period and improve the efficiency of the use of funds
7. Make full use of the feature that Layer2 can obtain enough data through Roothash+Proof
