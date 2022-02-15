/*
test full step
*/

// import 



// wallet 

// 3 Provider and 3 master Wallet and 2 sender wallet and 2 maker wallet


const l1Provider = new providers.JsonRpcProvider(process.env.L1RPC)
const arbProvider = new providers.JsonRpcProvider(process.env.L2RPC)
const opProvider = new providers.JsonRpcProvider(process.env.L2RPC)

// deploy
const walletPrivateKey_Master = process.env.DEVNET_PRIVKEY
const l1Wallet = new Wallet(walletPrivateKey_Master, l1Provider)
const arbWallet = new Wallet(walletPrivateKey_Master, l2Provider)
const opWallet = new Wallet(walletPrivateKey_Master, l2Provider)

// sender
const senderWalletList = process.env.DEVNET_PRIVKEY
const senderWallet = new Wallet(walletPrivateKey_Master, l2Provider)

// maker
const makerWalletList = process.env.DEVNET_PRIVKEY
const makerWallet = new Wallet(walletPrivateKey_Master, l2Provider)

// bonder
const bonderWallet = process.env.DEVNET_PRIVKEY
const bonderWallet = new Wallet(walletPrivateKey_Master, l2Provider)

// deploy 3 Token contract 

// deploy 3 contract 
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

const L1Contract = await (
    await ethers.getContractFactory('DappToken')
).connect(opWallet)
const l1Contract = await L1Contract.deploy(1000000000000000)
await l1Contract.deployed()
console.log('Deployed! L1Contract address:', l1Contract.address)

// set 3 contract
// - SourceContract`s dest is L1 , bridge address is A
// - L1`s dest is OP, bridge address is B

// sender call sourceContract - transfer(transferData)


// maker call DestContract - claim(transferData,txIndex, forkTxIndex ,forkId)


// bonder call 
// - sourceContract - extractHashOnionAndBalance()
// - waiting withdraw time  canUse L1TestMock
// - l1 - sendHashOnionAndBalancetoL2()  -> call destContract bonder