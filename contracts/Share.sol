// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';

import './owner/Operator.sol';

contract Share is ERC20Burnable, Operator {
    using SafeMath for uint256;

    uint256 public constant BSD_USDC_REWARD_POOL_ALLOCATION = 500000 ether;
    uint256 public constant BSS_USDC_REWARD_POOL_ALLOCATION = 300000 ether;
    uint256 public constant TREASURY_FUND_POOL_ALLOCATION = 100000 ether;
    uint256 public constant DEV_FUND_POOL_ALLOCATION = 100000 ether;

    uint256 public constant VESTING_DURATION = 365 days;
    uint256 public startTime = 1608040800; // Tuesday, December 15, 2020 2:00:00 PM UTC
    uint256 public endTime = startTime + VESTING_DURATION; // Wednesday, December 15, 2021 2:00:00 PM

    uint256 public treasuryFundRewardRate = TREASURY_FUND_POOL_ALLOCATION / VESTING_DURATION;
    uint256 public devFundRewardRate = DEV_FUND_POOL_ALLOCATION / VESTING_DURATION;

    address public treasuryFund;
    address public devFund;

    uint256 public treasuryFundLastClaimed = startTime;
    uint256 public devFundLastClaimed = startTime;

    bool public rewardPoolDistributed = false;

    constructor() public ERC20('Basis Share', 'BSS') {
        _mint(msg.sender, 1 ether); // mint 1 Basis Share for initial pools deployment
        devFund = msg.sender;
    }

    function setTreasuryFund(address _treasuryFund) external onlyOperator {
        treasuryFund = _treasuryFund;
    }

    function setDevFund(address _devFund) external onlyOperator {
        devFund = _devFund;
    }

    function unclaimedTreasuryFund() public view returns (uint256 _pending) {
        uint256 _now = block.timestamp;
        if (_now > endTime) _now = endTime;
        if (treasuryFundLastClaimed >= _now) return 0;
        _pending = _now.sub(treasuryFundLastClaimed).mul(treasuryFundRewardRate);
    }

    function unclaimedDevFund() public view returns (uint256 _pending) {
        uint256 _now = block.timestamp;
        if (_now > endTime) _now = endTime;
        if (devFundLastClaimed >= _now) return 0;
        _pending = _now.sub(devFundLastClaimed).mul(devFundRewardRate);
    }

    /**
     * @dev Claim pending rewards to treasury and dev fund
     */
    function claimRewards() external {
        uint256 _pending = unclaimedTreasuryFund();
        if (_pending > 0 && treasuryFund != address(0)) {
            _mint(treasuryFund, _pending);
            treasuryFundLastClaimed = block.timestamp;
        }
        _pending = unclaimedDevFund();
        if (_pending > 0 && devFund != address(0)) {
            _mint(devFund, _pending);
            devFundLastClaimed = block.timestamp;
        }
    }

    /**
     * @notice distribute to reward pool (only once)
     */
    function distributeRewards(address _bsdRewardPool, address _bssRewardPool) external onlyOperator {
        require(!rewardPoolDistributed, "only can distribute once");
        require(_bsdRewardPool != address(0), "!_bsdRewardPool");
        require(_bssRewardPool != address(0), "!_bssRewardPool");
        rewardPoolDistributed = true;
        _mint(_bsdRewardPool, BSD_USDC_REWARD_POOL_ALLOCATION);
        _mint(_bssRewardPool, BSS_USDC_REWARD_POOL_ALLOCATION);
    }

    function burn(uint256 amount) public override onlyOperator {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount) public override onlyOperator {
        super.burnFrom(account, amount);
    }
}
