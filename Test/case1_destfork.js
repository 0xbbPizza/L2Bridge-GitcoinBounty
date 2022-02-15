/*
test just sourceContract and destContract on one provider
*/

// import 



// wallet 

// 1 Provider 
const l1Provider = new providers.JsonRpcProvider(process.env.L1RPC)


// deploy
const walletPrivateKey_Master = process.env.DEVNET_PRIVKEY
const l1Wallet = new Wallet(walletPrivateKey_Master, l1Provider)

// sender
const senderWalletList = process.env.DEVNET_PRIVKEY
const senderWallet = new Wallet(walletPrivateKey_Master, l2Provider)

// maker
const makerWalletList = process.env.DEVNET_PRIVKEY
const makerWallet = new Wallet(walletPrivateKey_Master, l2Provider)

// bonder
const bonderWallet = process.env.DEVNET_PRIVKEY
const bonderWallet = new Wallet(walletPrivateKey_Master, l2Provider)

// deploy 1 Token contract 
const L1DappToken = await (
    await ethers.getContractFactory('DappToken')
).connect(l1Wallet)
const l1DappToken = await L1DappToken.deploy(1000000000000000)
await l1DappToken.deployed()

// deploy 2 contract 
const SourceContract = await (
    await ethers.getContractFactory('DappToken')
).connect(arbWallet)
const sourceContract = await SourceContract.deploy(1000000000000000)
await sourceContract.deployed()
console.log('Deployed! sourceContract address:',sourceContract.address)

const DestContract = await (
    await ethers.getContractFactory('DappToken')
).connect(opWallet)
const destContract = await DestContract.deploy(1000000000000000)
await destContract.deployed()
console.log('Deployed! destContract address:',destContract.address)


// set 3 contract
// - SourceContract`s dest is destContract

// sender call sourceContract - transfer(transferData)

// maker call DestContract - claim(transferData,txIndex, forkTxIndex ,forkId)


// bonder call 
// - sourceContract - extractHashOnionAndBalance()
// - call destContract bonder