// import "ethers";
import { expect } from "chai";
import { BigNumber, Contract, Signer } from "ethers";
import { ethers } from "hardhat";
import { generateForkKey } from "./utils";

const DEPOSIT_MFORK_UNITED_WORK_INDEX = 2 ** 16 - 1;
const DEPOSIT_SCALE = 10;

describe("sourceToDest", function () {
  let accounts: Signer[];
  let fakeToken: Contract;
  let source: Contract;
  let dest: Contract;
  let poolToken: Contract;
  let hashOnion: string;
  let sourceAmount: BigNumber;
  let users: Signer[];
  let makers: Signer[];
  let endorser: Signer;
  let denyer: Signer;
  let txs: [string, BigNumber, BigNumber][];
  let ONEFORK_MAX_LENGTH: any;
  // let sourceToDestAmount: any;
  let chainId: number;
  const forkDatasArr: {
    forkIndex: number;
    forkKey: string;
    wrongtxHash: string[];
  }[][] = [];

  const addForkData = (
    chainId: number,
    sourOnion: string,
    forkIndex = 0,
    wrongtxHash: string[] = []
  ) => {
    const forkKey = generateForkKey(chainId, sourOnion, forkIndex);
    const fork = { forkKey, forkIndex, wrongtxHash };
    if (forkIndex == 0) {
      forkDatasArr.push([fork]);
    } else {
      forkDatasArr[forkDatasArr.length - 1].push(fork);
    }
    return forkKey;
  };

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
      let amount = i * 10000000;
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

    // Deploy PoolToken
    const PoolToken = await ethers.getContractFactory("PoolToken");
    poolToken = await PoolToken.deploy(dest.address);
    await poolToken.deployed();
    console.log("PoolToken address:", poolToken.address);
    await dest.bindPoolTokenAddress(poolToken.address);

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
    users = accounts.slice(1, 12);
    makers = accounts.slice(13);
    endorser = accounts[14];
    denyer = accounts[15];
    txs = [];

    // Depositer extra amount
    const extraAmount = 2000000000000;
    await fakeToken.transfer(await endorser.getAddress(), extraAmount);
    await fakeToken.transfer(await denyer.getAddress(), extraAmount);
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

  it("mFork and Claim on dest", async function () {
    expect(ONEFORK_MAX_LENGTH).to.equal(await dest.ONEFORK_MAX_LENGTH());

    const committer: Signer = accounts[0];
    const committerAddress = await committer.getAddress();
    const amount: BigNumber = await fakeToken.balanceOf(committerAddress);

    await dest.becomeCommiter();
    await fakeToken.approve(dest.address, amount);

    let forkKey = addForkData(chainId, ethers.constants.HashZero);
    let sourOnion = ethers.constants.HashZero;
    let destOnion = ethers.constants.HashZero;

    // Refresh sourOnion & destOnion with tx
    const refreshWorkOnions = (tx: [string, BigNumber, BigNumber]) => {
      const txEncode = ethers.utils.defaultAbiCoder.encode(
        ["address", "uint", "uint"],
        tx
      );
      const txHash = ethers.utils.keccak256(txEncode);
      const onionEncode = ethers.utils.defaultAbiCoder.encode(
        ["bytes32", "bytes32"],
        [sourOnion, txHash]
      );
      sourOnion = ethers.utils.keccak256(onionEncode);
      const destOnionEncode = ethers.utils.defaultAbiCoder.encode(
        ["bytes32", "bytes32", "address"],
        [destOnion, sourOnion, committerAddress]
      );
      destOnion = ethers.utils.keccak256(destOnionEncode);

      console.warn("onionEncode: ", sourOnion, ", destOnion: ", destOnion);
    };

    for (let i = 0; i < txs.length; i++) {
      const index = i % ONEFORK_MAX_LENGTH;

      if (index == 0) {
        console.warn(
          "----------------------------------------------------------------zFork----------------------------------------------------------------"
        );
        refreshWorkOnions(txs[i]);

        await dest.zFork(
          chainId,
          forkKey,
          txs[i][0],
          txs[i][1],
          txs[i][2],
          true
        );
        forkKey = addForkData(chainId, sourOnion);
      } else {
        const mockMFork = index == 3;
        const transferData = {
          destination: txs[i][0],
          amount: txs[i][1],
          fee: txs[i][2],
        };

        if (!mockMFork) {
          // Normal
          refreshWorkOnions(txs[i]);
          await dest.claim(chainId, forkKey, index, [transferData], [true]);
        } else {
          // Mock wrong
          await dest.claim(
            chainId,
            forkKey,
            index,
            [
              {
                ...transferData,
                fee: 10, // Mock wrong transfer
              },
            ],
            [true]
          );

          // mFork
          await dest.becomeCommiter();
          await dest.mFork(
            chainId,
            sourOnion,
            destOnion,
            index,
            transferData,
            true
          );

          console.warn(
            "----------------------------------------------------------------mFork----------------------------------------------------------------"
          );
          refreshWorkOnions(txs[i]);

          forkKey = addForkData(chainId, sourOnion, index);
        }
      }

      const fork = await dest.hashOnionForks(forkKey);

      expect(fork.onionHead).to.equal(sourOnion);
      expect(fork.destOnionHead).to.equal(destOnion);
    }

    let userAddress = await users[2].getAddress();
    expect(await fakeToken.balanceOf(userAddress)).to.equal(0);
    let userAddress2 = await users[3].getAddress();
    let user2Amount = txs[1][1].add(txs[2][1]);
    expect(await fakeToken.balanceOf(userAddress2)).to.equal(user2Amount);
  });

  it("Deposit mForks", async function () {
    const endorserDest = dest.connect(endorser);
    await fakeToken
      .connect(endorser)
      .approve(dest.address, ethers.constants.MaxUint256);

    let endorserBalancePrev = await fakeToken.balanceOf(
      await endorser.getAddress()
    );
    let currentHashOnion = ethers.constants.HashZero;
    let forkHashOnion = currentHashOnion;
    let prevForkKey = generateForkKey(chainId, currentHashOnion, 0);
    let forkAllAmount = BigNumber.from(0);
    const committers = [];
    const transferDatas = [];
    let fdi = 1;
    for (let i = 0; i < txs.length; i++) {
      const tx = txs[i];
      committers.push(await accounts[0].getAddress());
      transferDatas.push({ destination: tx[0], amount: tx[1], fee: tx[2] });
      forkAllAmount = forkAllAmount.add(tx[1]).add(tx[2]);

      // Calculate hashOnion
      const txHash = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(["address", "uint", "uint"], tx)
      );
      currentHashOnion = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["bytes32", "bytes32"],
          [currentHashOnion, txHash]
        )
      );

      // When fork’s first tx
      if (i % ONEFORK_MAX_LENGTH == 0) {
        forkHashOnion = currentHashOnion;
      }

      // When fork’s last tx
      if (i % ONEFORK_MAX_LENGTH == ONEFORK_MAX_LENGTH - 1) {
        await endorserDest.depositMForks(
          chainId,
          prevForkKey,
          forkDatasArr[fdi],
          transferDatas,
          committers
        );

        prevForkKey = generateForkKey(
          chainId,
          forkHashOnion,
          DEPOSIT_MFORK_UNITED_WORK_INDEX
        );

        // Test
        const endorserBalanceCurrent = await fakeToken.balanceOf(
          await endorser.getAddress()
        );
        expect(endorserBalancePrev.sub(endorserBalanceCurrent)).to.equal(
          forkAllAmount.div(DEPOSIT_SCALE)
        );

        endorserBalancePrev = endorserBalanceCurrent;
        fdi++;
        committers.length = 0;
        transferDatas.length = 0;
        forkAllAmount = BigNumber.from(0);
      }
    }
  });

  it("EarlyBond", async function () {
    const endorserDest = dest.connect(endorser);
    await fakeToken
      .connect(endorser)
      .approve(dest.address, ethers.constants.MaxUint256);

    // let endorserBalancePrev = await fakeToken.balanceOf(
    //   await endorser.getAddress()
    // );
    let currentHashOnion = ethers.constants.HashZero;
    let forkHashOnion = currentHashOnion;
    let prevForkKey = generateForkKey(chainId, currentHashOnion, 0);
    let forkAllAmount = BigNumber.from(0);
    const committers = [];
    const transferDatas = [];
    let fdi = 1;
    for (let i = 0; i < txs.length; i++) {
      const tx = txs[i];
      committers.push(await accounts[0].getAddress());
      transferDatas.push({ destination: tx[0], amount: tx[1], fee: tx[2] });
      forkAllAmount = forkAllAmount.add(tx[1]).add(tx[2]);

      // Calculate hashOnion
      const txHash = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(["address", "uint", "uint"], tx)
      );
      currentHashOnion = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["bytes32", "bytes32"],
          [currentHashOnion, txHash]
        )
      );

      // When fork’s first tx
      if (i % ONEFORK_MAX_LENGTH == 0) {
        forkHashOnion = currentHashOnion;
      }

      // When fork’s last tx
      if (i % ONEFORK_MAX_LENGTH == ONEFORK_MAX_LENGTH - 1) {
        // await endorserDest.depositMForks(
        //   chainId,
        //   prevForkKey,
        //   forkDatasArr[fdi],
        //   transferDatas,
        //   committers
        // );

        const forkKey = generateForkKey(
          chainId,
          forkHashOnion,
          DEPOSIT_MFORK_UNITED_WORK_INDEX
        );

        await dest.earlyBond(prevForkKey, forkKey, transferDatas, committers);

        // Test
        // const endorserBalanceCurrent = await fakeToken.balanceOf(
        //   await endorser.getAddress()
        // );
        // expect(endorserBalancePrev.sub(endorserBalanceCurrent)).to.equal(
        //   forkAllAmount.div(DEPOSIT_SCALE)
        // );

        // endorserBalancePrev = endorserBalanceCurrent;
        prevForkKey = forkKey;
        fdi++;
        committers.length = 0;
        transferDatas.length = 0;
        forkAllAmount = BigNumber.from(0);
      }
    }
  });
});
