// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "./libraries/Data.sol";
import "./libraries/Fork.sol";
import "./libraries/ForkDeposit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IDestinationContract.sol";
import "./MessageDock/CrossDomainHelper.sol";
import "./PTokenApprovable.sol";

import "hardhat/console.sol";

contract NewDestination is
    IDestinationContract,
    CrossDomainHelper,
    Ownable,
    PTokenApprovable
{
    using SafeERC20 for IERC20;
    using HashOnions for mapping(uint256 => HashOnions.Info);
    using Fork for mapping(bytes32 => Fork.Info);
    using ForkDeposit for mapping(bytes32 => ForkDeposit.Info);

    address private tokenAddress;

    mapping(bytes32 => Fork.Info) public hashOnionForks;
    mapping(uint256 => mapping(bytes32 => bool)) private isRespondOnions;
    mapping(uint256 => HashOnions.Info) private hashOnions;
    mapping(bytes32 => address) private onionsAddress; // !!! Conflict with using zk scheme, new scheme needs to be considered when using zk

    mapping(address => uint256) private source_chainIds;

    mapping(address => bool) private _committerDeposits; // Submitter's bond record

    mapping(bytes32 => ForkDeposit.Info) private hashOnionForkDeposits;

    uint256 public immutable ONEFORK_MAX_LENGTH = 5; // !!! The final value is 50 , the higher the value, the longer the wait time and the less storage consumption
    uint256 public immutable DEPOSIT_AMOUNT = 1 * 10**18; // !!! The final value is 2 * 10**17

    /*
	1. every LP need deposit `DEPOSIT_AMOUNT` ETH, DEPOSIT_AMOUNT = OnebondGaslimit * max_fork.length * Average_gasPrice 
	2. when LP call zfork()、mfork()、claim(). lock deposit, and unlock the preHashOnions LP's deposit. 
	3. When bonder is settling `middle fork`, will get `DEPOSIT_AMOUNT` ETH back from destContract. 
	4. LP's deposit can only be withdrawn if they are unlocked.
	5. No one wants to pay for someone else's mistakes, so the perpetrator's deposit will never be unlocked
    */

    constructor(address _tokenAddress, address _dockAddr)
        CrossDomainHelper(_dockAddr)
    {
        tokenAddress = _tokenAddress;
    }

    function _onlyApprovedSources(address _sourceSender, uint256 _sourChainId)
        internal
        view
        override
    {
        require(_sourChainId != 0, "ZERO_CHAINID");
        require(source_chainIds[_sourceSender] == _sourChainId, "NOTAPPROVE");
    }

    /*
     * call from source
     * TODO it is not already ok
     */
    function bondSourceHashOnion(uint256 chainId, bytes32 hashOnion)
        external
        sourceSafe
    {
        HashOnions.Info memory info = hashOnions[chainId];

        if (info.onWorkHashOnion == "" || info.onWorkHashOnion == hashOnion) {
            hashOnions[chainId].onWorkHashOnion = hashOnion;
        }

        hashOnions[chainId].sourceHashOnion = hashOnion;
    }

    /**
     * Add domain. Init hashOnionForks, bind source & chainId
     */
    function addDomain(uint256 chainId, address source) external onlyOwner {
        hashOnionForks.initialize(chainId, ONEFORK_MAX_LENGTH);
        source_chainIds[source] = chainId;
    }

    // TODO need deposit ETH
    function becomeCommiter() external {
        _committerDeposits[msg.sender] = true;
    }

    function getHashOnionFork(
        uint256 chainId,
        bytes32 hashOnion,
        uint16 index
    ) external view returns (Fork.Info memory) {
        bytes32 forkKey = Fork.generateForkKey(chainId, hashOnion, index);
        return hashOnionForks.getForkEnsure(forkKey);
    }

    function getHashOnionInfo(uint256 chainId)
        external
        view
        returns (HashOnions.Info memory)
    {
        return hashOnions[chainId];
    }

    /* 
        A. Ensure that a single correct fork link is present:
        There are three behaviors of commiters related to fork:
        1. Create a 0-bit fork
        2. Create a non-zero fork
        3. Add OnionHead to any Fork

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

    // if index % ONEFORK_MAX_LENGTH == 0
    function zFork(
        uint256 chainId,
        bytes32 workForkKey,
        address dest,
        uint256 amount,
        uint256 fee,
        bool _isRespond
    ) external override {
        (Fork.Info memory workFork, Fork.Info memory newFork) = hashOnionForks
            .createZFork(chainId, workForkKey, dest, amount, fee);

        if (_committerDeposits[msg.sender] == false) {
            // If same commiter, don't need deposit
            require(msg.sender == workFork.lastCommiterAddress, "a2");
        }

        // Determine whether the maker only submits or submits and responds
        if (_isRespond) {
            IERC20(tokenAddress).safeTransferFrom(msg.sender, dest, amount);
        } else {
            // !!! Whether to add the identification position of the index
            isRespondOnions[chainId][newFork.onionHead] = true;
        }

        // Locks the new committer's bond, unlocks the previous committer's bond state
        if (workFork.lastCommiterAddress != msg.sender) {
            _committerDeposits[workFork.lastCommiterAddress] = true;
            _committerDeposits[msg.sender] = false;
        }

        emit newClaim(dest, amount, fee, 0, newFork.onionHead);
    }

    // just deppend
    function claim(
        uint256 chainId,
        bytes32 workForkKey,
        uint256 _workIndex,
        Data.TransferData[] calldata _transferDatas,
        bool[] calldata _isResponds
    ) external override {
        // incoming data length is correct
        require(_transferDatas.length > 0, "a1");

        Fork.Info memory workFork = hashOnionForks.getForkEnsure(workForkKey);

        // Determine the eligibility of the submitter
        if (_committerDeposits[msg.sender] == false) {
            require(msg.sender == workFork.lastCommiterAddress, "a3");
        }

        // Determine whether someone has submitted it before. If it has been submitted by the predecessor, tx.origin thinks that the submission is incorrect and can be forked and resubmitted through forkFromInput
        // !!! Avoid duplicate submissions
        require(_workIndex == workFork.length, "b2");

        // Judge _transferDatas not to exceed the limit
        require(_workIndex + _transferDatas.length <= ONEFORK_MAX_LENGTH, "a2");

        bytes32 onionHead = workFork.onionHead;
        bytes32 destOnionHead = workFork.destOnionHead;
        uint256 allAmount = 0;
        // just append
        for (uint256 i; i < _transferDatas.length; i++) {
            onionHead = Fork.generateOnionHead(onionHead, _transferDatas[i]);
            if (_isResponds[i]) {
                IERC20(tokenAddress).safeTransferFrom(
                    msg.sender,
                    _transferDatas[i].destination,
                    _transferDatas[i].amount
                );
            } else {
                // TODO need change to transferData hash
                isRespondOnions[chainId][onionHead] = true;
            }
            destOnionHead = Fork.generateDestOnionHead(
                destOnionHead,
                onionHead,
                msg.sender
            );
            allAmount += _transferDatas[i].amount + _transferDatas[i].fee;

            emit newClaim(
                _transferDatas[i].destination,
                _transferDatas[i].amount,
                _transferDatas[i].fee,
                _workIndex + i,
                onionHead
            );
        }

        // change deposit , deposit token is ETH , need a function to deposit and with draw
        if (workFork.lastCommiterAddress != msg.sender) {
            _committerDeposits[workFork.lastCommiterAddress] = true;
            _committerDeposits[msg.sender] = false;
        }

        workFork = Fork.Info(
            0,
            onionHead,
            destOnionHead,
            allAmount + workFork.allAmount,
            _workIndex + _transferDatas.length,
            msg.sender,
            workFork.needBond,
            0
        );

        // storage
        hashOnionForks.update(workForkKey, workFork);
    }

    // if source index % ONEFORK_MAX_LENGTH != 0
    function mFork(
        uint256 chainId,
        bytes32 _lastOnionHead,
        bytes32 _lastDestOnionHead,
        uint16 _index,
        Data.TransferData calldata _transferData,
        bool _isRespond
    ) external override {
        // Determine whether tx.origin is eligible to submit
        require(_committerDeposits[msg.sender] == true, "a3");

        Fork.Info memory newFork = hashOnionForks.createMFork(
            chainId,
            _lastOnionHead,
            _lastDestOnionHead,
            _index,
            _transferData
        );

        // Determine whether the maker only submits or submits and also responds, so as to avoid the large amount of unresponsiveness of the maker and block subsequent commints
        if (_isRespond) {
            IERC20(tokenAddress).safeTransferFrom(
                msg.sender,
                _transferData.destination,
                _transferData.amount
            );
        } else {
            isRespondOnions[chainId][newFork.onionHead] = true;
        }

        // Freeze Margin
        _committerDeposits[msg.sender] = false;
    }

    // clearing zfork
    function zbond(
        uint256 chainId,
        bytes32 prevForkKey,
        bytes32 forkKey,
        Data.TransferData[] calldata _transferDatas,
        address[] calldata _committers
    ) external override {
        // incoming data length is correct
        require(_transferDatas.length > 0, "a1");
        require(_committers.length == _transferDatas.length, "a2");

        Fork.Info memory workFork = hashOnionForks.getForkEnsure(forkKey);
        bool isEarlyBonded = Fork.isEarlyBonded(
            workFork.verifyStatus,
            workFork.needBond
        );

        // When verified and not needBond, throw error
        require(workFork.verifyStatus == 0 || workFork.needBond, "a3");

        // Determine whether the onion of the fork has been recognized
        require(
            workFork.onionHead == hashOnions[chainId].onWorkHashOnion,
            "a4"
        );

        Fork.Info memory prevWorkFork = hashOnionForks.getForkEnsure(
            prevForkKey
        );

        (bytes32[] memory onionHeads, bytes32 destOnionHead) = Fork
            .getVerifyOnions(prevWorkFork, _transferDatas, _committers);

        // Assert that the replay result is equal to the stored value of the fork, which means that the incoming _transferdatas are valid
        require(destOnionHead == workFork.destOnionHead, "a5");

        // storage workFork
        workFork.verifyStatus = 1;
        workFork.needBond = false;
        hashOnionForks.update(forkKey, workFork);

        // If the prefork also needs to be settled, push the onWorkHashOnion forward a fork
        _setOnWorkHashOnion(chainId, prevWorkFork);

        // When earlyBonded, donnot transfer to committers
        if (isEarlyBonded) {
            return;
        }

        _settlement(
            chainId,
            workFork.allAmount,
            onionHeads,
            _transferDatas,
            _committers
        );

        // When has forkDeposit, send token to fork's endorser
        ForkDeposit.Info memory forkDeposit = hashOnionForkDeposits[forkKey];
        if (forkDeposit.endorser != address(0)) {
            IERC20(tokenAddress).safeTransfer(
                forkDeposit.endorser,
                forkDeposit.amount // TODO Add reward and denyer amount
            );
        }

        // !!! Reward bonder
    }

    function buyOneOnion(
        uint256 chainId,
        bytes32 preHashOnion,
        Data.TransferData calldata _transferData
    ) external override {
        bytes32 key = keccak256(
            abi.encode(preHashOnion, keccak256(abi.encode(_transferData)))
        );
        require(isRespondOnions[chainId][key], "a1");
        require(onionsAddress[key] == address(0), "a2");

        IERC20(tokenAddress).safeTransferFrom(
            msg.sender,
            _transferData.destination,
            _transferData.amount
        );

        onionsAddress[key] = msg.sender;
    }

    // Depostit one fork
    function depositWithOneFork(bytes32 forkKey) public {
        Fork.Info memory fork = hashOnionForks.getForkEnsure(forkKey);

        require(fork.workIndex == 0, "Only zFork");
        require(fork.length == ONEFORK_MAX_LENGTH, "Insufficient length");

        uint256 amount = fork.allAmount / ForkDeposit.DEPOSIT_SCALE;

        IERC20(tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        hashOnionForkDeposits.deposit(forkKey, amount, false);

        // Event
    }

    // Deposit mForks
    function depositMForks(
        uint256 chainId,
        bytes32 _prevForkKey,
        Data.MForkData[] calldata _mForkDatas,
        Data.TransferData[] calldata _transferDatas,
        address[] calldata _committers
    ) external {
        require(
            _transferDatas.length == ONEFORK_MAX_LENGTH,
            "Insufficient length"
        );

        Fork.Info memory prevFork = hashOnionForks.getForkEnsure(_prevForkKey);

        // Create unitedForkKey
        bytes32 hashOnion = Fork.generateOnionHead(
            prevFork.onionHead,
            _transferDatas[0]
        );
        bytes32 unitedForkKey = Fork.generateForkKey(
            chainId,
            hashOnion,
            ForkDeposit.MFORK_UNITED_WORK_INDEX
        );

        uint256 allAmount = 0;
        uint16 fi = 0;
        for (uint16 i = 0; i < _transferDatas.length; i++) {
            Data.TransferData memory transferData = _transferDatas[i];

            allAmount += transferData.amount + transferData.fee;
            if (fi < _mForkDatas.length && _mForkDatas[fi].forkIndex == i) {
                // Ensure fork exist
                require(
                    hashOnionForks.isExist(_mForkDatas[fi].forkKey),
                    "Fork is null"
                );

                fi += 1;
            }
        }

        Fork.Info memory unitedFork;
        unitedFork.allAmount = allAmount;
        unitedFork.length = ONEFORK_MAX_LENGTH;
        unitedFork.needBond = true;

        // Set onionHead, destOnionHead and lastCommiterAddress
        bytes32 onionHead = prevFork.onionHead;
        bytes32 destOnionHead = prevFork.destOnionHead;
        for (uint256 i; i < _transferDatas.length; i++) {
            onionHead = Fork.generateOnionHead(onionHead, _transferDatas[i]);

            destOnionHead = Fork.generateDestOnionHead(
                destOnionHead,
                onionHead,
                _committers[i]
            );

            unitedFork.lastCommiterAddress = _committers[i];
        }
        unitedFork.onionHead = onionHead;
        unitedFork.destOnionHead = destOnionHead;

        hashOnionForks.update(unitedForkKey, unitedFork);

        depositWithOneFork(unitedForkKey);
    }

    // Deny depostit one fork
    function denyDepositOneFork(bytes32 forkKey) external {
        ForkDeposit.Info memory forkDeposit = hashOnionForkDeposits
            .getDepositEnsure(forkKey);

        IERC20(tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            forkDeposit.amount
        );

        hashOnionForkDeposits.deposit(forkKey, forkDeposit.amount, true);
    }

    function earlyBond(
        uint256 chainId,
        bytes32 prevForkKey,
        bytes32 forkKey,
        Data.TransferData[] calldata _transferDatas,
        address[] calldata _committers
    ) external {
        ForkDeposit.Info memory forkDeposit = hashOnionForkDeposits
            .getDepositEnsure(forkKey);

        require(forkDeposit.denyer == address(0), "Dispute");
        require(
            ForkDeposit.isBlockNumberArrive(forkDeposit.prevBlockNumber),
            "No arrive"
        );

        Fork.Info memory prevFork = hashOnionForks.getForkEnsure(prevForkKey);
        Fork.Info memory fork = hashOnionForks.getForkEnsure(forkKey);

        require(fork.verifyStatus == 0, "Invalid verifyStatus");

        // Check destOnionHead
        (bytes32[] memory onionHeads, bytes32 destOnionHead) = Fork
            .getVerifyOnions(prevFork, _transferDatas, _committers);
        require(destOnionHead == fork.destOnionHead, "Different destOnionHead");

        _settlement(
            chainId,
            fork.allAmount,
            onionHeads,
            _transferDatas,
            _committers
        );

        // Send token to fork's endorser
        IERC20(tokenAddress).safeTransfer(
            forkDeposit.endorser,
            forkDeposit.amount // TODO Add reward(No denyer here)
        );

        // storage fork
        fork.needBond = false;
        hashOnionForks.update(forkKey, fork);
    }

    function disputeSolve(
        uint256 chainId,
        bytes32 prevForkKey,
        bytes32 forkKey,
        bytes32 forkTxHash,
        bytes32[] memory wrongForkKeys,
        bytes32[] memory wrongForkTxHashs
    ) external {
        Fork.Info memory prevFork = hashOnionForks.getForkEnsure(prevForkKey);
        Fork.Info memory fork = hashOnionForks.getForkEnsure(forkKey);

        // Verify forkKey
        bytes32 forkOnionHead = keccak256(
            abi.encode(prevFork.onionHead, forkTxHash)
        );
        require(
            Fork.generateForkKey(chainId, forkOnionHead, fork.workIndex) ==
                forkKey,
            "ForkKey verify faild"
        );

        require(fork.verifyStatus == 1, "Fork verify failed");

        bytes32 wrongForkOnionHead = prevFork.onionHead;
        for (uint256 i = 0; i < wrongForkKeys.length; i++) {
            Fork.Info memory wrongFork = hashOnionForks.getForkEnsure(
                wrongForkKeys[i]
            );

            // Verify wrong forkKey, verifyStatus
            wrongForkOnionHead = keccak256(
                abi.encode(wrongForkOnionHead, wrongForkTxHashs[i])
            );
            require(
                Fork.generateForkKey(
                    chainId,
                    wrongForkOnionHead,
                    wrongFork.workIndex
                ) == wrongForkKeys[i],
                "Wrong forkKey verify faild"
            );
            require(wrongFork.verifyStatus != 0, "Exception verifyStatus");

            // Check deposit
            ForkDeposit.Info memory wrongForkDeposit = hashOnionForkDeposits
                .getDepositEnsure(wrongForkKeys[i]);
            require(wrongForkDeposit.denyer != address(0), "No exist denyer");

            IERC20(tokenAddress).safeTransfer(
                wrongForkDeposit.denyer,
                wrongForkDeposit.amount
            );

            // Change wrongFork.verifyStatus
            wrongFork.verifyStatus = 2;
            hashOnionForks.update(wrongForkKeys[i], wrongFork);
        }
    }

    function loanFromLPPool(uint256 amount) internal {
        // Send bondToken to LPPool, LPPool send real token to dest
        PToken(pTokenAddress()).exchange(tokenAddress, amount);
    }

    // buy bond token
    function buyOneFork(
        uint256 chainId,
        uint256 _forkKey,
        uint256 _forkId
    ) external override {}

    // 1. Dest borrow token from the liquidity poo.(When liquidity is insufficient)
    // 2. Dest send token to committers
    function _settlement(
        uint256 chainId,
        uint256 forkAllAmount,
        bytes32[] memory onionHeads,
        Data.TransferData[] calldata _transferDatas,
        address[] calldata _committers
    ) internal {
        // When token.balanceOf(this) < fork.allAmount, get token from LP
        if (IERC20(tokenAddress).balanceOf(address(this)) < forkAllAmount) {
            uint256 diffAmount = forkAllAmount -
                IERC20(tokenAddress).balanceOf(address(this));

            // Ensure LP has sufficient token
            require(
                IERC20(tokenAddress).balanceOf(pTokenAddress()) >=
                    diffAmount,
                "Pool insufficient"
            );

            // Calculate lever
            PToken pToken = PToken(pTokenAddress());
            uint256 pTokenAmount = diffAmount / pToken.scale();

            // Mint pToken
            pToken.mint(pTokenAmount);

            // Exchange
            pToken.exchange(tokenAddress, pTokenAmount);
        }

        // Send token to committers
        for (uint256 i; i < _transferDatas.length; i++) {
            bytes32 onionHead = onionHeads[i];

            if (isRespondOnions[chainId][onionHead]) {
                address onionAddress = onionsAddress[onionHead];
                if (onionAddress != address(0)) {
                    IERC20(tokenAddress).safeTransfer(
                        onionAddress,
                        _transferDatas[i].amount + _transferDatas[i].fee
                    );
                } else {
                    IERC20(tokenAddress).safeTransfer(
                        _transferDatas[i].destination,
                        _transferDatas[i].amount + _transferDatas[i].fee
                    );
                }
            } else {
                IERC20(tokenAddress).safeTransfer(
                    _committers[i],
                    _transferDatas[i].amount + _transferDatas[i].fee
                );
            }
        }
    }

    function _setOnWorkHashOnion(uint256 chainId, Fork.Info memory fork)
        internal
    {
        HashOnions.Info memory info = hashOnions[chainId];

        if (
            fork.needBond ||
            Fork.isEarlyBonded(fork.verifyStatus, fork.needBond)
        ) {
            info.onWorkHashOnion = fork.onionHead;
        } else {
            // If no settlement is required, it means that the previous round of settlement is completed, and a new value is set
            info.onWorkHashOnion = info.sourceHashOnion;
        }

        hashOnions[chainId] = info;
    }
}
