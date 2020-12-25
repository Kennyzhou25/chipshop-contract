// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

// Note that this pool has no minter key of BDO (rewards).
// Instead, the governance will call BDO distributeReward method and send reward to this pool at the beginning.
contract BdoRewardPool {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // governance
    address public operator;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. BDOs to distribute per block.
        uint256 lastRewardBlock; // Last block number that BDOs distribution occurs.
        uint256 accBdoPerShare; // Accumulated BDOs per share, times 1e18. See below.
        bool isStarted; // if lastRewardBlock has passed
    }

    IERC20 public bdo = IERC20(0x190b589cf9Fb8DDEabBFeae36a813FFb2A702454);

    // Info of each pool.
    PoolInfo[] public poolInfo;

    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    // The block number when BDO mining starts.
    uint256 public startBlock;

    uint256 public constant BLOCKS_PER_WEEK = 201600; // 86400 * 7 / 3;

    uint256[] public epochTotalRewards = [80000 ether, 60000 ether, 40000 ether];

    // Block number when each epoch ends.
    uint[3] public epochEndBlocks;

    // Reward per block for each of 3 epochs (last item is equal to 0 - for sanity).
    uint[4] public epochBdoPerBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event RewardPaid(address indexed user, uint256 amount);

    constructor(
        address _bdo,
        uint256 _startBlock
    ) public {
        require(block.number < _startBlock, "late");
        if (_bdo != address(0)) bdo = IERC20(_bdo);
        startBlock = _startBlock; // supposed to be 3,410,000 (Fri Dec 25 2020 15:00:00 UTC)
        epochEndBlocks[0] = startBlock + BLOCKS_PER_WEEK;
        uint256 i;
        for (i = 1; i <= 2; ++i) {
            epochEndBlocks[i] = epochEndBlocks[i - 1] + BLOCKS_PER_WEEK;
        }
        for (i = 0; i <= 2; ++i) {
            epochBdoPerBlock[i] = epochTotalRewards[i].div(BLOCKS_PER_WEEK);
        }
        epochBdoPerBlock[3] = 0;
        operator = msg.sender;
    }

    modifier onlyOperator() {
        require(operator == msg.sender, "BdoRewardPool: caller is not the operator");
        _;
    }

    function checkPoolDuplicate(IERC20 _lpToken) internal view {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            require(poolInfo[pid].lpToken != _lpToken, "BdoRewardPool: existing pool?");
        }
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate,
        uint256 _lastRewardBlock
    ) public onlyOperator {
        checkPoolDuplicate(_lpToken);
        if (_withUpdate) {
            massUpdatePools();
        }
        if (block.number < startBlock) {
            // chef is sleeping
            if (_lastRewardBlock == 0) {
                _lastRewardBlock = startBlock;
            } else {
                if (_lastRewardBlock < startBlock) {
                    _lastRewardBlock = startBlock;
                }
            }
        } else {
            // chef is cooking
            if (_lastRewardBlock == 0 || _lastRewardBlock < block.number) {
                _lastRewardBlock = block.number;
            }
        }
        bool _isStarted =
        (_lastRewardBlock <= startBlock) ||
        (_lastRewardBlock <= block.number);
        poolInfo.push(PoolInfo({
            lpToken : _lpToken,
            allocPoint : _allocPoint,
            lastRewardBlock : _lastRewardBlock,
            accBdoPerShare : 0,
            isStarted : _isStarted
            }));
        if (_isStarted) {
            totalAllocPoint = totalAllocPoint.add(_allocPoint);
        }
    }

    // Update the given pool's BDO allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint) public onlyOperator {
        massUpdatePools();
        PoolInfo storage pool = poolInfo[_pid];
        if (pool.isStarted) {
            totalAllocPoint = totalAllocPoint.sub(pool.allocPoint).add(
                _allocPoint
            );
        }
        pool.allocPoint = _allocPoint;
    }

    // Return accumulate rewards over the given _from to _to block.
    function getGeneratedReward(uint256 _from, uint256 _to) public view returns (uint256) {
        for (uint8 epochId = 3; epochId >= 1; --epochId) {
            if (_to >= epochEndBlocks[epochId - 1]) {
                if (_from >= epochEndBlocks[epochId - 1]) return _to.sub(_from).mul(epochBdoPerBlock[epochId]);
                uint256 _generatedReward = _to.sub(epochEndBlocks[epochId - 1]).mul(epochBdoPerBlock[epochId]);
                if (epochId == 1) return _generatedReward.add(epochEndBlocks[0].sub(_from).mul(epochBdoPerBlock[0]));
                for (epochId = epochId - 1; epochId >= 1; --epochId) {
                    if (_from >= epochEndBlocks[epochId - 1]) return _generatedReward.add(epochEndBlocks[epochId].sub(_from).mul(epochBdoPerBlock[epochId]));
                    _generatedReward = _generatedReward.add(epochEndBlocks[epochId].sub(epochEndBlocks[epochId - 1]).mul(epochBdoPerBlock[epochId]));
                }
                return _generatedReward.add(epochEndBlocks[0].sub(_from).mul(epochBdoPerBlock[0]));
            }
        }
        return _to.sub(_from).mul(epochBdoPerBlock[0]);
    }

    // View function to see pending BDOs on frontend.
    function pendingBDO(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accBdoPerShare = pool.accBdoPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 _generatedReward = getGeneratedReward(pool.lastRewardBlock, block.number);
            uint256 _bdoReward = _generatedReward.mul(pool.allocPoint).div(totalAllocPoint);
            accBdoPerShare = accBdoPerShare.add(_bdoReward.mul(1e18).div(lpSupply));
        }
        return user.amount.mul(accBdoPerShare).div(1e18).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
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
        if (!pool.isStarted) {
            pool.isStarted = true;
            totalAllocPoint = totalAllocPoint.add(pool.allocPoint);
        }
        if (totalAllocPoint > 0) {
            uint256 _generatedReward = getGeneratedReward(pool.lastRewardBlock, block.number);
            uint256 _bdoReward = _generatedReward.mul(pool.allocPoint).div(totalAllocPoint);
            pool.accBdoPerShare = pool.accBdoPerShare.add(_bdoReward.mul(1e18).div(lpSupply));
        }
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens.
    function deposit(uint256 _pid, uint256 _amount) public {
        address _sender = msg.sender;
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 _pending = user.amount.mul(pool.accBdoPerShare).div(1e18).sub(user.rewardDebt);
            if (_pending > 0) {
                safeBdoTransfer(_sender, _pending);
                emit RewardPaid(_sender, _pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(_sender, address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accBdoPerShare).div(1e18);
        emit Deposit(_sender, _pid, _amount);
    }

    // Withdraw LP tokens.
    function withdraw(uint256 _pid, uint256 _amount) public {
        address _sender = msg.sender;
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 _pending = user.amount.mul(pool.accBdoPerShare).div(1e18).sub(user.rewardDebt);
        if (_pending > 0) {
            safeBdoTransfer(_sender, _pending);
            emit RewardPaid(_sender, _pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(_sender, _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accBdoPerShare).div(1e18);
        emit Withdraw(_sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 _amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(msg.sender, _amount);
        emit EmergencyWithdraw(msg.sender, _pid, _amount);
    }

    // Safe bdo transfer function, just in case if rounding error causes pool to not have enough BDOs.
    function safeBdoTransfer(address _to, uint256 _amount) internal {
        uint256 _bdoBal = bdo.balanceOf(address(this));
        if (_bdoBal > 0) {
            if (_amount > _bdoBal) {
                bdo.safeTransfer(_to, _bdoBal);
            } else {
                bdo.safeTransfer(_to, _amount);
            }
        }
    }

    function setOperator(address _operator) external onlyOperator {
        operator = _operator;
    }

    function governanceRecoverUnsupported(IERC20 _token, uint256 amount, address to) external onlyOperator {
        if (block.number < epochEndBlocks[2] + BLOCKS_PER_WEEK * 26) {
            // do not allow to drain lpToken if less than 6 months after farming
            require(_token != bdo, "!bdo");
            uint256 length = poolInfo.length;
            for (uint256 pid = 0; pid < length; ++pid) {
                PoolInfo storage pool = poolInfo[pid];
                require(_token != pool.lpToken, "!pool.lpToken");
            }
        }
        _token.safeTransfer(to, amount);
    }
}
