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

/**
 * @dev This contract will collect vesting Shares, stake to the Boardroom and rebalance BDO, BUSD, WBNB according to DAO.
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

    // DAO parameters - https://docs.basisdollar.fi/DAO
    uint256[] public expansionPercent;
    uint256[] public contractionPercent;

    /* =================== Added variables (need to keep orders for proxy to work) =================== */
    address public strategist;
    address public dollarOracle = address(0xfAB911c54f7CF3ffFdE0482d2267a751D87B5B20);
    address public treasury = address(0x15A90e6157a870CD335AF03c6df776d0B1ebf94F);
    mapping(address => uint256) public maxAmountToTrade; // BDO, BUSD, WBNB

    /* ========== EVENTS ========== */

    event Initialized(address indexed executor, uint256 at);
    event SwapToken(address inputToken, address outputToken, uint256 amount);
    event BoughtBonds(uint256 amount);
    event RedeemedBonds(uint256 amount);
    event ExecuteTransaction(address indexed target, uint256 value, string signature, bytes data);

    /* ========== Modifiers =============== */

    modifier onlyOperator() {
        require(operator == msg.sender, "CommunityFund: caller is not the operator");
        _;
    }

    modifier onlyStrategist() {
        require(strategist == msg.sender || operator == msg.sender, "CommunityFund: caller is not a strategist");
        _;
    }

    modifier notInitialized() {
        require(!initialized, "CommunityFund: already initialized");
        _;
    }

    modifier checkPublicAllow() {
        require(publicAllowed || msg.sender == operator, "CommunityFund: caller is not the operator nor public call not allowed");
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
        require(_dollarPriceToSell >= 950 finney && _dollarPriceToSell <= 2000 finney, "_dollarPriceToSell: out of range"); // [$0.95, $2.00]
        dollarPriceToSell = _dollarPriceToSell;
    }

    function setDollarPriceToBuy(uint256 _dollarPriceToBuy) external onlyStrategist {
        require(_dollarPriceToBuy >= 500 finney && _dollarPriceToBuy <= 1050 finney, "_dollarPriceToBuy: out of range"); // [$0.50, $1.05]
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
            revert("CommunityFund: failed to consult dollar price from the oracle");
        }
    }

    function getDollarUpdatedPrice() public view returns (uint256 _dollarPrice) {
        try IOracle(dollarOracle).twap(dollar, 1e18) returns (uint144 price) {
            return uint256(price);
        } catch {
            revert("Treasury: failed to consult dollar price from the oracle");
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
            uint256 _dollarPrice = getDollarPrice();
            if (_dollarPrice >= dollarPriceToSell) {// expansion: sell BDO
                if (_dollarPercent > expansionPercent[0]) {
                    uint256 _sellingBdo = _dollarBal.mul(_dollarPercent.sub(expansionPercent[0])).div(10000);
                    if (_busdPercent >= expansionPercent[1]) {// enough BUSD
                        if (_wbnbPercent < expansionPercent[2]) {// short of WBNB: buy WBNB
                            _swapToken(dollar, wbnb, _sellingBdo);
                        } else {
                            if (_busdPercent.sub(expansionPercent[1]) <= _wbnbPercent.sub(expansionPercent[2])) {// has more WBNB than BUSD: buy BUSD
                                _swapToken(dollar, busd, _sellingBdo);
                            } else {// has more BUSD than WBNB: buy WBNB
                                _swapToken(dollar, wbnb, _sellingBdo);
                            }
                        }
                    } else {// short of BUSD
                        if (_wbnbPercent >= expansionPercent[2]) {// enough WBNB: buy BUSD
                            _swapToken(dollar, busd, _sellingBdo);
                        } else {// short of WBNB
                            uint256 _sellingBdoToBusd = _sellingBdo.div(2);
                            _swapToken(dollar, busd, _sellingBdoToBusd);
                            _swapToken(dollar, wbnb, _sellingBdo.sub(_sellingBdoToBusd));
                        }
                    }
                }
            } else if (_dollarPrice <= dollarPriceToBuy && (msg.sender == operator || msg.sender == strategist)) {// contraction: buy BDO
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
        require(getDollarPrice() >= dollarPriceToBuy, "CommunityFund: price is too low to sell");
        _swapToken(dollar, _buyingToken, _dollarAmount);
    }

    function forceBuy(address _sellingToken, uint256 _sellingAmount) external onlyStrategist {
        require(getDollarPrice() <= dollarPriceToSell, "CommunityFund: price is too high to buy");
        _swapToken(_sellingToken, dollar, _sellingAmount);
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
        pancakeRouter.swapExactTokensForTokens(_amount, 1, _path, address(this), now.add(1800));
    }

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
