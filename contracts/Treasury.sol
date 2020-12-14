// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./lib/Babylonian.sol";
import "./lib/FixedPoint.sol";
import "./lib/Safe112.sol";
import "./owner/Operator.sol";
import "./utils/ContractGuard.sol";
import "./interfaces/IBasisAsset.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IBoardroom.sol";

/**
 * @title Basis Dollar Treasury contract
 * @notice Monetary policy logic to adjust supplies of basis dollar assets
 * @author Summer Smith & Rick Sanchez
 */
contract Treasury is ContractGuard, Operator {
    using FixedPoint for *;
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    using Safe112 for uint112;

    /* ========= CONSTANT VARIABLES ======== */

    uint256 public constant PERIOD = 1 days;

    /* ========== STATE VARIABLES ========== */

    // flags
    bool private migrated = false;
    bool private initialized = false;

    // epoch
    uint256 public startTime;
    uint256 public epoch = 0;

    // core components
    address private dollar;
    address private bond;
    address private share;
    address private boardroom;
    address private dollarOracle;

    // price
    uint256 public dollarPriceOne;
    uint256 public dollarPriceCeiling;
    uint256 private bondDepletionFloor;
    uint256 private seigniorageSaved = 0;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _dollar,
        address _bond,
        address _share,
        address _dollarOracle,
        address _boardroom,
        uint256 _startTime
    ) public {
        dollar = _dollar;
        bond = _bond;
        share = _share;
        dollarOracle = _dollarOracle;
        boardroom = _boardroom;

        startTime = _startTime;

        dollarPriceOne = 10**18;
        dollarPriceCeiling = uint256(105).mul(dollarPriceOne).div(10**2);

        bondDepletionFloor = uint256(1000).mul(dollarPriceOne);
    }

    /* =================== Modifier =================== */

    modifier checkCondition {
        require(!migrated, "Treasury: migrated");
        require(now >= startTime, "Treasury: not started yet");

        _;
    }

    modifier checkEpoch {
        require(now >= nextEpochPoint(), "Treasury: not opened yet");

        _;

        epoch = epoch.add(1);
    }

    modifier checkOperator {
        require(
            IBasisAsset(dollar).operator() == address(this) &&
                IBasisAsset(bond).operator() == address(this) &&
                IBasisAsset(share).operator() == address(this) &&
                Operator(boardroom).operator() == address(this),
            "Treasury: need more permission"
        );

        _;
    }

    modifier notInitialized {
        require(!initialized, "Treasury: already initialized");

        _;
    }

    /* ========== VIEW FUNCTIONS ========== */

    // flags
    function isMigrated() public view returns (bool) {
        return migrated;
    }

    function isInitialized() public view returns (bool) {
        return initialized;
    }

    // epoch
    function nextEpochPoint() public view returns (uint256) {
        return startTime.add(epoch.mul(PERIOD));
    }

    // oracle
    function getDollarPrice() public view returns (uint256 dollarPrice) {
        try IOracle(dollarOracle).consult(dollar, 1e18) returns (uint256 price) {
            return price;
        } catch {
            revert("Treasury: failed to consult dollar price from the oracle");
        }
    }

    // budget
    function getReserve() public view returns (uint256) {
        return seigniorageSaved;
    }

    /* ========== GOVERNANCE ========== */

    function initialize() public notInitialized checkOperator {
        // burn all of it's balance
        IBasisAsset(dollar).burn(IERC20(dollar).balanceOf(address(this)));

        // mint only 1001 dollar to itself
        IBasisAsset(dollar).mint(address(this), 1001 ether);

        // set seigniorageSaved to it's balance
        seigniorageSaved = IERC20(dollar).balanceOf(address(this));

        initialized = true;
        emit Initialized(msg.sender, block.number);
    }

    function migrate(address target) public onlyOperator checkOperator {
        require(!migrated, "Treasury: migrated");

        // dollar
        Operator(dollar).transferOperator(target);
        Operator(dollar).transferOwnership(target);
        IERC20(dollar).transfer(target, IERC20(dollar).balanceOf(address(this)));

        // bond
        Operator(bond).transferOperator(target);
        Operator(bond).transferOwnership(target);
        IERC20(bond).transfer(target, IERC20(bond).balanceOf(address(this)));

        // share
        Operator(share).transferOperator(target);
        Operator(share).transferOwnership(target);
        IERC20(share).transfer(target, IERC20(share).balanceOf(address(this)));

        migrated = true;
        emit Migration(target);
    }

    /* ========== MUTABLE FUNCTIONS ========== */

    function _updateDollarPrice() internal {
        try IOracle(dollarOracle).update() {} catch {}
    }

    function buyBonds(uint256 amount, uint256 targetPrice) external onlyOneBlock checkCondition checkOperator {
        require(amount > 0, "Treasury: cannot purchase bonds with zero amount");

        uint256 dollarPrice = getDollarPrice();
        require(dollarPrice == targetPrice, "Treasury: dollar price moved");
        require(
            dollarPrice < dollarPriceOne, // price < $1
            "Treasury: dollarPrice not eligible for bond purchase"
        );

        uint256 bondPrice = dollarPrice;

        IBasisAsset(dollar).burnFrom(msg.sender, amount);
        IBasisAsset(bond).mint(msg.sender, amount.mul(1e18).div(bondPrice));
        _updateDollarPrice();

        emit BoughtBonds(msg.sender, amount);
    }

    function redeemBonds(uint256 amount, uint256 targetPrice) external onlyOneBlock checkCondition checkOperator {
        require(amount > 0, "Treasury: cannot redeem bonds with zero amount");

        uint256 dollarPrice = getDollarPrice();
        require(dollarPrice == targetPrice, "Treasury: dollar price moved");
        require(
            dollarPrice > dollarPriceCeiling, // price > $1.05
            "Treasury: dollarPrice not eligible for bond purchase"
        );
        require(IERC20(dollar).balanceOf(address(this)) >= amount, "Treasury: treasury has no more budget");

        seigniorageSaved = seigniorageSaved.sub(Math.min(seigniorageSaved, amount));

        IBasisAsset(bond).burnFrom(msg.sender, amount);
        IERC20(dollar).safeTransfer(msg.sender, amount);
        _updateDollarPrice();

        emit RedeemedBonds(msg.sender, amount);
    }

    function allocateSeigniorage() external onlyOneBlock checkCondition checkEpoch checkOperator {
        _updateDollarPrice();
        uint256 dollarPrice = getDollarPrice();
        require(dollarPrice > dollarPriceCeiling, "Treasury: there is no seigniorage to be allocated");

        uint256 dollarSupply = IERC20(dollar).totalSupply().sub(seigniorageSaved);
        uint256 percentage = dollarPrice.sub(dollarPriceOne);
        uint256 seigniorage = dollarSupply.mul(percentage).div(1e18);

        if (seigniorageSaved > bondDepletionFloor) {
            IBasisAsset(dollar).mint(address(this), seigniorage);
            IERC20(dollar).safeApprove(boardroom, seigniorage);
            IBoardroom(boardroom).allocateSeigniorage(seigniorage);
            emit BoardroomFunded(now, seigniorage);
        } else {
            seigniorageSaved = seigniorageSaved.add(seigniorage);
            IBasisAsset(dollar).mint(address(this), seigniorage);
            emit TreasuryFunded(now, seigniorage);
        }
    }

    event Initialized(address indexed executor, uint256 at);
    event Migration(address indexed target);
    event RedeemedBonds(address indexed from, uint256 amount);
    event BoughtBonds(address indexed from, uint256 amount);
    event TreasuryFunded(uint256 timestamp, uint256 seigniorage);
    event BoardroomFunded(uint256 timestamp, uint256 seigniorage);
}
