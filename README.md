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

