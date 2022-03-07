// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Data.sol";
import "./IDestChildContract.sol";
import "./IDestinationContract.sol";
import "./MassageDock/CrossDomainHelper.sol";

contract DestinationContract is IDestinationContract, CrossDomainHelper , Ownable {
    using SafeERC20 for IERC20;

    address tokenAddress;

    mapping(uint256 => address) public chainId_childs;
    mapping(address => uint256) public child_chainIds;

    mapping(address => uint256) public sourc_chainIds;

    mapping(address => bool) private _commiterDeposit;   // Submitter's bond record

    uint256 public ONEFORK_MAX_LENGTH = 5;  // !!! The final value is 50 , the higher the value, the longer the wait time and the less storage consumption
    uint256 DEPOSIT_AMOUNT = 1 * 10**18;  // !!! The final value is 2 * 10**17

    /*
	1. every LP need deposit `DEPOSIT_AMOUNT` ETH, DEPOSIT_AMOUNT = OnebondGaslimit * max_fork.length * Average_gasPrice 
	2. when LP call zfork()、mfork()、claim(). lock deposit, and unlock the preHashOnions LP's deposit. 
	3. When bonder is settling `middle fork`, will get `DEPOSIT_AMOUNT` ETH back from destContract. 
	4. LP's deposit can only be withdrawn if they are unlocked.
	5. No one wants to pay for someone else's mistakes, so the perpetrator's deposit will never be unlocked
    */

    constructor(
        address _tokenAddress,
        address _dockAddr
    )
        CrossDomainHelper(_dockAddr)
    {
        tokenAddress = _tokenAddress;
    }

    modifier onlyChild {
        require(child_chainIds[msg.sender] != 0, "not child");
        _;
    }

    function _onlyApprovedSources(address _sourceSender, uint256 _sourChainId) internal view override{
        require(_sourChainId != 0, "ZERO_CHAINID");
        require(sourc_chainIds[_sourceSender] == _sourChainId, "NOTAPPROVE");
    }

    /*
        call from source 
    */
    function bondSourceHashOnion(uint256 chainId, bytes32 hashOnion) external sourceSafe {
        IDestChildContract(chainId_childs[chainId]).bondSourceHashOnion(hashOnion);
    }

    /*
        set
    */
    function addDomain(uint256 chainId, address source) external onlyOwner {
        require(chainId_childs[chainId] == address(0));
        address childAddr = deployChildContract();
        chainId_childs[chainId] = childAddr;
        child_chainIds[childAddr] = chainId;
        sourc_chainIds[source] = chainId;
    }

    // TODO 
    function deployChildContract() internal returns (address addr){
        return address(0);
    }
    
    // TODO need deposit ETH 
    function becomeCommiter() external{
        _commiterDeposit[tx.origin] = true;
    }

    /*
        childContract call back
    */
    function getCommiterDeposit() external view override returns (bool) {
        return _commiterDeposit[tx.origin];
    }
    function transfer(address dest, uint256 amount) external override onlyChild{
        IERC20(tokenAddress).safeTransfer(dest,amount); 
    }

    function transferFrom(address dest,uint256 amount) external override onlyChild {
        IERC20(tokenAddress).safeTransferFrom(tx.origin,dest,amount); 
    }
        
    function changeDepositState(address addr, bool state) external override onlyChild {
        _commiterDeposit[addr] = state;
    }

    /*
        call childContract
    */
    // if index % ONEFORK_MAX_LENGTH == 0 
    function zFork(uint256 chainId, uint256 forkKeyNum, address dest, uint256 amount, uint256 fee, bool _isRespond) external override {
        IDestChildContract(chainId_childs[chainId]).zFork(forkKeyNum,dest,amount,fee,_isRespond);
    }
    // just deppend
    function claim(uint256 chainId, uint256 forkKeyNum, uint256 _workIndex, Data.TransferData[] calldata _transferDatas,bool[] calldata _isResponds) external override {
        IDestChildContract(chainId_childs[chainId]).claim(forkKeyNum,_workIndex,_transferDatas,_isResponds);
    }
    // if source index % ONEFORK_MAX_LENGTH != 0
    function mFork(uint256 chainId, bytes32 _lastOnionHead, bytes32 _lastDestOnionHead, uint8 _index , Data.TransferData calldata _transferData, bool _isRespond) external override {
        IDestChildContract(chainId_childs[chainId]).mFork(_lastOnionHead,_lastDestOnionHead,_index,_transferData,_isRespond);
    }
    // clearing zfork
    function zbond(uint256 chainId, uint256 forkKeyNum, uint256 _preForkKeyNum, Data.TransferData[] calldata _transferDatas, address[] calldata _commiters) external override {
        IDestChildContract(chainId_childs[chainId]).zbond(forkKeyNum,_preForkKeyNum,_transferDatas,_commiters);
    }
    // Settlement non-zero fork
    function mbond(uint256 chainId, Data.MForkData[] calldata _mForkDatas, uint256 forkKeyNum, Data.TransferData[] calldata _transferDatas, address[] calldata _commiters) external override {
        IDestChildContract(chainId_childs[chainId]).mbond(_mForkDatas,forkKeyNum,_transferDatas,_commiters);
    }
    function buyOneOnion(uint256 chainId, bytes32 preHashOnion,Data.TransferData calldata _transferData) external override {
        IDestChildContract(chainId_childs[chainId]).buyOneOnion(preHashOnion,_transferData);
    }
    function buyOneFork(uint256 chainId, uint256 _forkKey, uint256 _forkId) external override {
        IDestChildContract(chainId_childs[chainId]).buyOneFork(_forkKey,_forkId);
    }
}   



