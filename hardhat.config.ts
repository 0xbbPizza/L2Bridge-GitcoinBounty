import { task } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import * as fs from "fs";
import "hardhat-gas-reporter";
import "@nomiclabs/hardhat-etherscan";

import * as dotenv from "dotenv";
dotenv.config({ path: __dirname + "/.env" });

const privateKeyPath = "./generated/PrivateKey.secret";
const getPrivateKey = (): string[] => {
  try {
    return fs.readFileSync(privateKeyPath).toString().trim().split("\n");
  } catch (e) {
    if (process.env.HARDHAT_TARGET_NETWORK !== "localhost") {
      console.log(
        "☢️ WARNING: No PrivateKey file created for a deploy account. Try `yarn run generate` and then `yarn run account`."
      );
    }
  }
  return [""];
};

const mnemonicPath = "./generated/mnemonic.secret";
const getMnemonic = (): string => {
  try {
    return fs.readFileSync(mnemonicPath).toString().trim();
  } catch (e) {
    if (process.env.HARDHAT_TARGET_NETWORK !== "localhost") {
      console.log(
        "☢️ WARNING: No mnemonic file created for a deploy account. Try `yarn run generate` and then `yarn run account`."
      );
    }
  }
  return "";
};

const getAcounts = (): any => {
  if (process.env.accountType == "PrivateKey") {
    return getPrivateKey();
  } else {
    return {
      mnemonic: getMnemonic(),
    };
  }
};

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(await account.address);
  }
});

task("accountsBalance", "Account eth balance", async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    let balance = await account.getBalance();

    console.log(await account.address, hre.ethers.utils.formatEther(balance));
  }
});

task("GBAccounts", "Give balance to Account", async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  const account1Amount = await accounts[0].getBalance();
  const giveAmount = account1Amount.div(2 * accounts.length);

  // accounts[0].transfer(account1Amount/)

  for (const account of accounts) {
    let balance = await account.getBalance();
    let address = await account.address;
    if (balance.eq(0)) {
      const tx = accounts[0].sendTransaction({
        to: address,
        value: giveAmount,
      });
    }
    balance = await account.getBalance();
    console.log(address, balance);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

export default {
  solidity: "0.8.4",
  gasReporter: {
    currency: "USD",
    gasPrice: 21,
    enabled: process.env.REPORT_GAS ? true : false,
  },
  mocha: {
    timeout: 6000000
  },
  networks: {
    mainnet: {
      url: process.env.mainnetRPC,
      accounts: getPrivateKey(),
    },
    rinkeby: {
      url: process.env.rinkebyRPC,
      accounts: getPrivateKey(),
    },

    arbitrum: {
      url: process.env.arbitrumRPC,
      accounts: getPrivateKey(),
    },
    rinkebyArbitrum: {
      url: process.env.rinkebyArbitrumRPC,
      accounts: getPrivateKey(),
    },

    polygon: {
      url: process.env.polygonRPC,
      accounts: getPrivateKey(),
    },
    goerliPolygon: {
      url: process.env.goerliPolygonRPC,
      accounts: getPrivateKey(),
    },

    optimism: {
      url: process.env.optimismRPC,
      accounts: getPrivateKey(),
    },
    kovanOptimism: {
      url: process.env.kovanOptimismRPC,
      accounts: getPrivateKey(),
    },
  },
  // gasReporter: {
  //   enabled: process.env.REPORT_GAS !== undefined,
  //   currency: "USD",
  // },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY,
      rinkeby: process.env.ETHERSCAN_API_KEY,

      arbitrumOne: process.env.ARBISCAN_API_KEY,
      arbitrumTestnet: process.env.ARBISCAN_API_KEY,
    },
  },
};
