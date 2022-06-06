import { ethers } from "hardhat";
import { Signer, BigNumber, Contract, utils } from "ethers";
// import "ethers";
import { expect } from "chai";
import { generateForkKey } from "./utils";

describe("sourceToDest", function () {
  let accounts: Signer[];
  let fakeToken: Contract;
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

    // deploy token contract
    const FakeToken = await ethers.getContractFactory("BasicToken");
    fakeToken = await FakeToken.deploy(ethers.utils.parseEther("80000"));
    await fakeToken.deployed();
    console.log("FakeToken address:", fakeToken.address);

    // set account token amount
    for (let i = 1; i < accounts.length; i++) {
      let amount = i * 1000000000;
      await fakeToken.transfer(await accounts[i].getAddress(), amount);
    }

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
    dest = await Dest.deploy(fakeToken.address, dock_Mainnet.address);
    await dest.deployed();
    console.log("destContract Address", dest.address);

    // deploy source contract 1
    const Source = await ethers.getContractFactory("SourceContract");
    source = await Source.deploy(
      fakeToken.address,
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
    let amount = await fakeToken.balanceOf(users[1].getAddress());
    let fee = BigNumber.from(0);
    let address1 = await users[1].getAddress();

    hashOnion = ethers.constants.HashZero;

    expect(await getSourceHashOnion(chainId)).to.equal(hashOnion);

    await fakeToken.connect(users[1]).approve(source.address, amount);
    await source.connect(users[1]).transfer(chainId, amount, fee);
    expect(await fakeToken.balanceOf(address1)).to.equal(0);

    sourceAmount = sourceAmount.add(amount);

    expect(await fakeToken.balanceOf(dest.address)).to.equal(sourceAmount);

    let data1 = ethers.utils.defaultAbiCoder.encode(
      ["address", "uint", "uint"],
      [address1, amount, fee]
    );
    let oneTxHash = ethers.utils.keccak256(data1);
    let dataHash_1 = ethers.utils.defaultAbiCoder.encode(
      ["bytes32", "bytes32"],
      [hashOnion, oneTxHash]
    );
    hashOnion = ethers.utils.keccak256(dataHash_1);

    expect(await getSourceHashOnion(chainId)).to.equal(hashOnion);

    txs.push([address1, amount, fee]);
  });

  it("transferWithDest on SourceContract, change hashOnion", async function () {
    const user = users[2];
    const allAmount = await fakeToken.balanceOf(await user.getAddress());
    const fee = BigNumber.from(10000);
    const amount = allAmount.sub(fee);
    const userAddress = await user.getAddress();
    const userAddress3 = await users[3].getAddress();

    sourceAmount = sourceAmount.add(allAmount);

    await fakeToken.connect(user).approve(source.address, allAmount);
    await source
      .connect(user)
      .transferWithDest(chainId, userAddress3, amount, fee);
    expect(await fakeToken.balanceOf(userAddress)).to.equal(0);
    expect(await fakeToken.balanceOf(dest.address)).to.equal(sourceAmount);

    const txEncode = ethers.utils.defaultAbiCoder.encode(
      ["address", "uint", "uint"],
      [userAddress3, amount, fee]
    );
    const txHash = ethers.utils.keccak256(txEncode);
    const onionEncode = ethers.utils.defaultAbiCoder.encode(
      ["bytes32", "bytes32"],
      [hashOnion, txHash]
    );
    hashOnion = ethers.utils.keccak256(onionEncode);

    expect(await getSourceHashOnion(chainId)).to.equal(hashOnion);
    txs.push([userAddress3, amount, fee]);
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

      allAmount = await fakeToken.balanceOf(user.getAddress());
      fee = BigNumber.from(i * 10000);
      amount = allAmount.sub(fee);
      sourceAmount = sourceAmount.add(allAmount);

      await fakeToken.connect(user).approve(source.address, allAmount);
      await source.connect(user).transfer(chainId, amount, fee);
      expect(await fakeToken.balanceOf(userAddress)).to.equal(0);
      expect(await fakeToken.balanceOf(dest.address)).to.equal(sourceAmount);

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
    const amount: BigNumber = await fakeToken.balanceOf(
      await committer.getAddress()
    );
    await dest.becomeCommiter();
    await fakeToken.approve(dest.address, amount);
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
      expect(fork[0]).to.equal(sourOnion);
      expect(fork[1]).to.equal(destOnion);
    }

    const fork = await dest.hashOnionForks(forkKey);
    expect(fork[0]).to.equal(hashOnion);

    let userAddress = await users[2].getAddress();
    expect(await fakeToken.balanceOf(userAddress)).to.equal(0);
    let userAddress2 = await users[3].getAddress();
    let user2Amount = txs[1][1].add(txs[2][1]);
    expect(await fakeToken.balanceOf(userAddress2)).to.equal(user2Amount);
  });

  it("only zbond on dest", async function () {
    await source.extractHashOnion(chainId);
    const hashOnionInfo = await dest.getHashOnionInfo(chainId);
    expect(hashOnionInfo.sourceHashOnion).to.equal(hashOnion);
    expect(hashOnionInfo.onWorkHashOnion).to.equal(hashOnion);

    let sourOnion = ethers.constants.HashZero;
    let keySourOnions = [sourOnion];
    let index: number;
    let transferDatas = [];
    let commitAddresslist = [];

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
      index = i % ONEFORK_MAX_LENGTH;
      if (index == 0) {
        keySourOnions.push(sourOnion);
      }
      transferDatas.push({
        destination: txs[i][0],
        amount: txs[i][1],
        fee: txs[i][2],
      });
      commitAddresslist.push(accounts[0].getAddress());
    }

    let sourceAmount = await fakeToken.balanceOf(dest.address);
    let bonderAmount = await fakeToken.balanceOf(accounts[0].getAddress());
    // await fakeToken.transfer(dest.address,sourceAmount)
    // expect(await fakeToken.balanceOf(dest.address)).to.equal(sourceAmount)
    // expect(await fakeToken.balanceOf(accounts[0].getAddress())).to.equal(bonderAmount.sub(sourceAmount))
    // console.log(await fakeToken.balanceOf(accounts[0].getAddress()))
    // console.log(await fakeToken.balanceOf(dest.address))

    for (let i = keySourOnions.length - 1; i > 0; i--) {
      let x = (i - 1) * ONEFORK_MAX_LENGTH;
      let y = i * ONEFORK_MAX_LENGTH;
      // console.log(forkIndex, preForkIndex)
      // console.log(await getDestFork(chainId,keySourOnion[i-1],0))
      await dest.zbond(
        chainId,
        keySourOnions[i],
        keySourOnions[i - 1],
        transferDatas.slice(x, y),
        commitAddresslist.slice(x, y)
      );
    }
    // console.log(await fakeToken.balanceOf(accounts[0].getAddress()))
    // console.log(await fakeToken.balanceOf(dest.address))
    // console.log(bonderAmount)
    // console.log(sourceAmount)
    expect(await fakeToken.balanceOf(dest.address)).to.equal(0);
    // expect(await fakeToken.balanceOf(accounts[0].getAddress())).to.equal(bonderAmount.sub(sourceAmount))
  });

  // it("depositWithOneFork" async function () {
  //   let waitBuyForkID = []
  //   let waitBuyFork = []

  //   // choice one fork
  //   for (let i = 0; i < 10; i++){
  //     let fork = await getDestFork(chainId, forkKey, 0)
  //     if (!fork.hadBuy) {
  //       waitBuyForkID.push(i)
  //       waitBuyFork.push(fork)
  //     }
  //   }

  //   // math how many amount need deposit
  //   let depositAmount = fork.allAmount + dest.minDepositFundRate();
  //   if (depositAmount > dest.maxDepositsFunds){
  //     depositAmount = dest.maxDepositsFunds
  //   }

  //   await fakeToken.connect(users[1]).approve(dest.address,depositAmount)

  //   // call depositWtihOneFork
  //   await dest.depositWithOneFork( chainId, waitBuyForkID[0])

  //   // check deposit is ok ?
  // })
});
