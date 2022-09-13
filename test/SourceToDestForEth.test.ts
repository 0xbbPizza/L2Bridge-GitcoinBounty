import { BigNumber, constants, Contract, Signer } from "ethers";
import { ethers } from "hardhat";
import { expect } from "chai";
import { generateForkKey, getGasUsed } from "./utils";

describe("sourceToDest", function () {
  let accounts: Signer[];
  let tokenAddress: any;
  let source: Contract;
  let dest: Contract;
  let hashOnion: string;
  let sourceAmount: BigNumber;
  let users: Signer[];
  let makers: Signer[];
  let txs: [string, BigNumber, BigNumber][];
  let ONEFORK_MAX_LENGTH: any;
  // let sourceToDestAmount: any;
  let chainId: number;

  before(async function () {
    accounts = await ethers.getSigners();

    chainId = await accounts[0].getChainId();
    console.log("chainId", chainId);

    tokenAddress = constants.AddressZero;
    let dTokenAddress = "0x3484fa63622fdBc33BD709B3d23b68755C4642C1";

    // 3
    const Relay = await ethers.getContractFactory("Relay");
    const relay = await Relay.deploy();
    await relay.deployed();
    console.log("relay Address:", relay.address);

    // 2
    const Dock_Mainnet = await ethers.getContractFactory("Dock_MainNet");
    const dock_Mainnet = await Dock_Mainnet.deploy(relay.address);
    await dock_Mainnet.deployed();
    console.log("dock_Mainnet Address:", dock_Mainnet.address);

    // set 2 to 3
    await relay.addDock(dock_Mainnet.address, chainId);

    // deploy dest contract 4
    const Dest = await ethers.getContractFactory("NewDestination");
    dest = await Dest.deploy(tokenAddress, dTokenAddress, dock_Mainnet.address);
    await dest.deployed();
    console.log("destContract Address", dest.address);

    // deploy source contract 1
    const Source = await ethers.getContractFactory("SourceContract");
    source = await Source.deploy(
      tokenAddress,
      dock_Mainnet.address,
      dest.address
    ); //mock
    await source.deployed();
    ONEFORK_MAX_LENGTH = await source.ONEFORK_MAX_LENGTH();
    console.log("sourceContract Address", source.address);

    // add 1 to 4
    await dest.addDomain(chainId, source.address);

    // add 4 to 1
    await source.addDestDomain(chainId, dest.address);

    sourceAmount = BigNumber.from(0);
    users = accounts.slice(1, 17);
    makers = accounts.slice(18);
    txs = [];
  });

  async function getSourceHashOnion(_chainId: number) {
    let domainStruct = await source.chainId_Onions(_chainId);
    return domainStruct[1];
  }

  it("transfer on SourceContract, change hashOnion", async function () {
    const amount = ethers.utils.parseEther("10");
    const beforeUserETHBalance = await users[1].getBalance();
    const fee = BigNumber.from(0);
    const allAmount = amount.add(fee);
    const address1 = await users[1].getAddress();

    hashOnion = ethers.constants.HashZero;

    expect(await getSourceHashOnion(chainId)).to.equal(hashOnion);

    const responce = await source
      .connect(users[1])
      .transfer(chainId, amount, fee, { value: allAmount });
    const tx = await responce.wait();
    const gasUsed = getGasUsed(tx);
    const afterUserETHBalance = await users[1].getBalance();

    expect(beforeUserETHBalance.sub(allAmount).sub(gasUsed)).eq(
      afterUserETHBalance
    );

    sourceAmount = sourceAmount.add(amount);

    const destAmount = await ethers.provider.getBalance(dest.address);

    expect(destAmount).to.equal(sourceAmount);

    const data1 = ethers.utils.defaultAbiCoder.encode(
      ["address", "uint", "uint"],
      [address1, amount, fee]
    );
    const oneTxHash = ethers.utils.keccak256(data1);
    const dataHash_1 = ethers.utils.defaultAbiCoder.encode(
      ["bytes32", "bytes32"],
      [hashOnion, oneTxHash]
    );
    hashOnion = ethers.utils.keccak256(dataHash_1);

    expect(await getSourceHashOnion(chainId)).to.equal(hashOnion);

    txs.push([address1, amount, fee]);
  });

  it("transferWithDest on SourceContract, change hashOnion", async function () {
    const user = users[2];
    const allAmount = ethers.utils.parseEther("10");
    const fee = BigNumber.from(10000);
    const amount = allAmount.sub(fee);
    const destUserAddress = await users[3].getAddress();
    const beforeUserETHBalance = await user.getBalance();

    sourceAmount = sourceAmount.add(allAmount);

    const responce = await source
      .connect(user)
      .transferWithDest(chainId, destUserAddress, amount, fee, {
        value: allAmount,
      });
    const tx = await responce.wait();
    const gasUsed = getGasUsed(tx);
    const destAmount = await ethers.provider.getBalance(dest.address);
    const afterUserETHBalance = await user.getBalance();
    console.log("afterUserETHBalance: ", afterUserETHBalance);

    expect(beforeUserETHBalance.sub(allAmount).sub(gasUsed)).eq(
      afterUserETHBalance
    );
    expect(destAmount).to.equal(sourceAmount);

    const txEncode = ethers.utils.defaultAbiCoder.encode(
      ["address", "uint", "uint"],
      [destUserAddress, amount, fee]
    );
    const txHash = ethers.utils.keccak256(txEncode);
    const onionEncode = ethers.utils.defaultAbiCoder.encode(
      ["bytes32", "bytes32"],
      [hashOnion, txHash]
    );
    hashOnion = ethers.utils.keccak256(onionEncode);

    expect(await getSourceHashOnion(chainId)).to.equal(hashOnion);
    txs.push([destUserAddress, amount, fee]);
  });

  it("creat long hashOnion on SourceContract", async function () {
    let user: Signer;
    let userAddress: string;
    let allAmount: BigNumber;
    let fee: BigNumber;
    let amount: BigNumber;

    for (let i = 3; i < users.length; i++) {
      user = users[i];
      userAddress = await users[i].getAddress();

      allAmount = ethers.utils.parseEther("10");
      fee = BigNumber.from(i * 10000);
      amount = allAmount.sub(fee);
      sourceAmount = sourceAmount.add(allAmount);
      const beforeUserETHBalance = await user.getBalance();

      const responce = await source
        .connect(user)
        .transfer(chainId, amount, fee, { value: allAmount });
      const tx = await responce.wait();
      const gasUsed = getGasUsed(tx);
      const afterUserETHBalance = await user.getBalance();
      const destAmount = await ethers.provider.getBalance(dest.address);

      expect(beforeUserETHBalance.sub(allAmount).sub(gasUsed)).eq(
        afterUserETHBalance
      );
      expect(destAmount).to.equal(sourceAmount);

      const txEncode = ethers.utils.defaultAbiCoder.encode(
        ["address", "uint", "uint"],
        [userAddress, amount, fee]
      );
      const txHash = ethers.utils.keccak256(txEncode);
      const onionEncode = ethers.utils.defaultAbiCoder.encode(
        ["bytes32", "bytes32"],
        [hashOnion, txHash]
      );
      hashOnion = ethers.utils.keccak256(onionEncode);

      expect(await getSourceHashOnion(chainId)).to.equal(hashOnion);
      txs.push([userAddress, amount, fee]);
    }
  });

  it("only zFork and Claim on dest", async function () {
    expect(ONEFORK_MAX_LENGTH).to.equal(await dest.ONEFORK_MAX_LENGTH());
    const committer: Signer = accounts[0];
    const beforeZForkUser3Balance = await users[3].getBalance();
    await dest.becomeCommiter();
    let index = 0;
    let sourOnion = ethers.constants.HashZero;
    let destOnion = ethers.constants.HashZero;
    let forkKey = generateForkKey(chainId, sourOnion, 0);

    for (let i = 0; i < txs.length; i++) {
      const txEncode = ethers.utils.defaultAbiCoder.encode(
        ["address", "uint", "uint"],
        txs[i]
      );
      const txHash = ethers.utils.keccak256(txEncode);
      const onionEncode = ethers.utils.defaultAbiCoder.encode(
        ["bytes32", "bytes32"],
        [sourOnion, txHash]
      );
      sourOnion = ethers.utils.keccak256(onionEncode);
      const destOnionEncode = ethers.utils.defaultAbiCoder.encode(
        ["bytes32", "bytes32", "address"],
        [destOnion, sourOnion, await committer.getAddress()]
      );
      destOnion = ethers.utils.keccak256(destOnionEncode);

      index = i % ONEFORK_MAX_LENGTH;

      if (index == 0) {
        await dest.zFork(
          chainId,
          forkKey,
          txs[i][0],
          txs[i][1],
          txs[i][2],
          true
        );
        forkKey = generateForkKey(chainId, sourOnion, 0);
      } else {
        await dest.claim(
          chainId,
          forkKey,
          index,
          [
            {
              destination: txs[i][0],
              amount: txs[i][1],
              fee: txs[i][2],
            },
          ],
          [true]
        );
      }

      const fork = await dest.hashOnionForks(forkKey);
      expect(fork.onionHead).to.equal(sourOnion);
      expect(fork.destOnionHead).to.equal(destOnion);
    }

    const fork = await dest.hashOnionForks(forkKey);
    expect(fork.onionHead).to.equal(hashOnion);

    const afterZForkUser3Balance = await users[3].getBalance();
    const user3ReceiveAmount = txs[1][1].add(txs[2][1]);
    expect(afterZForkUser3Balance.sub(beforeZForkUser3Balance)).to.equal(
      user3ReceiveAmount
    );
  });

  // it("only zbond on dest", async function () {
  //   await source.extractHashOnion(chainId);
  //   const hashOnionInfo = await dest.getHashOnionInfo(chainId);
  //   expect(hashOnionInfo.sourceHashOnion).eq(hashOnion);
  //   expect(hashOnionInfo.onWorkHashOnion).eq(hashOnion);

  //   let sourOnion = ethers.constants.HashZero;
  //   let keySourOnions = [sourOnion];
  //   let index: number;
  //   let transferDatas = [];
  //   let commitAddresslist = [];

  //   for (let i = 0; i < txs.length; i++) {
  //     const txEncode = ethers.utils.defaultAbiCoder.encode(
  //       ["address", "uint", "uint"],
  //       txs[i]
  //     );
  //     const txHash = ethers.utils.keccak256(txEncode);
  //     const onionEncode = ethers.utils.defaultAbiCoder.encode(
  //       ["bytes32", "bytes32"],
  //       [sourOnion, txHash]
  //     );
  //     sourOnion = ethers.utils.keccak256(onionEncode);
  //     index = i % ONEFORK_MAX_LENGTH;
  //     if (index == 0) {
  //       keySourOnions.push(sourOnion);
  //     }
  //     transferDatas.push({
  //       destination: txs[i][0],
  //       amount: txs[i][1],
  //       fee: txs[i][2],
  //     });
  //     commitAddresslist.push(accounts[0].getAddress());
  //   }

  //   let sourceAmount = await ethers.provider.getBalance(dest.address);
  //   let bonderAmount = accounts[0].getBalance();

  //   for (let i = keySourOnions.length - 1; i > 0; i--) {
  //     let x = (i - 1) * ONEFORK_MAX_LENGTH;
  //     let y = i * ONEFORK_MAX_LENGTH;
  //     // console.log(forkIndex, preForkIndex)
  //     // console.log(await getDestFork(chainId,keySourOnion[i-1],0))
  //     const prevForkKey = generateForkKey(chainId, keySourOnions[i - 1], 0);
  //     const forkKey = generateForkKey(chainId, keySourOnions[i], 0);

  //     await dest.zbond(
  //       chainId,
  //       prevForkKey,
  //       forkKey,
  //       transferDatas.slice(x, y),
  //       commitAddresslist.slice(x, y)
  //     );
  //   }
  //   // console.log(await fakeToken.balanceOf(accounts[0].getAddress()))
  //   // console.log(await fakeToken.balanceOf(dest.address))
  //   // console.log(bonderAmount)
  //   // console.log(sourceAmount)
  //   // expect(await fakeToken.balanceOf(dest.address)).to.equal(0);
  //   // expect(await fakeToken.balanceOf(accounts[0].getAddress())).to.equal(bonderAmount.sub(sourceAmount))
  // });
});
