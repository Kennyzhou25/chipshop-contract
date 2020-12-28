// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

import "./owner/Operator.sol";

contract Share is ERC20Burnable, Operator {
    using SafeMath for uint256;

    // TOTAL MAX SUPPLY = 100,000 sBDO
    uint256 public constant FARMING_POOL_REWARD_ALLOCATION = 85000 ether;
    uint256 public constant COMMUNITY_FUND_POOL_ALLOCATION = 7500 ether;
    uint256 public constant DEV_FUND_POOL_ALLOCATION = 7500 ether;

    uint256 public constant VESTING_DURATION = 365 days;
    uint256 public startTime = 1608811200; // Thursday, 24 December 2020 12:00:00 PM UTC
    uint256 public endTime = startTime + VESTING_DURATION; // Friday, 24 December 2021 12:00:00 PM UTC

    uint256 public communityFundRewardRate = COMMUNITY_FUND_POOL_ALLOCATION / VESTING_DURATION;
    uint256 public devFundRewardRate = DEV_FUND_POOL_ALLOCATION / VESTING_DURATION;

    address public communityFund;
    address public devFund;

    uint256 public communityFundLastClaimed = startTime;
    uint256 public devFundLastClaimed = startTime;

    bool public rewardPoolDistributed = false;

    constructor() public ERC20("bDollar Share", "sBDO") {
        _mint(msg.sender, 1 ether); // mint 1 Basis Share for initial pools deployment
        devFund = msg.sender;
    }

    function setTreasuryFund(address _communityFund) external {
        require(msg.sender == devFund, "!dev");
        communityFund = _communityFund;
    }

    function setDevFund(address _devFund) external {
        require(msg.sender == devFund, "!dev");
        require(_devFund != address(0), "zero");
        devFund = _devFund;
    }

    function unclaimedTreasuryFund() public view returns (uint256 _pending) {
        uint256 _now = block.timestamp;
        if (_now > endTime) _now = endTime;
        if (communityFundLastClaimed >= _now) return 0;
        _pending = _now.sub(communityFundLastClaimed).mul(communityFundRewardRate);
    }

    function unclaimedDevFund() public view returns (uint256 _pending) {
        uint256 _now = block.timestamp;
        if (_now > endTime) _now = endTime;
        if (devFundLastClaimed >= _now) return 0;
        _pending = _now.sub(devFundLastClaimed).mul(devFundRewardRate);
    }

    /**
     * @dev Claim pending rewards to community and dev fund
     */
    function claimRewards() external {
        uint256 _pending = unclaimedTreasuryFund();
        if (_pending > 0 && communityFund != address(0)) {
            _mint(communityFund, _pending);
            communityFundLastClaimed = block.timestamp;
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
    function distributeReward(address _farmingIncentiveFund) external onlyOperator {
        require(!rewardPoolDistributed, "only can distribute once");
        require(_farmingIncentiveFund != address(0), "!_farmingIncentiveFund");
        rewardPoolDistributed = true;
        _mint(_farmingIncentiveFund, FARMING_POOL_REWARD_ALLOCATION);
    }

    function burn(uint256 amount) public override {
        super.burn(amount);
    }
}
