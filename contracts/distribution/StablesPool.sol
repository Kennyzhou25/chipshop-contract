// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

// Note that this pool has no minter key of BSD (rewards).
// Instead, the governance will call BSD.distributeReward and send reward to this pool at the beginning.
contract StablesPool {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public governance;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of BSDs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accBsdPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accBsdPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
        uint256 accumulatedStakingPower; // will accumulate every time user harvest
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 lastRewardBlock; // Last block number that BSDs distribution occurs.
        uint256 accBsdPerShare; // Accumulated BSDs per share, times 1e18. See below.
    }

    // The BSD TOKEN!
    IERC20 public bsd = IERC20(0x003e0af2916e598Fa5eA5Cb2Da4EDfdA9aEd9Fde);

    // Info of each pool.
    PoolInfo[] public poolInfo;

    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    uint256 public startBlock;

    uint256 public poolLength = 5; // DAI, USDC, USDT, BUSD, ESD

    uint256 public constant BLOCKS_PER_WEEK = 46500;

    uint256[] public epochTotalRewards = [200000 ether, 150000 ether, 100000 ether, 50000 ether];

    // Block number when each epoch ends.
    uint[4] public epochEndBlocks;

    // Reward per block for each of 4 epochs (last item is equal to 0 - for sanity).
    uint[5] public epochBsdPerBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event RewardPaid(address indexed user, uint256 amount);

    constructor(
        address _bsd,
        uint256 _startBlock,
        address[] memory _lpTokens
    ) public {
        require(block.number < _startBlock, "late");
        if (_bsd != address(0)) bsd = IERC20(_bsd);
        startBlock = _startBlock; // supposed to be 11,465,000 (Wed Dec 16 2020 15:00:00 UTC)
        epochEndBlocks[0] = startBlock + BLOCKS_PER_WEEK;
        uint256 i;
        for (i = 1; i <= 3; ++i) {
            epochEndBlocks[i] = epochEndBlocks[i - 1] + BLOCKS_PER_WEEK;
        }
        for (i = 0; i <= 3; ++i) {
            epochBsdPerBlock[i] = epochTotalRewards[i].div(BLOCKS_PER_WEEK);
        }
        epochBsdPerBlock[4] = 0;
        if (_lpTokens.length == 0) {
            _addPool(address(0x6B175474E89094C44Da98b954EedeAC495271d0F)); // DAI
            _addPool(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)); // USDC
            _addPool(address(0xdAC17F958D2ee523a2206206994597C13D831ec7)); // USDT
            _addPool(address(0x4Fabb145d64652a948d72533023f6E7A623C7C53)); // BUSD
            _addPool(address(0x36F3FD68E7325a35EB768F1AedaAe9EA0689d723)); // ESD
        } else {
            require(_lpTokens.length == poolLength, "Need exactly 5 lpToken address");
            for (i = 0; i < poolLength; ++i) {
                _addPool(_lpTokens[i]);
            }
        }
    }

    // Add a new lp to the pool. Called in the constructor only.
    function _addPool(address _lpToken) internal {
        require(_lpToken != address(0), "!_lpToken");
        poolInfo.push(
            PoolInfo({
            lpToken : IERC20(_lpToken),
            lastRewardBlock : startBlock,
            accBsdPerShare : 0
            })
        );
    }

    // Return reward multiplier over the given _from to _to block.
    function getGeneratedReward(uint256 _from, uint256 _to) public view returns (uint256) {
        for (uint8 epochId = 4; epochId >= 1; --epochId) {
            if (_to >= epochEndBlocks[epochId - 1]) {
                if (_from >= epochEndBlocks[epochId - 1]) return _to.sub(_from).mul(epochBsdPerBlock[epochId]);
                uint256 _generatedReward = _to.sub(epochEndBlocks[epochId - 1]).mul(epochBsdPerBlock[epochId]);
                if (epochId == 1) return _generatedReward.add(epochEndBlocks[0].sub(_from).mul(epochBsdPerBlock[0]));
                for (epochId = epochId - 1; epochId >= 1; --epochId) {
                    if (_from >= epochEndBlocks[epochId - 1]) return _generatedReward.add(epochEndBlocks[epochId].sub(_from).mul(epochBsdPerBlock[epochId]));
                    _generatedReward = _generatedReward.add(epochEndBlocks[epochId].sub(epochEndBlocks[epochId - 1]).mul(epochBsdPerBlock[epochId]));
                }
                return _generatedReward.add(epochEndBlocks[0].sub(_from).mul(epochBsdPerBlock[0]));
            }
        }
        return _to.sub(_from).mul(epochBsdPerBlock[0]);
    }

    // View function to see pending BSDs on frontend.
    function pendingBasisDollar(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accBsdPerShare = pool.accBsdPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 _generatedReward = getGeneratedReward(pool.lastRewardBlock, block.number);
            accBsdPerShare = accBsdPerShare.add(_generatedReward.div(poolLength).mul(1e18).div(lpSupply));
        }
        return user.amount.mul(accBsdPerShare).div(1e18).sub(user.rewardDebt);
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 _generatedReward = getGeneratedReward(pool.lastRewardBlock, block.number);
        pool.accBsdPerShare = pool.accBsdPerShare.add(_generatedReward.div(poolLength).mul(1e18).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens.
    function deposit(uint256 _pid, uint256 _amount) public {
        address _sender = msg.sender;
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 _pending = user.amount.mul(pool.accBsdPerShare).div(1e18).sub(user.rewardDebt);
            if (_pending > 0) {
                safeBsdTransfer(_sender, _pending);
                emit RewardPaid(_sender, _pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(_sender, address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accBsdPerShare).div(1e18);
        emit Deposit(_sender, _pid, _amount);
    }

    // Withdraw LP tokens.
    function withdraw(uint256 _pid, uint256 _amount) public {
        address _sender = msg.sender;
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 _pending = user.amount.mul(pool.accBsdPerShare).div(1e18).sub(user.rewardDebt);
        if (_pending > 0) {
            safeBsdTransfer(_sender, _pending);
            emit RewardPaid(_sender, _pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(_sender, _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accBsdPerShare).div(1e18);
        emit Withdraw(_sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe bsd transfer function, just in case if rounding error causes pool to not have enough BSDs.
    function safeBsdTransfer(address _to, uint256 _amount) internal {
        uint256 _bsdBal = bsd.balanceOf(address(this));
        if (_bsdBal > 0) {
            if (_amount > _bsdBal) {
                bsd.transfer(_to, _bsdBal);
            } else {
                bsd.transfer(_to, _amount);
            }
        }
    }

    function setGovernance(address _governance) external {
        require(msg.sender == governance, "!governance");
        require(_governance != address(0), "zero");
        governance = _governance;
    }

    function governanceRecoverUnsupported(IERC20 _token, uint256 amount, address to) external {
        require(msg.sender == governance, "!governance");
        if (block.number < epochEndBlocks[3] + BLOCKS_PER_WEEK * 12) {
            // do not allow to drain lpToken if less than 3 months after farming
            require(_token != bsd, "!bsd");
            for (uint256 pid = 0; pid < poolLength; ++pid) {
                PoolInfo storage pool = poolInfo[pid];
                require(_token != pool.lpToken, "!pool.lpToken");
            }
        }
        _token.safeTransfer(to, amount);
    }
}
