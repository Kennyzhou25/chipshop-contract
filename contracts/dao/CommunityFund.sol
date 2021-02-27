// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../interfaces/IUniswapV2Router.sol";
import "../interfaces/IBPool.sol";
import "../interfaces/IBoardroom.sol";
import "../interfaces/IShare.sol";
import "../interfaces/ITreasury.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/IShareRewardPool.sol";
import "../interfaces/IPancakeswapPool.sol";

/**
 * @dev This contract will collect vesting Shares, stake to the Boardroom and rebalance MEE, BUSD, WBNB according to DAO.
 */
contract CommunityFund {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    /* ========== STATE VARIABLES ========== */

    // governance
    address public operator;

    // flags
    bool public initialized = false;
    bool public publicAllowed; // set to true to allow public to call rebalance()

    // price
    uint256 public meePriceToSell; // to rebalance when expansion
    uint256 public meePriceToBuy; // to rebalance when contraction

    address public mee = address(0x35e869B7456462b81cdB5e6e42434bD27f3F788c);
    address public share = address(0x242E46490397ACCa94ED930F2C4EdF16250237fa);
    address public bond = address(0xCaD2109CC2816D47a796cB7a0B57988EC7611541);

    address public busd = address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    address public usdt = address(0x55d398326f99059fF775485246999027B3197955);
    address public bdo = address(0x190b589cf9Fb8DDEabBFeae36a813FFb2A702454);
    address public bcash = address(0xc2161d47011C4065648ab9cDFd0071094228fa09);
    address public wbnb = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    address public boardroom = address(0xFF0b41ad7a85430FEbBC5220fd4c7a68013F2C0d);
    address public meeOracle = address(0x26593B4E6a803aac7f39955bd33C6826f266D7Fc);
    address public treasury = address(0xD3372603Db4087FF5D797F91839c0Ca6b9aF294a);

    // Pancakeswap
    IUniswapV2Router public pancakeRouter = IUniswapV2Router(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F);
    mapping(address => mapping(address => address[])) public uniswapPaths;

    // DAO parameters - https://docs.wantanmee.finance/DAO
    uint256[] public expansionPercent;
    uint256[] public contractionPercent;

    address public strategist;

    mapping(address => uint256) public maxAmountToTrade; // MEE, BUSD, WBNB

    address public shareRewardPool = address(0xecC17b190581C60811862E5dF8c9183dA98BD08a);
    mapping(address => uint256) public shareRewardPoolId; // [BUSD, USDT, BDO, bCash] -> [Pool_id]: 0, 1, 3, 4
    mapping(address => address) public lpPairAddress; // [BUSD, USDT, BDO, bCash] -> [LP]: 0xD65F81878517039E39c359434d8D8bD46CC4531F, 0xd245BDb115707730136F0459e2aa9b0b19023724, ...

    /* =================== Added variables (need to keep orders for proxy to work) =================== */
    //// TO BE ADDED

    /* ========== EVENTS ========== */

    event Initialized(address indexed executor, uint256 at);
    event SwapToken(address inputToken, address outputToken, uint256 amount);
    event BoughtBonds(uint256 amount);
    event RedeemedBonds(uint256 amount);
    event ExecuteTransaction(address indexed target, uint256 value, string signature, bytes data);

    /* ========== Modifiers =============== */

    modifier onlyOperator() {
        require(operator == msg.sender, "!operator");
        _;
    }

    modifier onlyStrategist() {
        require(strategist == msg.sender || operator == msg.sender, "!strategist");
        _;
    }

    modifier notInitialized() {
        require(!initialized, "initialized");
        _;
    }

    modifier checkPublicAllow() {
        require(publicAllowed || msg.sender == operator, "!operator nor !publicAllowed");
        _;
    }

    /* ========== GOVERNANCE ========== */

    function initialize(
        address _mee,
        address _bond,
        address _share,
        address _busd,
        address _wbnb,
        address _boardroom,
        address _meeOracle,
        address _treasury,
        IUniswapV2Router _pancakeRouter
    ) public notInitialized {
        mee = _mee;
        bond = _bond;
        share = _share;
        busd = _busd;
        wbnb = _wbnb;
        boardroom = _boardroom;
        meeOracle = _meeOracle;
        treasury = _treasury;
        pancakeRouter = _pancakeRouter;
        meePriceToSell = 1500 finney; // $1.5
        meePriceToBuy = 800 finney; // $0.8
        expansionPercent = [3000, 6800, 200]; // mee (30%), BUSD (68%), WBNB (2%) during expansion period
        contractionPercent = [8800, 1160, 40]; // mee (88%), BUSD (11.6%), WBNB (0.4%) during contraction period
        publicAllowed = true;
        initialized = true;
        operator = msg.sender;
        strategist = msg.sender;
        emit Initialized(msg.sender, block.number);
    }

    function setOperator(address _operator) external onlyOperator {
        operator = _operator;
    }

    function setStrategist(address _strategist) external onlyOperator {
        strategist = _strategist;
    }

    function setTreasury(address _treasury) external onlyOperator {
        treasury = _treasury;
    }

    function setShareRewardPool(address _shareRewardPool) external onlyOperator {
        shareRewardPool = _shareRewardPool;
    }

    function setShareRewardPoolId(address _tokenB, uint256 _pid) external onlyStrategist {
        shareRewardPoolId[_tokenB] = _pid;
    }

    function setLpPairAddress(address _tokenB, address _lpAdd) external onlyStrategist {
        lpPairAddress[_tokenB] = _lpAdd;
    }

    function setDollarOracle(address _meeOracle) external onlyOperator {
        meeOracle = _meeOracle;
    }

    function setPublicAllowed(bool _publicAllowed) external onlyStrategist {
        publicAllowed = _publicAllowed;
    }

    function setExpansionPercent(uint256 _meePercent, uint256 _busdPercent, uint256 _wbnbPercent) external onlyStrategist {
        require(_meePercent.add(_busdPercent).add(_wbnbPercent) == 10000, "!100%");
        expansionPercent[0] = _meePercent;
        expansionPercent[1] = _busdPercent;
        expansionPercent[2] = _wbnbPercent;
    }

    function setContractionPercent(uint256 _meePercent, uint256 _busdPercent, uint256 _wbnbPercent) external onlyStrategist {
        require(_meePercent.add(_busdPercent).add(_wbnbPercent) == 10000, "!100%");
        contractionPercent[0] = _meePercent;
        contractionPercent[1] = _busdPercent;
        contractionPercent[2] = _wbnbPercent;
    }

    function setMaxAmountToTrade(uint256 _meeAmount, uint256 _busdAmount, uint256 _wbnbAmount) external onlyStrategist {
        maxAmountToTrade[mee] = _meeAmount;
        maxAmountToTrade[busd] = _busdAmount;
        maxAmountToTrade[wbnb] = _wbnbAmount;
    }

    function setDollarPriceToSell(uint256 _meePriceToSell) external onlyStrategist {
        require(_meePriceToSell >= 950 finney && _meePriceToSell <= 2000 finney, "out of range"); // [$0.95, $2.00]
        meePriceToSell = _meePriceToSell;
    }

    function setDollarPriceToBuy(uint256 _meePriceToBuy) external onlyStrategist {
        require(_meePriceToBuy >= 500 finney && _meePriceToBuy <= 1050 finney, "out of range"); // [$0.50, $1.05]
        meePriceToBuy = _meePriceToBuy;
    }

    function setUnirouterPath(address _input, address _output, address[] memory _path) external onlyStrategist {
        uniswapPaths[_input][_output] = _path;
    }

    function setTokenAddresses(address _busd, address _usdt, address _bdo, address _bcash, address _wbnb) external onlyOperator {
        busd = _busd;
        usdt = _usdt;
        bdo = _bdo;
        bcash = _bcash;
        wbnb = _wbnb;
    }

    function withdrawShare(uint256 _amount) external onlyStrategist {
        IBoardroom(boardroom).withdraw(_amount);
    }

    function exitBoardroom() external onlyStrategist {
        IBoardroom(boardroom).exit();
    }

    function grandFund(address _token, uint256 _amount, address _to) external onlyOperator {
        IERC20(_token).transfer(_to, _amount);
    }

    /* ========== VIEW FUNCTIONS ========== */

    function earned() public view returns (uint256) {
        return IBoardroom(boardroom).earned(address(this));
    }

    function tokenBalances() public view returns (uint256 _meeBal, uint256 _busdBal, uint256 _wbnbBal, uint256 _totalBal) {
        _meeBal = IERC20(mee).balanceOf(address(this));
        _busdBal = IERC20(busd).balanceOf(address(this));
        _wbnbBal = IERC20(wbnb).balanceOf(address(this));
        _totalBal = _meeBal.add(_busdBal).add(_wbnbBal);
    }

    function tokenPercents() public view returns (uint256 _meePercent, uint256 _busdPercent, uint256 _wbnbPercent) {
        (uint256 _meeBal, uint256 _busdBal, uint256 _wbnbBal, uint256 _totalBal) = tokenBalances();
        if (_totalBal > 0) {
            _meePercent = _meeBal.mul(10000).div(_totalBal);
            _busdPercent = _busdBal.mul(10000).div(_totalBal);
            _wbnbPercent = _wbnbBal.mul(10000).div(_totalBal);
        }
    }

    function getEthPrice() public view returns (uint256 meePrice) {
        try IOracle(meeOracle).consult(mee, 1e18) returns (uint144 price) {
            return uint256(price);
        } catch {
            revert("failed to consult price");
        }
    }

    function getEthUpdatedPrice() public view returns (uint256 _meePrice) {
        try IOracle(meeOracle).twap(mee, 1e18) returns (uint144 price) {
            return uint256(price);
        } catch {
            revert("failed to consult price");
        }
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function collectShareRewards() public checkPublicAllow {
        if (IShare(share).unclaimedTreasuryFund() > 0) {
            IShare(share).claimRewards();
        }
    }

    function claimAndRestake() public checkPublicAllow {
        if (IBoardroom(boardroom).canClaimReward(address(this))) {// only restake more if at this epoch we could claim pending mee rewards
            if (earned() > 0) {
                IBoardroom(boardroom).claimReward();
            }
            uint256 _shareBal = IERC20(share).balanceOf(address(this));
            if (_shareBal > 0) {
                IERC20(share).safeApprove(boardroom, 0);
                IERC20(share).safeApprove(boardroom, _shareBal);
                IBoardroom(boardroom).stake(_shareBal);
            }
        }
    }

    function rebalance() public checkPublicAllow {
        (uint256 _meeBal, uint256 _busdBal, uint256 _wbnbBal, uint256 _totalBal) = tokenBalances();
        if (_totalBal > 0) {
            uint256 _meePercent = _meeBal.mul(10000).div(_totalBal);
            uint256 _busdPercent = _busdBal.mul(10000).div(_totalBal);
            uint256 _wbnbPercent = _wbnbBal.mul(10000).div(_totalBal);
            uint256 _meePrice = getEthUpdatedPrice();
            if (_meePrice >= meePriceToSell) {// expansion: sell MEE
                if (_meePercent > expansionPercent[0]) {
                    uint256 _sellingMee = _meeBal.mul(_meePercent.sub(expansionPercent[0])).div(10000);
                    if (_busdPercent >= expansionPercent[1]) {// enough BUSD
                        if (_wbnbPercent < expansionPercent[2]) {// short of WBNB: buy WBNB
                            _swapToken(mee, wbnb, _sellingMee);
                        } else {
                            if (_busdPercent.sub(expansionPercent[1]) <= _wbnbPercent.sub(expansionPercent[2])) {// has more WBNB than BUSD: buy BUSD
                                _swapToken(mee, busd, _sellingMee);
                            } else {// has more BUSD than WBNB: buy WBNB
                                _swapToken(mee, wbnb, _sellingMee);
                            }
                        }
                    } else {// short of BUSD
                        if (_wbnbPercent >= expansionPercent[2]) {// enough WBNB: buy BUSD
                            _swapToken(mee, busd, _sellingMee);
                        } else {// short of WBNB
                            uint256 _sellingMeeToBusd = _sellingMee.div(2);
                            _swapToken(mee, busd, _sellingMeeToBusd);
                            _swapToken(mee, wbnb, _sellingMee.sub(_sellingMeeToBusd));
                        }
                    }
                }
            } else if (_meePrice <= meePriceToBuy && (msg.sender == operator || msg.sender == strategist)) {// contraction: buy MEE
                if (_busdPercent >= contractionPercent[1]) {// enough BUSD
                    if (_wbnbPercent <= contractionPercent[2]) {// short of WBNB: sell BUSD
                        uint256 _sellingBUSD = _busdBal.mul(_busdPercent.sub(contractionPercent[1])).div(10000);
                        _swapToken(busd, mee, _sellingBUSD);
                    } else {
                        if (_busdPercent.sub(contractionPercent[1]) > _wbnbPercent.sub(contractionPercent[2])) {// has more BUSD than WBNB: sell BUSD
                            uint256 _sellingBUSD = _busdBal.mul(_busdPercent.sub(contractionPercent[1])).div(10000);
                            _swapToken(busd, mee, _sellingBUSD);
                        } else {// has more WBNB than BUSD: sell WBNB
                            uint256 _sellingWBNB = _wbnbBal.mul(_wbnbPercent.sub(contractionPercent[2])).div(10000);
                            _swapToken(wbnb, mee, _sellingWBNB);
                        }
                    }
                } else {// short of BUSD
                    if (_wbnbPercent > contractionPercent[2]) {// enough WBNB: sell WBNB
                        uint256 _sellingWBNB = _wbnbBal.mul(_wbnbPercent.sub(contractionPercent[2])).div(10000);
                        _swapToken(wbnb, mee, _sellingWBNB);
                    }
                }
            }
        }
    }

    function workForDaoFund() external checkPublicAllow {
        collectShareRewards();
        claimAllRewardFromSharePool();
        claimAndRestake();
        rebalance();
    }

    function buyBonds(uint256 _meeAmount) external onlyStrategist {
        uint256 _meePrice = ITreasury(treasury).getEthPrice();
        ITreasury(treasury).buyBonds(_meeAmount, _meePrice);
        emit BoughtBonds(_meeAmount);
    }

    function redeemBonds(uint256 _bondAmount) external onlyStrategist {
        uint256 _meePrice = ITreasury(treasury).getEthPrice();
        ITreasury(treasury).redeemBonds(_bondAmount, _meePrice);
        emit RedeemedBonds(_bondAmount);
    }

    function forceSell(address _buyingToken, uint256 _meeAmount) external onlyStrategist {
        require(getEthUpdatedPrice() >= meePriceToBuy, "price is too low to sell");
        _swapToken(mee, _buyingToken, _meeAmount);
    }

    function forceBuy(address _sellingToken, uint256 _sellingAmount) external onlyStrategist {
        require(getEthUpdatedPrice() <= meePriceToSell, "price is too high to buy");
        _swapToken(_sellingToken, mee, _sellingAmount);
    }

    function trimNonCoreToken(address _sellingToken) public onlyStrategist {
        require(_sellingToken != mee &&
        _sellingToken != bond && _sellingToken != share &&
        _sellingToken != busd && _sellingToken != wbnb, "core");
        uint256 _bal = IERC20(_sellingToken).balanceOf(address(this));
        if (_bal > 0) {
            _swapToken(_sellingToken, mee, _bal);
        }
    }

    function _swapToken(address _inputToken, address _outputToken, uint256 _amount) internal {
        if (_amount == 0) return;
        uint256 _maxAmount = maxAmountToTrade[_inputToken];
        if (_maxAmount > 0 && _maxAmount < _amount) {
            _amount = _maxAmount;
        }
        address[] memory _path = uniswapPaths[_inputToken][_outputToken];
        if (_path.length == 0) {
            _path = new address[](2);
            _path[0] = _inputToken;
            _path[1] = _outputToken;
        }
        IERC20(_inputToken).safeApprove(address(pancakeRouter), 0);
        IERC20(_inputToken).safeApprove(address(pancakeRouter), _amount);
        pancakeRouter.swapExactTokensForTokens(_amount, 1, _path, address(this), now.add(1800));
    }

    function _addLiquidity(address _tokenB, uint256 _amountADesired) internal {
        // tokenA is always MEE
        _addLiquidity2(mee, _tokenB, _amountADesired, IERC20(_tokenB).balanceOf(address(this)));
    }

    function _removeLiquidity(address _lpAdd, address _tokenB, uint256 _liquidity) internal {
        // tokenA is always MEE
        _removeLiquidity2(_lpAdd, mee, _tokenB, _liquidity);
    }

    function _addLiquidity2(address _tokenA, address _tokenB, uint256 _amountADesired, uint256 amountBDesired) internal {
        IERC20(_tokenA).safeApprove(address(pancakeRouter), 0);
        IERC20(_tokenA).safeApprove(address(pancakeRouter), type(uint256).max);
        IERC20(_tokenB).safeApprove(address(pancakeRouter), 0);
        IERC20(_tokenB).safeApprove(address(pancakeRouter), type(uint256).max);
        // addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, to, deadline)
        pancakeRouter.addLiquidity(_tokenA, _tokenB, _amountADesired, amountBDesired, 0, 0, address(this), now.add(1800));
    }

    function _removeLiquidity2(address _lpAdd, address _tokenA, address _tokenB, uint256 _liquidity) internal {
        IERC20(_lpAdd).safeApprove(address(pancakeRouter), 0);
        IERC20(_lpAdd).safeApprove(address(pancakeRouter), _liquidity);
        // removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline)
        pancakeRouter.removeLiquidity(_tokenA, _tokenB, _liquidity, 1, 1, address(this), now.add(1800));
    }

    /* ========== PROVIDE LP AND STAKE TO SHARE POOL ========== */

    function depositToSharePool(address _tokenB, uint256 _meeAmount) external onlyStrategist {
        address _lpAdd = lpPairAddress[_tokenB];
        uint256 _before = IERC20(_lpAdd).balanceOf(address(this));
        _addLiquidity(_tokenB, _meeAmount);
        uint256 _after = IERC20(_lpAdd).balanceOf(address(this));
        uint256 _lpBal = _after.sub(_before);
        require(_lpBal > 0, "!_lpBal");
        address _shareRewardPool = shareRewardPool;
        uint256 _pid = shareRewardPoolId[_tokenB];
        IERC20(_lpAdd).safeApprove(_shareRewardPool, 0);
        IERC20(_lpAdd).safeApprove(_shareRewardPool, _lpBal);
        IShareRewardPool(_shareRewardPool).deposit(_pid, _lpBal);
    }

    function withdrawFromSharePool(address _tokenB, uint256 _lpAmount) public onlyStrategist {
        address _lpAdd = lpPairAddress[_tokenB];
        address _shareRewardPool = shareRewardPool;
        uint256 _pid = shareRewardPoolId[_tokenB];
        IShareRewardPool(_shareRewardPool).withdraw(_pid, _lpAmount);
        _removeLiquidity(_lpAdd, _tokenB, _lpAmount);
    }

    function exitSharePool(address _tokenB) public onlyStrategist {
        (uint _stakedAmount,) = IShareRewardPool(shareRewardPool).userInfo(shareRewardPoolId[_tokenB], address(this));
        withdrawFromSharePool(_tokenB, _stakedAmount);
    }

    function exitAllSharePool() external {
        if (stakeAmountFromSharePool(busd) > 0) exitSharePool(busd);
        if (stakeAmountFromSharePool(wbnb) > 0) exitSharePool(wbnb);
    }

    function claimRewardFromSharePool(address _tokenB) public {
        uint256 _pid = shareRewardPoolId[_tokenB];
        IShareRewardPool(shareRewardPool).withdraw(_pid, 0);
    }

    function claimAllRewardFromSharePool() public {
        if (pendingFromSharePool(busd) > 0) claimRewardFromSharePool(busd);
        if (pendingFromSharePool(wbnb) > 0) claimRewardFromSharePool(wbnb);
    }

    function pendingFromSharePool(address _tokenB) public view returns(uint256) {
        return IShareRewardPool(shareRewardPool).pendingShare(shareRewardPoolId[_tokenB], address(this));
    }

    function pendingAllFromSharePool() public view returns(uint256) {
        return pendingFromSharePool(busd).add(pendingFromSharePool(wbnb));
    }

    function stakeAmountFromSharePool(address _tokenB) public view returns(uint256 _stakedAmount) {
        (_stakedAmount, ) = IShareRewardPool(shareRewardPool).userInfo(shareRewardPoolId[_tokenB], address(this));
    }

    function stakeAmountAllFromSharePool() public view returns(uint256 _bnbPoolStakedAmount, uint256 _wbnbPoolStakedAmount) {
        _bnbPoolStakedAmount = stakeAmountFromSharePool(busd);
        _wbnbPoolStakedAmount = stakeAmountFromSharePool(wbnb);
    }

    /* ========== EMERGENCY ========== */

    function executeTransaction(address target, uint256 value, string memory signature, bytes memory data) public onlyOperator returns (bytes memory) {
        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, string("CommunityFund::executeTransaction: Transaction execution reverted."));

        emit ExecuteTransaction(target, value, signature, data);

        return returnData;
    }

    receive() external payable {}
}
