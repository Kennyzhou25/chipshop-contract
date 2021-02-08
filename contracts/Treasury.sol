// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./lib/Babylonian.sol";
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
contract Treasury is ContractGuard {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    /* ========= CONSTANT VARIABLES ======== */

    uint256 public constant PERIOD = 6 hours;

    /* ========== STATE VARIABLES ========== */

    // governance
    address public operator;

    // flags
    bool public migrated = false;
    bool public initialized = false;

    // epoch
    uint256 public startTime;
    uint256 public epoch = 0;
    uint256 public epochSupplyContractionLeft = 0;

    // core components
    address public dollar = address(0x190b589cf9Fb8DDEabBFeae36a813FFb2A702454);
    address public bond = address(0x9586b02B09bd68A7cD4aa9167a61B78F43092063);
    address public share = address(0x0d9319565be7f53CeFE84Ad201Be3f40feAE2740);

    address public boardroom;
    address public dollarOracle;

    // price
    uint256 public dollarPriceOne;
    uint256 public dollarPriceCeiling;

    uint256 public seigniorageSaved;

    // protocol parameters - https://github.com/MidasCore/midasdollar-protocol/tree/master/docs/ProtocolParameters.md
    uint256 public maxSupplyExpansionPercent;
    uint256 public maxSupplyExpansionPercentInDebtPhase;
    uint256 public bondDepletionFloorPercent;
    uint256 public seigniorageExpansionFloorPercent;
    uint256 public maxSupplyContractionPercent;
    uint256 public maxDeptRatioPercent;

    /* =================== MDOIPs (Midas Dollar Improvement Proposals) =================== */

    // MDOIP01: 28 first epochs (1 week) with 4.5% expansion regardless of MDO price
    uint256 public bdoip01BootstrapEpochs;
    uint256 public bdoip01BootstrapSupplyExpansionPercent;

    /* =================== Added variables (need to keep orders for proxy to work) =================== */
    uint256 public previousEpochDollarPrice;
    uint256 public allocateSeigniorageSalary;
    uint256 public maxDiscountRate; // when purchasing bond
    uint256 public maxPremiumRate; // when redeeming bond
    uint256 public discountPercent;
    uint256 public premiumPercent;
    uint256 public mintingFactorForPayingDebt; // print extra MDO during dept phase

    // MDOIP03: 10% of minted MDO goes to Community DAO Fund
    address public daoFund;
    uint256 public daoFundSharedPercent;

    // MDOIP04: 15% to DAO Fund, 3% to bVaults incentive fund, 2% to MKT
    address public bVaultsFund;
    uint256 public bVaultsFundSharedPercent;
    address public marketingFund;
    uint256 public marketingFundSharedPercent;

    /* =================== Events =================== */

    event Initialized(address indexed executor, uint256 at);
    event Migration(address indexed target);
    event RedeemedBonds(address indexed from, uint256 dollarAmount, uint256 bondAmount);
    event BoughtBonds(address indexed from, uint256 dollarAmount, uint256 bondAmount);
    event TreasuryFunded(uint256 timestamp, uint256 seigniorage);
    event BoardroomFunded(uint256 timestamp, uint256 seigniorage);
    event DaoFundFunded(uint256 timestamp, uint256 seigniorage);
    event BVaultsFundFunded(uint256 timestamp, uint256 seigniorage);
    event MarketingFundFunded(uint256 timestamp, uint256 seigniorage);

    /* =================== Modifier =================== */

    modifier onlyOperator() {
        require(operator == msg.sender, "Treasury: caller is not the operator");
        _;
    }

    modifier checkCondition {
        require(!migrated, "Treasury: migrated");
        require(now >= startTime, "Treasury: not started yet");

        _;
    }

    modifier checkEpoch {
        require(now >= nextEpochPoint(), "Treasury: not opened yet");

        _;

        epoch = epoch.add(1);
        epochSupplyContractionLeft = (getDollarPrice() > dollarPriceCeiling) ? 0 : IERC20(dollar).totalSupply().mul(maxSupplyContractionPercent).div(10000);
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
        try IOracle(dollarOracle).consult(dollar, 1e18) returns (uint144 price) {
            return uint256(price);
        } catch {
            revert("Treasury: failed to consult dollar price from the oracle");
        }
    }

    function getDollarUpdatedPrice() public view returns (uint256 _dollarPrice) {
        try IOracle(dollarOracle).twap(dollar, 1e18) returns (uint144 price) {
            return uint256(price);
        } catch {
            revert("Treasury: failed to consult dollar price from the oracle");
        }
    }

    // budget
    function getReserve() public view returns (uint256) {
        return seigniorageSaved;
    }

    function getBurnableDollarLeft() public view returns (uint256 _burnableDollarLeft) {
        uint256  _dollarPrice = getDollarPrice();
        if (_dollarPrice <= dollarPriceOne) {
            uint256 _dollarSupply = IERC20(dollar).totalSupply();
            uint256 _bondMaxSupply = _dollarSupply.mul(maxDeptRatioPercent).div(10000);
            uint256 _bondSupply = IERC20(bond).totalSupply();
            if (_bondMaxSupply > _bondSupply) {
                uint256 _maxMintableBond = _bondMaxSupply.sub(_bondSupply);
                uint256 _maxBurnableDollar = _maxMintableBond.mul(_dollarPrice).div(1e18);
                _burnableDollarLeft = Math.min(epochSupplyContractionLeft, _maxBurnableDollar);
            }
        }
    }

    function getRedeemableBonds() public view returns (uint256 _redeemableBonds) {
        uint256  _dollarPrice = getDollarPrice();
        if (_dollarPrice > dollarPriceCeiling) {
            uint256 _totalDollar = IERC20(dollar).balanceOf(address(this));
            uint256 _rate = getBondPremiumRate();
            if (_rate > 0) {
                _redeemableBonds = _totalDollar.mul(1e18).div(_rate);
            }
        }
    }

    function getBondDiscountRate() public view returns (uint256 _rate) {
        uint256 _dollarPrice = getDollarPrice();
        if (_dollarPrice <= dollarPriceOne) {
            if (discountPercent == 0) {
                // no discount
                _rate = dollarPriceOne;
            } else {
                uint256 _bondAmount = dollarPriceOne.mul(1e18).div(_dollarPrice); // to burn 1 dollar
                uint256 _discountAmount = _bondAmount.sub(dollarPriceOne).mul(discountPercent).div(10000);
                _rate = dollarPriceOne.add(_discountAmount);
                if (maxDiscountRate > 0 && _rate > maxDiscountRate) {
                    _rate = maxDiscountRate;
                }
            }
        }
    }

    function getBondPremiumRate() public view returns (uint256 _rate) {
        uint256 _dollarPrice = getDollarPrice();
        if (_dollarPrice > dollarPriceCeiling) {
            if (premiumPercent == 0) {
                // no premium bonus
                _rate = dollarPriceOne;
            } else {
                uint256 _premiumAmount = _dollarPrice.sub(dollarPriceOne).mul(premiumPercent).div(10000);
                _rate = dollarPriceOne.add(_premiumAmount);
                if (maxDiscountRate > 0 && _rate > maxDiscountRate) {
                    _rate = maxDiscountRate;
                }
            }
        }
    }

    /* ========== GOVERNANCE ========== */

    function initialize(
        address _dollar,
        address _bond,
        address _share,
        uint256 _startTime
    ) public notInitialized {
        dollar = _dollar;
        bond = _bond;
        share = _share;
        startTime = _startTime;

        dollarPriceOne = 10**18;
        dollarPriceCeiling = dollarPriceOne.mul(101).div(100);

        maxSupplyExpansionPercent = 300; // Upto 3.0% supply for expansion
        maxSupplyExpansionPercentInDebtPhase = 450; // Upto 4.5% supply for expansion in debt phase (to pay debt faster)
        bondDepletionFloorPercent = 10000; // 100% of Bond supply for depletion floor
        seigniorageExpansionFloorPercent = 3500; // At least 35% of expansion reserved for boardroom
        maxSupplyContractionPercent = 300; // Upto 3.0% supply for contraction (to burn MDO and mint MDB)
        maxDeptRatioPercent = 3500; // Upto 35% supply of MDB to purchase

        // BDIP01: First 28 epochs with 4.5% expansion
        bdoip01BootstrapEpochs = 28;
        bdoip01BootstrapSupplyExpansionPercent = 450;

        // set seigniorageSaved to it's balance
        seigniorageSaved = IERC20(dollar).balanceOf(address(this));

        initialized = true;
        operator = msg.sender;
        emit Initialized(msg.sender, block.number);
    }

    function setOperator(address _operator) external onlyOperator {
        operator = _operator;
    }

    function setBoardroom(address _boardroom) external onlyOperator {
        boardroom = _boardroom;
    }

    function setDollarOracle(address _dollarOracle) external onlyOperator {
        dollarOracle = _dollarOracle;
    }

    function setDollarPriceCeiling(uint256 _dollarPriceCeiling) external onlyOperator {
        require(_dollarPriceCeiling >= dollarPriceOne && _dollarPriceCeiling <= dollarPriceOne.mul(120).div(100), "out of range"); // [$1.0, $1.2]
        dollarPriceCeiling = _dollarPriceCeiling;
    }

    function setMaxSupplyExpansionPercents(uint256 _maxSupplyExpansionPercent, uint256 _maxSupplyExpansionPercentInDebtPhase) external onlyOperator {
        require(_maxSupplyExpansionPercent >= 10 && _maxSupplyExpansionPercent <= 1000, "_maxSupplyExpansionPercent: out of range"); // [0.1%, 10%]
        require(_maxSupplyExpansionPercentInDebtPhase >= 10 && _maxSupplyExpansionPercentInDebtPhase <= 1500, "_maxSupplyExpansionPercentInDebtPhase: out of range"); // [0.1%, 15%]
        require(_maxSupplyExpansionPercent <= _maxSupplyExpansionPercentInDebtPhase, "_maxSupplyExpansionPercent is over _maxSupplyExpansionPercentInDebtPhase");
        maxSupplyExpansionPercent = _maxSupplyExpansionPercent;
        maxSupplyExpansionPercentInDebtPhase = _maxSupplyExpansionPercentInDebtPhase;
    }

    function setBondDepletionFloorPercent(uint256 _bondDepletionFloorPercent) external onlyOperator {
        require(_bondDepletionFloorPercent >= 500 && _bondDepletionFloorPercent <= 10000, "out of range"); // [5%, 100%]
        bondDepletionFloorPercent = _bondDepletionFloorPercent;
    }

    function setMaxSupplyContractionPercent(uint256 _maxSupplyContractionPercent) external onlyOperator {
        require(_maxSupplyContractionPercent >= 100 && _maxSupplyContractionPercent <= 1500, "out of range"); // [0.1%, 15%]
        maxSupplyContractionPercent = _maxSupplyContractionPercent;
    }

    function setMaxDeptRatioPercent(uint256 _maxDeptRatioPercent) external onlyOperator {
        require(_maxDeptRatioPercent >= 1000 && _maxDeptRatioPercent <= 10000, "out of range"); // [10%, 100%]
        maxDeptRatioPercent = _maxDeptRatioPercent;
    }

    function setMDOIP01(uint256 _bdoip01BootstrapEpochs, uint256 _bdoip01BootstrapSupplyExpansionPercent) external onlyOperator {
        require(_bdoip01BootstrapEpochs <= 120, "_bdoip01BootstrapEpochs: out of range"); // <= 1 month
        require(_bdoip01BootstrapSupplyExpansionPercent >= 100 && _bdoip01BootstrapSupplyExpansionPercent <= 1000, "_bdoip01BootstrapSupplyExpansionPercent: out of range"); // [1%, 10%]
        bdoip01BootstrapEpochs = _bdoip01BootstrapEpochs;
        bdoip01BootstrapSupplyExpansionPercent = _bdoip01BootstrapSupplyExpansionPercent;
    }

    function setExtraFunds(address _daoFund, uint256 _daoFundSharedPercent,
        address _bVaultsFund, uint256 _bVaultsFundSharedPercent,
        address _marketingFund, uint256 _marketingFundSharedPercent) external onlyOperator {
        require(_daoFund != address(0), "zero");
        require(_daoFundSharedPercent <= 3000, "out of range"); // <= 30%
        require(_bVaultsFund != address(0), "zero");
        require(_bVaultsFundSharedPercent <= 1000, "out of range"); // <= 10%
        require(_marketingFund != address(0), "zero");
        require(_marketingFundSharedPercent <= 1000, "out of range"); // <= 10%
        daoFund = _daoFund;
        daoFundSharedPercent = _daoFundSharedPercent;
        bVaultsFund = _bVaultsFund;
        bVaultsFundSharedPercent = _bVaultsFundSharedPercent;
        marketingFund = _marketingFund;
        marketingFundSharedPercent = _marketingFundSharedPercent;
    }

    function setAllocateSeigniorageSalary(uint256 _allocateSeigniorageSalary) external onlyOperator {
        require(_allocateSeigniorageSalary <= 100 ether, "Treasury: dont pay too much");
        allocateSeigniorageSalary = _allocateSeigniorageSalary;
    }

    function setMaxDiscountRate(uint256 _maxDiscountRate) external onlyOperator {
        maxDiscountRate = _maxDiscountRate;
    }

    function setMaxPremiumRate(uint256 _maxPremiumRate) external onlyOperator {
        maxPremiumRate = _maxPremiumRate;
    }

    function setDiscountPercent(uint256 _discountPercent) external onlyOperator {
        require(_discountPercent <= 20000, "_discountPercent is over 200%");
        discountPercent = _discountPercent;
    }

    function setPremiumPercent(uint256 _premiumPercent) external onlyOperator {
        require(_premiumPercent <= 20000, "_premiumPercent is over 200%");
        premiumPercent = _premiumPercent;
    }

    function setMintingFactorForPayingDebt(uint256 _mintingFactorForPayingDebt) external onlyOperator {
        require(_mintingFactorForPayingDebt >= 10000 && _mintingFactorForPayingDebt <= 20000, "_mintingFactorForPayingDebt: out of range"); // [100%, 200%]
        mintingFactorForPayingDebt = _mintingFactorForPayingDebt;
    }

    function migrate(address target) external onlyOperator checkOperator {
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

    function buyBonds(uint256 _dollarAmount, uint256 targetPrice) external onlyOneBlock checkCondition checkOperator {
        require(_dollarAmount > 0, "Treasury: cannot purchase bonds with zero amount");

        uint256 dollarPrice = getDollarPrice();
        require(dollarPrice == targetPrice, "Treasury: dollar price moved");
        require(
            dollarPrice < dollarPriceOne, // price < $1
            "Treasury: dollarPrice not eligible for bond purchase"
        );

        require(_dollarAmount <= epochSupplyContractionLeft, "Treasury: not enough bond left to purchase");

        uint256 _rate = getBondDiscountRate();
        require(_rate > 0, "Treasury: invalid bond rate");

        uint256 _bondAmount = _dollarAmount.mul(_rate).div(1e18);
        uint256 dollarSupply = IERC20(dollar).totalSupply();
        uint256 newBondSupply = IERC20(bond).totalSupply().add(_bondAmount);
        require(newBondSupply <= dollarSupply.mul(maxDeptRatioPercent).div(10000), "over max debt ratio");

        IBasisAsset(dollar).burnFrom(msg.sender, _dollarAmount);
        IBasisAsset(bond).mint(msg.sender, _bondAmount);

        epochSupplyContractionLeft = epochSupplyContractionLeft.sub(_dollarAmount);
        _updateDollarPrice();

        emit BoughtBonds(msg.sender, _dollarAmount, _bondAmount);
    }

    function redeemBonds(uint256 _bondAmount, uint256 targetPrice) external onlyOneBlock checkCondition checkOperator {
        require(_bondAmount > 0, "Treasury: cannot redeem bonds with zero amount");

        uint256 dollarPrice = getDollarPrice();
        require(dollarPrice == targetPrice, "Treasury: dollar price moved");
        require(
            dollarPrice > dollarPriceCeiling, // price > $1.01
            "Treasury: dollarPrice not eligible for bond purchase"
        );

        uint256 _rate = getBondPremiumRate();
        require(_rate > 0, "Treasury: invalid bond rate");

        uint256 _dollarAmount = _bondAmount.mul(_rate).div(1e18);
        require(IERC20(dollar).balanceOf(address(this)) >= _dollarAmount, "Treasury: treasury has no more budget");

        seigniorageSaved = seigniorageSaved.sub(Math.min(seigniorageSaved, _dollarAmount));

        IBasisAsset(bond).burnFrom(msg.sender, _bondAmount);
        IERC20(dollar).safeTransfer(msg.sender, _dollarAmount);

        _updateDollarPrice();

        emit RedeemedBonds(msg.sender, _dollarAmount, _bondAmount);
    }

    function _sendToBoardRoom(uint256 _amount) internal {
        IBasisAsset(dollar).mint(address(this), _amount);
        if (daoFundSharedPercent > 0) {
            uint256 _daoFundSharedAmount = _amount.mul(daoFundSharedPercent).div(10000);
            IERC20(dollar).transfer(daoFund, _daoFundSharedAmount);
            emit DaoFundFunded(now, _daoFundSharedAmount);
            _amount = _amount.sub(_daoFundSharedAmount);
        }
        if (bVaultsFundSharedPercent > 0) {
            uint256 _bVaultsFundSharedAmount = _amount.mul(bVaultsFundSharedPercent).div(10000);
            IERC20(dollar).transfer(bVaultsFund, _bVaultsFundSharedAmount);
            emit BVaultsFundFunded(now, _bVaultsFundSharedAmount);
            _amount = _amount.sub(_bVaultsFundSharedAmount);
        }
        if (marketingFundSharedPercent > 0) {
            uint256 _marketingSharedAmount = _amount.mul(marketingFundSharedPercent).div(10000);
            IERC20(dollar).transfer(marketingFund, _marketingSharedAmount);
            emit MarketingFundFunded(now, _marketingSharedAmount);
            _amount = _amount.sub(_marketingSharedAmount);
        }
        IERC20(dollar).safeApprove(boardroom, 0);
        IERC20(dollar).safeApprove(boardroom, _amount);
        IBoardroom(boardroom).allocateSeigniorage(_amount);
        emit BoardroomFunded(now, _amount);
    }

    function allocateSeigniorage() external onlyOneBlock checkCondition checkEpoch checkOperator {
        _updateDollarPrice();
        previousEpochDollarPrice = getDollarPrice();
        uint256 dollarSupply = IERC20(dollar).totalSupply().sub(seigniorageSaved);
        if (epoch < bdoip01BootstrapEpochs) {// MDOIP01: 28 first epochs with 4.5% expansion
            _sendToBoardRoom(dollarSupply.mul(bdoip01BootstrapSupplyExpansionPercent).div(10000));
        } else {
            if (previousEpochDollarPrice > dollarPriceCeiling) {
                // Expansion ($MDO Price > 1$): there is some seigniorage to be allocated
                uint256 bondSupply = IERC20(bond).totalSupply();
                uint256 _percentage = previousEpochDollarPrice.sub(dollarPriceOne);
                uint256 _savedForBond;
                uint256 _savedForBoardRoom;
                if (seigniorageSaved >= bondSupply.mul(bondDepletionFloorPercent).div(10000)) {// saved enough to pay dept, mint as usual rate
                    uint256 _mse = maxSupplyExpansionPercent.mul(1e14);
                    if (_percentage > _mse) {
                        _percentage = _mse;
                    }
                    _savedForBoardRoom = dollarSupply.mul(_percentage).div(1e18);
                } else {// have not saved enough to pay dept, mint more
                    uint256 _mse = maxSupplyExpansionPercentInDebtPhase.mul(1e14);
                    if (_percentage > _mse) {
                        _percentage = _mse;
                    }
                    uint256 _seigniorage = dollarSupply.mul(_percentage).div(1e18);
                    _savedForBoardRoom = _seigniorage.mul(seigniorageExpansionFloorPercent).div(10000);
                    _savedForBond = _seigniorage.sub(_savedForBoardRoom);
                    if (mintingFactorForPayingDebt > 0) {
                        _savedForBond = _savedForBond.mul(mintingFactorForPayingDebt).div(10000);
                    }
                }
                if (_savedForBoardRoom > 0) {
                    _sendToBoardRoom(_savedForBoardRoom);
                }
                if (_savedForBond > 0) {
                    seigniorageSaved = seigniorageSaved.add(_savedForBond);
                    IBasisAsset(dollar).mint(address(this), _savedForBond);
                    emit TreasuryFunded(now, _savedForBond);
                }
            }
        }
        if (allocateSeigniorageSalary > 0) {
            IBasisAsset(dollar).mint(address(msg.sender), allocateSeigniorageSalary);
        }
    }

    function governanceRecoverUnsupported(IERC20 _token, uint256 _amount, address _to) external onlyOperator {
        // do not allow to drain core tokens
        require(address(_token) != address(dollar), "dollar");
        require(address(_token) != address(bond), "bond");
        require(address(_token) != address(share), "share");
        _token.safeTransfer(_to, _amount);
    }

    /* ========== BOARDROOM CONTROLLING FUNCTIONS ========== */

    function boardroomSetOperator(address _operator) external onlyOperator {
        IBoardroom(boardroom).setOperator(_operator);
    }

    function boardroomSetLockUp(uint256 _withdrawLockupEpochs, uint256 _rewardLockupEpochs) external onlyOperator {
        IBoardroom(boardroom).setLockUp(_withdrawLockupEpochs, _rewardLockupEpochs);
    }

    function boardroomAllocateSeigniorage(uint256 amount) external onlyOperator {
        IBoardroom(boardroom).allocateSeigniorage(amount);
    }

    function boardroomGovernanceRecoverUnsupported(address _token, uint256 _amount, address _to) external onlyOperator {
        IBoardroom(boardroom).governanceRecoverUnsupported(_token, _amount, _to);
    }
}
