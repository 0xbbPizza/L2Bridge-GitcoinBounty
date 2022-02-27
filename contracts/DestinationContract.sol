// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Data.sol";
import "./IDestChildContract.sol";
import "./IDestinationContract.sol";

contract DestinationContract is IDestinationContract , Ownable {
    using SafeERC20 for IERC20;

    address tokenAddress;

    mapping(uint256 => address) public chainID_childs;
    mapping(address => uint256) public dest_chainIDs;
    mapping(address => uint256) public sourc_chainIDs;

    mapping(address => bool) private _commiterDeposit;   // Submitter's bond record

    uint256 public ONEFORK_MAX_LENGTH = 5;  // !!! The final value is 50 , the higher the value, the longer the wait time and the less storage consumption
    uint256 DEPOSIT_AMOUNT = 1 * 10**18;  // !!! The final value is 2 * 10**17

    address private _msgSender;

    modifier onlyChild {
        require(msg.sender == chainID_childs[chainID], "not child");
        _;
    }

    modifier onlySoure {
        _;
    }

    modifier onlySupportDomain {
        require(chainID_childs[chainID] != address(0));
        address activeMsgSender = _msgSender;
        _msgSender = msg.sender;
        _;
        _msgSender = activeMsgSender;
    }

    constructor(address _tokenAddress){
        tokenAddress = _tokenAddress;
    }

    /*
        set
    */
    function addDomain(uint256 chainID, address source) external onlyOwner {
        require(chainID_childs[chainID] == address(0));
        address childAddr = deployChildContract();
        chainID_childs[chainID] = childAddr;
        dest_chainIDs[childAddr] = chainID;
        sourc_chainIDs[source] = chainID;
    }

    // TODO 
    function deployChildContract() internal return (address addr){
        return address(0)
    }
    
    // TODO need deposit ETH 
    function becomeCommiter() external{
        _commiterDeposit[msg.sender] = true;
    }

    /*
        childContract call back
    */
    function getMsgSender() external view override returns (address) {
        return _msgSender;
    }
    function getCommiterDeposit() external view override returns (bool) {
        return _commiterDeposit[_msgSender];
    }
    function transfer(address dest, uint256 amount) external onlychild{
        IERC20(tokenAddress).safeTransfer(dest,amount); 
    }

    function transferFrom(address dest,uint256 amount) external onlyChild {
        IERC20(tokenAddress).safeTransferFrom(_msgSender,dest,amount); 
    }
        
    function changeDepositState(address addr, bool state) onlyChild {
        _commiterDeposit[addr] = state;
    }

    /*
        call from source 
    */
    // TODO
    function bondSourceHashOnion(bytes32 hashOnion) onlySoure {
        // call childs
    }

    /*
        call childContract
    */
    // if index % ONEFORK_MAX_LENGTH == 0 
    function zFork(uint256 chainId, bytes32 _forkKey, uint8 _index, address dest, uint256 amount, uint256 fee, bool _isRespond) external onlySupportDomain{
        IDestChildContract(chainID_childs[chainID]).zFork(_forkKey,_index,dest,amount,fee,_isRespond);
    }
    // just deppend
    function claim(uint256 chainId,bytes32 _forkKey, uint256 _forkIndex, uint256 _workIndex, Data.TransferData[] calldata _transferDatas,bool[] calldata _isResponds) external onlySupportDomain{
        IDestChildContract(chainID_childs[chainID]).claim(_forkKey,_forkIndex,_workIndex,_transferDatas,_isResponds);
    }
    // if source index % ONEFORK_MAX_LENGTH != 0
    function mFork(uint256 chainId, bytes32 _lastOnionHead, bytes32 _lastDestOnionHead, uint8 _index , Data.TransferData calldata _transferData, bool _isRespond) external onlySupportDomain{
        IDestChildContract(chainID_childs[chainID]).mFork(_lastOnionHead,_lastDestOnionHead,_index,_transferDatas,_isResponds);
    }
    // clearing zfork
    function zbond(uint256 chainId, bytes32 _forkKey,bytes32 _preForkKey, uint256 _preForkIndex, Data.TransferData[] calldata _transferDatas, address[] calldata _commiters) external onlySupportDomain{
        IDestChildContract(chainID_childs[chainID]).zbond(_child,_forkKey,preForkKey,_preForkIndex,_transferDatas,_commiters);
    }
    // Settlement non-zero fork
    function mbond(uint256 chainId, MForkData[] calldata _mForkDatas,bytes32 _preForkKey, uint256 _preForkIndex, Data.TransferData[] calldata _transferDatas, address[] calldata _commiters) external onlySupportDomain{
        IDestChildContract(chainID_childs[chainID]).mbond(_mForkDatas,_preForkKey,_preForkIndex,_transferDat,_commiters);
    }
    function buyOneOnion(uint256 chainId, bytes32 preHashOnion,Data.TransferData calldata _transferData) external onlySupportDomain{
        IDestChildContract(chainID_childs[chainID]).buyOneOnion(preHashOnion,_transferData);
    }
    function buyOneFork(uint256 chainId, uint256 _forkKey, uint256 _forkId) external onlySupportDomain{
        IDestChildContract(chainID_childs[chainID]).buyOneFork(_forkKey,_forkId);
    }
}   



