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
 * @dev This contract will collect vesting Shares, stake to the Boardroom and rebalance MDO, BUSD, WBNB according to DAO.
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
    uint256 public dollarPriceToSell; // to rebalance when expansion
    uint256 public dollarPriceToBuy; // to rebalance when contraction

    address public dollar = address(0x190b589cf9Fb8DDEabBFeae36a813FFb2A702454);
    address public bond = address(0x9586b02B09bd68A7cD4aa9167a61B78F43092063);
    address public share = address(0x0d9319565be7f53CeFE84Ad201Be3f40feAE2740);

    address public busd = address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    address public wbnb = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    address public boardroom = address(0x9D39cd20901c88030032073Fb014AaF79D84d2C5);

    // Pancakeswap
    IUniswapV2Router public pancakeRouter = IUniswapV2Router(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F);
    mapping(address => mapping(address => address[])) public uniswapPaths;

    // DAO parameters - https://docs.midasdollar.fi/DAO
    uint256[] public expansionPercent;
    uint256[] public contractionPercent;

    /* =================== Added variables (need to keep orders for proxy to work) =================== */
    address public strategist;
    address public dollarOracle = address(0xfAB911c54f7CF3ffFdE0482d2267a751D87B5B20);
    address public treasury = address(0x15A90e6157a870CD335AF03c6df776d0B1ebf94F);

    mapping(address => uint256) public maxAmountToTrade; // MDO, BUSD, WBNB

    address public shareRewardPool = address(0x948dB1713D4392EC04C86189070557C5A8566766);
    mapping(address => uint256) public shareRewardPoolId; // [BUSD, WBNB] -> [Pool_id]: 0, 2
    mapping(address => address) public lpPairAddress; // [BUSD, WBNB] -> [LP]: 0xc5b0d73A7c0E4eaF66baBf7eE16A2096447f7aD6, 0x74690f829fec83ea424ee1F1654041b2491A7bE9

    address public pancakeFarmingPool = address(0x73feaa1eE314F8c655E354234017bE2193C9E24E);
    uint256 public pancakeFarmingPoolId = 66;
    address public pancakeFarmingPoolLpPairAddress = address(0x74690f829fec83ea424ee1F1654041b2491A7bE9); // MDO/WBNB
    address public cake = address(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82); // CAKE (pancakePool farming token)

    address public kebabFarmingPool = address(0x76FCeffFcf5325c6156cA89639b17464ea833ECd);
    uint256 public kebabFarmingPoolId = 2;
    address public kebabFarmingPoolLpPairAddress = address(0x1B96B92314C44b159149f7E0303511fB2Fc4774f); // BUSD/WBNB
    address public kebab = address(0x7979F6C54ebA05E18Ded44C4F986F49a5De551c2); // KEBAB (kebabPool farming token)

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
        address _dollar,
        address _bond,
        address _share,
        address _busd,
        address _wbnb,
        address _boardroom,
        IUniswapV2Router _pancakeRouter
    ) public notInitialized {
        dollar = _dollar;
        bond = _bond;
        share = _share;
        busd = _busd;
        wbnb = _wbnb;
        boardroom = _boardroom;
        pancakeRouter = _pancakeRouter;
        dollarPriceToSell = 1500 finney; // $1.5
        dollarPriceToBuy = 800 finney; // $0.8
        expansionPercent = [3000, 6800, 200]; // dollar (30%), BUSD (68%), WBNB (2%) during expansion period
        contractionPercent = [8800, 1160, 40]; // dollar (88%), BUSD (11.6%), WBNB (0.4%) during contraction period
        publicAllowed = true;
        initialized = true;
        operator = msg.sender;
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

    function setPancakeFarmingPool(address _pancakeFarmingPool, uint256 _pancakeFarmingPoolId, address _pancakeFarmingPoolLpPairAddress, address _cake) external onlyOperator {
        pancakeFarmingPool = _pancakeFarmingPool;
        pancakeFarmingPoolId = _pancakeFarmingPoolId;
        pancakeFarmingPoolLpPairAddress = _pancakeFarmingPoolLpPairAddress;
        cake = _cake;
    }

    function setKebabFarmingPool(address _kebabFarmingPool, uint256 _kebabFarmingPoolId, address _kebabFarmingPoolLpPairAddress, address _kebab) external onlyOperator {
        kebabFarmingPool = _kebabFarmingPool;
        kebabFarmingPoolId = _kebabFarmingPoolId;
        kebabFarmingPoolLpPairAddress = _kebabFarmingPoolLpPairAddress;
        kebab = _kebab;
    }

    function setDollarOracle(address _dollarOracle) external onlyOperator {
        dollarOracle = _dollarOracle;
    }

    function setPublicAllowed(bool _publicAllowed) external onlyStrategist {
        publicAllowed = _publicAllowed;
    }

    function setExpansionPercent(uint256 _dollarPercent, uint256 _busdPercent, uint256 _wbnbPercent) external onlyStrategist {
        require(_dollarPercent.add(_busdPercent).add(_wbnbPercent) == 10000, "!100%");
        expansionPercent[0] = _dollarPercent;
        expansionPercent[1] = _busdPercent;
        expansionPercent[2] = _wbnbPercent;
    }

    function setContractionPercent(uint256 _dollarPercent, uint256 _busdPercent, uint256 _wbnbPercent) external onlyStrategist {
        require(_dollarPercent.add(_busdPercent).add(_wbnbPercent) == 10000, "!100%");
        contractionPercent[0] = _dollarPercent;
        contractionPercent[1] = _busdPercent;
        contractionPercent[2] = _wbnbPercent;
    }

    function setMaxAmountToTrade(uint256 _dollarAmount, uint256 _busdAmount, uint256 _wbnbAmount) external onlyStrategist {
        maxAmountToTrade[dollar] = _dollarAmount;
        maxAmountToTrade[busd] = _busdAmount;
        maxAmountToTrade[wbnb] = _wbnbAmount;
    }

    function setDollarPriceToSell(uint256 _dollarPriceToSell) external onlyStrategist {
        require(_dollarPriceToSell >= 950 finney && _dollarPriceToSell <= 2000 finney, "out of range"); // [$0.95, $2.00]
        dollarPriceToSell = _dollarPriceToSell;
    }

    function setDollarPriceToBuy(uint256 _dollarPriceToBuy) external onlyStrategist {
        require(_dollarPriceToBuy >= 500 finney && _dollarPriceToBuy <= 1050 finney, "out of range"); // [$0.50, $1.05]
        dollarPriceToBuy = _dollarPriceToBuy;
    }

    function setUnirouterPath(address _input, address _output, address[] memory _path) external onlyStrategist {
        uniswapPaths[_input][_output] = _path;
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

    function tokenBalances() public view returns (uint256 _dollarBal, uint256 _busdBal, uint256 _wbnbBal, uint256 _totalBal) {
        _dollarBal = IERC20(dollar).balanceOf(address(this));
        _busdBal = IERC20(busd).balanceOf(address(this));
        _wbnbBal = IERC20(wbnb).balanceOf(address(this));
        _totalBal = _dollarBal.add(_busdBal).add(_wbnbBal);
    }

    function tokenPercents() public view returns (uint256 _dollarPercent, uint256 _busdPercent, uint256 _wbnbPercent) {
        (uint256 _dollarBal, uint256 _busdBal, uint256 _wbnbBal, uint256 _totalBal) = tokenBalances();
        if (_totalBal > 0) {
            _dollarPercent = _dollarBal.mul(10000).div(_totalBal);
            _busdPercent = _busdBal.mul(10000).div(_totalBal);
            _wbnbPercent = _wbnbBal.mul(10000).div(_totalBal);
        }
    }

    function getDollarPrice() public view returns (uint256 dollarPrice) {
        try IOracle(dollarOracle).consult(dollar, 1e18) returns (uint144 price) {
            return uint256(price);
        } catch {
            revert("failed to consult price");
        }
    }

    function getDollarUpdatedPrice() public view returns (uint256 _dollarPrice) {
        try IOracle(dollarOracle).twap(dollar, 1e18) returns (uint144 price) {
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
        if (IBoardroom(boardroom).canClaimReward(address(this))) {// only restake more if at this epoch we could claim pending dollar rewards
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
        (uint256 _dollarBal, uint256 _busdBal, uint256 _wbnbBal, uint256 _totalBal) = tokenBalances();
        if (_totalBal > 0) {
            uint256 _dollarPercent = _dollarBal.mul(10000).div(_totalBal);
            uint256 _busdPercent = _busdBal.mul(10000).div(_totalBal);
            uint256 _wbnbPercent = _wbnbBal.mul(10000).div(_totalBal);
            uint256 _dollarPrice = getDollarUpdatedPrice();
            if (_dollarPrice >= dollarPriceToSell) {// expansion: sell MDO
                if (_dollarPercent > expansionPercent[0]) {
                    uint256 _sellingMdo = _dollarBal.mul(_dollarPercent.sub(expansionPercent[0])).div(10000);
                    if (_busdPercent >= expansionPercent[1]) {// enough BUSD
                        if (_wbnbPercent < expansionPercent[2]) {// short of WBNB: buy WBNB
                            _swapToken(dollar, wbnb, _sellingMdo);
                        } else {
                            if (_busdPercent.sub(expansionPercent[1]) <= _wbnbPercent.sub(expansionPercent[2])) {// has more WBNB than BUSD: buy BUSD
                                _swapToken(dollar, busd, _sellingMdo);
                            } else {// has more BUSD than WBNB: buy WBNB
                                _swapToken(dollar, wbnb, _sellingMdo);
                            }
                        }
                    } else {// short of BUSD
                        if (_wbnbPercent >= expansionPercent[2]) {// enough WBNB: buy BUSD
                            _swapToken(dollar, busd, _sellingMdo);
                        } else {// short of WBNB
                            uint256 _sellingMdoToBusd = _sellingMdo.div(2);
                            _swapToken(dollar, busd, _sellingMdoToBusd);
                            _swapToken(dollar, wbnb, _sellingMdo.sub(_sellingMdoToBusd));
                        }
                    }
                }
            } else if (_dollarPrice <= dollarPriceToBuy && (msg.sender == operator || msg.sender == strategist)) {// contraction: buy MDO
                if (_busdPercent >= contractionPercent[1]) {// enough BUSD
                    if (_wbnbPercent <= contractionPercent[2]) {// short of WBNB: sell BUSD
                        uint256 _sellingBUSD = _busdBal.mul(_busdPercent.sub(contractionPercent[1])).div(10000);
                        _swapToken(busd, dollar, _sellingBUSD);
                    } else {
                        if (_busdPercent.sub(contractionPercent[1]) > _wbnbPercent.sub(contractionPercent[2])) {// has more BUSD than WBNB: sell BUSD
                            uint256 _sellingBUSD = _busdBal.mul(_busdPercent.sub(contractionPercent[1])).div(10000);
                            _swapToken(busd, dollar, _sellingBUSD);
                        } else {// has more WBNB than BUSD: sell WBNB
                            uint256 _sellingWBNB = _wbnbBal.mul(_wbnbPercent.sub(contractionPercent[2])).div(10000);
                            _swapToken(wbnb, dollar, _sellingWBNB);
                        }
                    }
                } else {// short of BUSD
                    if (_wbnbPercent > contractionPercent[2]) {// enough WBNB: sell WBNB
                        uint256 _sellingWBNB = _wbnbBal.mul(_wbnbPercent.sub(contractionPercent[2])).div(10000);
                        _swapToken(wbnb, dollar, _sellingWBNB);
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

    function buyBonds(uint256 _dollarAmount) external onlyStrategist {
        uint256 _dollarPrice = ITreasury(treasury).getDollarPrice();
        ITreasury(treasury).buyBonds(_dollarAmount, _dollarPrice);
        emit BoughtBonds(_dollarAmount);
    }

    function redeemBonds(uint256 _bondAmount) external onlyStrategist {
        uint256 _dollarPrice = ITreasury(treasury).getDollarPrice();
        ITreasury(treasury).redeemBonds(_bondAmount, _dollarPrice);
        emit RedeemedBonds(_bondAmount);
    }

    function forceSell(address _buyingToken, uint256 _dollarAmount) external onlyStrategist {
        require(getDollarUpdatedPrice() >= dollarPriceToBuy, "price is too low to sell");
        _swapToken(dollar, _buyingToken, _dollarAmount);
    }

    function forceBuy(address _sellingToken, uint256 _sellingAmount) external onlyStrategist {
        require(getDollarUpdatedPrice() <= dollarPriceToSell, "price is too high to buy");
        _swapToken(_sellingToken, dollar, _sellingAmount);
    }

    function trimNonCoreToken(address _sellingToken) public onlyStrategist {
        require(_sellingToken != dollar &&
        _sellingToken != bond && _sellingToken != share &&
        _sellingToken != busd && _sellingToken != wbnb, "core");
        uint256 _bal = IERC20(_sellingToken).balanceOf(address(this));
        if (_bal > 0) {
            _swapToken(_sellingToken, dollar, _bal);
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
        // tokenA is always MDO
        _addLiquidity2(dollar, _tokenB, _amountADesired, IERC20(_tokenB).balanceOf(address(this)));
    }

    function _removeLiquidity(address _lpAdd, address _tokenB, uint256 _liquidity) internal {
        // tokenA is always MDO
        _removeLiquidity2(_lpAdd, dollar, _tokenB, _liquidity);
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

    function depositToSharePool(address _tokenB, uint256 _dollarAmount) external onlyStrategist {
        address _lpAdd = lpPairAddress[_tokenB];
        uint256 _before = IERC20(_lpAdd).balanceOf(address(this));
        _addLiquidity(_tokenB, _dollarAmount);
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

    /* ========== FARM PANCAKESWAP POOL: STAKE MDO/BUSD EARN CAKE ========== */

    function depositToPancakePool(uint256 _dollarAmount) external onlyStrategist {
        address _lpAdd = pancakeFarmingPoolLpPairAddress;
        uint256 _before = IERC20(_lpAdd).balanceOf(address(this));
        _addLiquidity(wbnb, _dollarAmount);
        uint256 _after = IERC20(_lpAdd).balanceOf(address(this));
        uint256 _lpBal = _after.sub(_before);
        require(_lpBal > 0, "!_lpBal");
        address _pancakeFarmingPool = pancakeFarmingPool;
        IERC20(_lpAdd).safeApprove(_pancakeFarmingPool, 0);
        IERC20(_lpAdd).safeApprove(_pancakeFarmingPool, _lpBal);
        IPancakeswapPool(_pancakeFarmingPool).deposit(pancakeFarmingPoolId, _lpBal);
    }

    function withdrawFromPancakePool(uint256 _lpAmount) public onlyStrategist {
        IPancakeswapPool(pancakeFarmingPool).withdraw(pancakeFarmingPoolId, _lpAmount);
        _removeLiquidity(pancakeFarmingPoolLpPairAddress, wbnb, _lpAmount);
    }

    function exitPancakePool() public onlyStrategist {
        (uint256 _stakedAmount, ) = IPancakeswapPool(pancakeFarmingPool).userInfo(pancakeFarmingPoolId, address(this));
        withdrawFromPancakePool(_stakedAmount);
        uint256 _bal = IERC20(cake).balanceOf(address(this));
        if (_bal > 0) {
            trimNonCoreToken(cake);
        }
    }

    function claimAndReinvestFromPancakePool() public {
        IPancakeswapPool(pancakeFarmingPool).withdraw(pancakeFarmingPoolId, 0);
        uint256 _cakeBal = IERC20(cake).balanceOf(address(this));
        if (_cakeBal > 0) {
            uint256 _wbnbBef = IERC20(wbnb).balanceOf(address(this));
            _swapToken(cake, wbnb, _cakeBal);
            uint256 _wbnbAft = IERC20(wbnb).balanceOf(address(this));
            uint256 _boughtWbnb = _wbnbAft.sub(_wbnbBef);
            if (_boughtWbnb >= 2) {
                uint256 _dollarBef = IERC20(dollar).balanceOf(address(this));
                _swapToken(wbnb, dollar, _boughtWbnb.div(2));
                uint256 _dollarAft = IERC20(dollar).balanceOf(address(this));
                uint256 _boughtDollar = _dollarAft.sub(_dollarBef);
                _addLiquidity(wbnb, _boughtDollar);
            }
        }
        address _lpAdd = pancakeFarmingPoolLpPairAddress;
        uint256 _lpBal = IERC20(_lpAdd).balanceOf(address(this));
        if (_lpBal > 0) {
            address _pancakeFarmingPool = pancakeFarmingPool;
            IERC20(_lpAdd).safeApprove(_pancakeFarmingPool, 0);
            IERC20(_lpAdd).safeApprove(_pancakeFarmingPool, _lpBal);
            IPancakeswapPool(_pancakeFarmingPool).deposit(pancakeFarmingPoolId, _lpBal);
        }
    }

    function pendingFromPancakePool() public view returns(uint256) {
        return IPancakeswapPool(pancakeFarmingPool).pendingCake(pancakeFarmingPoolId, address(this));
    }

    function stakeAmountFromPancakePool() public view returns(uint256 _stakedAmount) {
        (_stakedAmount, ) = IPancakeswapPool(pancakeFarmingPool).userInfo(pancakeFarmingPoolId, address(this));
    }

    /* ========== FARM KEBAB POOL: STAKE BUSD/WBNB EARN KEBAB ========== */

    function depositToKebabPool(uint256 _busdAmount, uint256 _wbnbAmount) external onlyStrategist {
        address _lpAdd = kebabFarmingPoolLpPairAddress;
        _addLiquidity2(busd, wbnb, _busdAmount, _wbnbAmount);
        uint256 _lpBal = IERC20(_lpAdd).balanceOf(address(this));
        require(_lpBal > 0, "!_lpBal");
        address _kebabFarmingPool = kebabFarmingPool;
        IERC20(_lpAdd).safeApprove(_kebabFarmingPool, 0);
        IERC20(_lpAdd).safeApprove(_kebabFarmingPool, _lpBal);
        IPancakeswapPool(_kebabFarmingPool).deposit(kebabFarmingPoolId, _lpBal);
    }

    function withdrawFromKebabPool(uint256 _lpAmount) public onlyStrategist {
        IPancakeswapPool(kebabFarmingPool).withdraw(kebabFarmingPoolId, _lpAmount);
        _removeLiquidity2(kebabFarmingPoolLpPairAddress, busd, wbnb, _lpAmount);
    }

    function exitKebabPool() public onlyStrategist {
        (uint256 _stakedAmount, ) = IPancakeswapPool(kebabFarmingPool).userInfo(kebabFarmingPoolId, address(this));
        withdrawFromKebabPool(_stakedAmount);
        uint256 _bal = IERC20(kebab).balanceOf(address(this));
        if (_bal > 0) {
            trimNonCoreToken(kebab);
        }
    }

    function claimAndReinvestFromKebabPool() public {
        IPancakeswapPool(kebabFarmingPool).withdraw(kebabFarmingPoolId, 0);
        uint256 _kebabBal = IERC20(kebab).balanceOf(address(this));
        if (_kebabBal > 0) {
            uint256 _wbnbBef = IERC20(wbnb).balanceOf(address(this));
            _swapToken(kebab, wbnb, _kebabBal);
            uint256 _wbnbAft = IERC20(wbnb).balanceOf(address(this));
            uint256 _boughtWbnb = _wbnbAft.sub(_wbnbBef);
            if (_boughtWbnb >= 2) {
                uint256 _dollarBef = IERC20(dollar).balanceOf(address(this));
                _swapToken(wbnb, dollar, _boughtWbnb.div(2));
                uint256 _dollarAft = IERC20(dollar).balanceOf(address(this));
                uint256 _boughtDollar = _dollarAft.sub(_dollarBef);
                _addLiquidity(wbnb, _boughtDollar);
                claimAndReinvestFromPancakePool();
            }
        }
    }

    function pendingFromKebabPool() public view returns(uint256) {
        return IPancakeswapPool(kebabFarmingPool).pendingCake(kebabFarmingPoolId, address(this));
    }

    function stakeAmountFromKebabPool() public view returns(uint256 _stakedAmount) {
        (_stakedAmount, ) = IPancakeswapPool(kebabFarmingPool).userInfo(kebabFarmingPoolId, address(this));
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
