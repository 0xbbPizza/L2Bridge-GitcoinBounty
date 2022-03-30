import { task } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import * as fs from 'fs';
import "hardhat-gas-reporter";
import "@nomiclabs/hardhat-etherscan"; 

import * as dotenv from "dotenv";
dotenv.config({ path: __dirname+'/.env' });

const privateKeyPath = './generated/PrivateKey.secret';
const getPrivateKey = (): string[] => {
  try {
    return fs.readFileSync(privateKeyPath).toString().trim().split("\n");
  } catch (e) {
    if (process.env.HARDHAT_TARGET_NETWORK !== 'localhost') {
      console.log('☢️ WARNING: No PrivateKey file created for a deploy account. Try `yarn run generate` and then `yarn run account`.');
    }
  }
  return [''];
};

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(await account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

export default {
  solidity: "0.8.4",
  // gasReporter: {
  //   currency: 'USD',
  //   gasPrice: 21
  // }
  networks: {
    localhost: {
      url: 'http://localhost:8545',
    },
    rinkeby: {
      url: process.env.rinkebyRPC, // <---- YOUR INFURA ID! (or it won't work)
      accounts: getPrivateKey(),
    },
    rinkebyArbitrum: {
      url: "https://rinkeby.arbitrum.io/rpc",
      accounts: getPrivateKey()
      // companionNetworks: {
      //   l1: "rinkeby",
      // },
    },
    kovanOptimism: {
      url: "https://kovan.optimism.io",
      accounts: getPrivateKey()
      // companionNetworks: {
      //   l1: "kovan",
      // },
    }
  },
  etherscan: {
    // Your API key for Etherscan
    apiKey: process.env.etherscanAPI // <---- "YOUR_ETHERSCAN_API_KEY"
  }
};