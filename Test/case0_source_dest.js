/*
test just sourceContract and destContract on one provider
*/

require('dotenv').config()

const requireEnvVariables = envVars => {
    for (const envVar of envVars) {
      if (!process.env[envVar]) {
        throw new Error(`Error: set your '${envVar}' environmental variable `)
      }
    }
    console.log('Environmental variables properly set 👍')
}

requireEnvVariables(['DEVNET_PRIVKEY', 'L2RPC', 'L1RPC'])


// Provider 
const l1Provider = new providers.JsonRpcProvider(process.env.L1RPC)

// master address
const walletPrivateKey_Master = process.env.DEVNET_PRIVKEY
const L1deployWallet = new Wallet(walletPrivateKey_Master, l1Provider)

// sender = master = maker = bonder
const senderWallet = L1deployWallet
const masterWallet = L1deployWallet
const makerWallet = L1deployWallet
const bonderWallet = L1deployWallet

// deploy 1 Token contract 
const L1DappToken = await (
    await ethers.getContractFactory('DappToken')
).connect(L1deployWallet)
const l1DappToken = await L1DappToken.deploy(1000000000000000)
await l1DappToken.deployed()

// deploy 2 contract 
const SourceContract = await (
    await ethers.getContractFactory('SourceContract')
).connect(L1deployWallet)
const sourceContract = await SourceContract.deploy(1000000000000000)
await sourceContract.deployed()
console.log('Deployed! sourceContract address:',sourceContract.address)

const DestContract = await (
    await ethers.getContractFactory('DestinationContract')
).connect(L1deployWallet)
const destContract = await DestContract.deploy(1000000000000000)
await destContract.deployed()
console.log('Deployed! destContract address:',destContract.address)

