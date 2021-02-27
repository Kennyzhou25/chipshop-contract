// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../owner/Operator.sol";
import "../interfaces/IBoardroom.sol";

contract MockBoardroom is IBoardroom, Operator {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IERC20 public mee;
    IERC20 public share;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    /* ========== CONSTRUCTOR ========== */

    constructor(address _mee, address _share) public {
        mee = IERC20(_mee);
        share = IERC20(_share);
    }

    /* ========== VIEW FUNCTIONS ========== */

    function balanceOf(address _account) external override view returns (uint256) {
        return _balances[_account];
    }

    function earned(address) public override view returns (uint256) {
        return 1 ether;
    }

    function canWithdraw(address) external override view returns (bool) {
        return true;
    }

    function canClaimReward(address) external override view returns (bool) {
        return true;
    }

    function epoch() external override view returns (uint256) {
        return 0;
    }

    function nextEpochPoint() external override view returns (uint256) {
        return 0;
    }

    function getEthPrice() external override view returns (uint256) {
        return 0;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function allocateSeigniorage(uint256 amount) external override onlyOperator {
        require(amount > 0, "Boardroom: Cannot allocate 0");
        mee.safeTransferFrom(msg.sender, address(this), amount);
        emit RewardAdded(msg.sender, amount);
    }

    function stake(uint256 _amount) external override {
        _totalSupply = _totalSupply.add(_amount);
        _balances[msg.sender] = _balances[msg.sender].add(_amount);
        share.safeTransferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(uint256 _amount) public override {
        _balances[msg.sender] = _balances[msg.sender].sub(_amount);
        share.safeTransfer(msg.sender, _amount);
    }

    function exit() external override {
        withdraw(_balances[msg.sender]);
    }

    function claimReward() external override {
        mee.safeTransfer(msg.sender, earned(msg.sender));
    }

    function setOperator(address _operator) external override onlyOperator {
    }

    function setLockUp(uint256 _withdrawLockupEpochs, uint256 _rewardLockupEpochs) external override onlyOperator {
    }

    function governanceRecoverUnsupported(address _token, uint256 _amount, address _to) external override onlyOperator {
    }

    /* ========== EVENTS ========== */

    event RewardAdded(address indexed user, uint256 reward);
}
