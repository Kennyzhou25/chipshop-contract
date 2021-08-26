// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./owner/Operator.sol";
import "./lib/Babylonian.sol";
import "./lib/FixedPoint.sol";
import "./lib/PancakeswapOracleLibrary.sol";
import "./interfaces/IEpoch.sol";
import "./interfaces/IPancakePair.sol";

// Note: Fixed window oracle that recomputes the average price for the entire period once every period.
// The price average is only guaranteed to be over at least 1 period, but may be over a longer period.
contract Oracle is IEpoch, Operator {
    using FixedPoint for *;
    using SafeMath for uint256;

    address public CHIP;
    address public ETH;
    address public BUSD;

    bool public initialized = false;

    IPancakePair public pair; // CHIP/ETH LP
    address public token0;
    address public token1;

    uint32 public blockTimestampLast;
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    FixedPoint.uq112x112 public price0Average;
    FixedPoint.uq112x112 public price1Average;

    IPancakePair public pair_1; // CHIP/BUSD LP
    address public token0_1;
    address public token1_1;

    uint32 public blockTimestampLast_1;
    uint256 public price0CumulativeLast_1;
    uint256 public price1CumulativeLast_1;
    FixedPoint.uq112x112 public price0Average_1;
    FixedPoint.uq112x112 public price1Average_1;

    IPancakePair public pair_EB; // ETH/BUSD LP
    address public token0_EB;
    address public token1_EB;

    uint32 public blockTimestampLast_EB;
    uint256 public price0CumulativeLast_EB;
    uint256 public price1CumulativeLast_EB;
    FixedPoint.uq112x112 public price0Average_EB;
    FixedPoint.uq112x112 public price1Average_EB;

    address public treasury;
    mapping(uint256 => uint256) public epochDollarPrice;
    uint256 public priceAppreciation;

    event Initialized(address indexed executor, uint256 at);
    event Updated(uint256 price0CumulativeLast, uint256 price1CumulativeLast);

    modifier checkEpoch {
        require(block.timestamp >= nextEpochPoint(), "OracleMultiPair: not opened yet");
        _;
    }

    modifier notInitialized {
        require(!initialized, "Treasury: already initialized");
        _;
    }

    function epoch() public view override returns (uint256) {
        return IEpoch(treasury).epoch();
    }

    function nextEpochPoint() public view override returns (uint256) {
        return IEpoch(treasury).nextEpochPoint();
    }

    function nextEpochLength() external view override returns (uint256) {
        return IEpoch(treasury).nextEpochLength();
    }

    function setAddress(address _CHIP, address _ETH, address _BUSD) external onlyOperator {
        CHIP = _CHIP;
        ETH = _ETH;
        BUSD = _BUSD;
    }

    // _pair is CHIP/ETH LP, _pair_1 is CHIP/BUSD LP, pair_EB is ETH/BUSD LP
    function initialize(IPancakePair _pair, IPancakePair _pair_1, IPancakePair _pair_EB) external onlyOperator notInitialized {
        pair = _pair;
        token0 = pair.token0();
        token1 = pair.token1();
        price0CumulativeLast = pair.price0CumulativeLast();
        price1CumulativeLast = pair.price1CumulativeLast();
        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1, blockTimestampLast) = pair.getReserves();
        require(reserve0 != 0 && reserve1 != 0, "Oracle: NO_RESERVES"); // Ensure that there's liquidity in the pair.

        pair_1 = _pair_1;
        token0_1 = pair_1.token0();
        token1_1 = pair_1.token1();
        price0CumulativeLast_1 = pair_1.price0CumulativeLast(); // Fetch the current accumulated price value (1 / 0).
        price1CumulativeLast_1 = pair_1.price1CumulativeLast(); // Fetch the current accumulated price value (0 / 1).
        uint112 reserve0_1;
        uint112 reserve1_1;
        (reserve0_1, reserve1_1, blockTimestampLast_1) = pair_1.getReserves();
        require(reserve0_1 != 0 && reserve1_1 != 0, "Oracle: NO_RESERVES"); // Ensure that there's liquidity in the pair.

        pair_EB = _pair_EB;
        token0_EB = pair_EB.token0();
        token1_EB = pair_EB.token1();
        price0CumulativeLast_EB = pair_EB.price0CumulativeLast(); // Fetch the current accumulated price value (1 / 0).
        price1CumulativeLast_EB = pair_EB.price1CumulativeLast(); // Fetch the current accumulated price value (0 / 1).
        uint112 reserve0_EB;
        uint112 reserve1_EB;
        (reserve0_EB, reserve1_EB, blockTimestampLast_EB) = pair_EB.getReserves();
        require(reserve0_EB != 0 && reserve1_EB != 0, "Oracle: NO_RESERVES"); // Ensure that there's liquidity in the pair.

        initialized = true;
        emit Initialized(msg.sender, block.number);
    }

    function setTreasury(address _treasury) external onlyOperator {
        treasury = _treasury;
    }

    function setPriceAppreciation(uint256 _priceAppreciation) external onlyOperator {
        require(_priceAppreciation <= 2e17, "_priceAppreciation is insane"); // <= 20%
        priceAppreciation = _priceAppreciation;
    }

    // Updates 1-day EMA price from pancakeswap.
    function update() external checkEpoch {
        // CHIP/ETH LP
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = PancakeswapOracleLibrary.currentCumulativePrices(address(pair));
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // Overflow is desired.
        if (timeElapsed == 0) {
            // Prevent divided by zero.
            return;
        }
        // Overflow is desired, casting never truncates.
        // Cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed.
        price0Average = FixedPoint.uq112x112(uint224((price0Cumulative - price0CumulativeLast) / timeElapsed));
        price1Average = FixedPoint.uq112x112(uint224((price1Cumulative - price1CumulativeLast) / timeElapsed));
        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        blockTimestampLast = blockTimestamp;
        epochDollarPrice[epoch()] = consult(CHIP, 1e18);

        // CHIP/BUSD LP
        (uint256 price0Cumulative_1, uint256 price1Cumulative_1, uint32 blockTimestamp_1) = PancakeswapOracleLibrary.currentCumulativePrices(address(pair_1));
        uint32 timeElapsed_1 = blockTimestamp_1 - blockTimestampLast_1; // overflow is desired
        if (timeElapsed_1 == 0) {
            // Prevent divided by zero.
            return;
        }
        // Overflow is desired, casting never truncates.
        // Cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed.
        price0Average_1 = FixedPoint.uq112x112(uint224((price0Cumulative_1 - price0CumulativeLast_1) / timeElapsed_1));
        price1Average_1 = FixedPoint.uq112x112(uint224((price1Cumulative_1 - price1CumulativeLast_1) / timeElapsed_1));
        price0CumulativeLast_1 = price0Cumulative_1;
        price1CumulativeLast_1 = price1Cumulative_1;
        blockTimestampLast_1 = blockTimestamp_1;

        // ETH/BUSD LP
        (uint256 price0Cumulative_EB, uint256 price1Cumulative_EB, uint32 blockTimestamp_EB) = PancakeswapOracleLibrary.currentCumulativePrices(address(pair_EB));
        uint32 timeElapsed_EB = blockTimestamp_EB - blockTimestampLast_EB; // overflow is desired
        if (timeElapsed_EB == 0) {
            // Prevent divided by zero.
            return;
        }
        // Overflow is desired, casting never truncates.
        // Cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed.
        price0Average_EB = FixedPoint.uq112x112(uint224((price0Cumulative_EB - price0CumulativeLast_EB) / timeElapsed_EB));
        price1Average_EB = FixedPoint.uq112x112(uint224((price1Cumulative_EB - price1CumulativeLast_EB) / timeElapsed_EB));
        price0CumulativeLast_EB = price0Cumulative_EB;
        price1CumulativeLast_EB = price1Cumulative_EB;
        blockTimestampLast_EB = blockTimestamp_EB;

        emit Updated(price0Cumulative, price1Cumulative);
    }

    // This will always return 0 before update has been called successfully for the first time.
    // This function returns average of ETH-based and BUSD-based price of CHIP.
    function consult(address _token, uint256 _amountIn) public view returns (uint144 _amountOut) {
        if (priceAppreciation > 0) {
            uint256 _added = _amountIn.mul(priceAppreciation).div(1e18);
            _amountIn = _amountIn.add(_added);
        }
        if (_token == token0) {
            _amountOut = price0Average.mul(_amountIn).decode144();
        } else {
            require(_token == token1, "Oracle: INVALID_TOKEN");
            _amountOut = price1Average.mul(_amountIn).decode144();
        }

        uint144 _amountOut2;
        if (_token == token0_1) {
            _amountOut2 = price0Average_1.mul(_amountIn).decode144();
        } else {
            require(_token == token1_1, "Oracle: INVALID_TOKEN");
            _amountOut2 = price1Average_1.mul(_amountIn).decode144();
        }

        uint256 tmp = uint256(_amountOut);

        uint256 tmp_1 = uint256(getETHPricePerBUSD()).mul(uint256(_amountOut2));
        tmp = tmp.add(tmp_1).div(2);

        _amountOut = uint144(tmp);
    }

    // Twap of CHIP/ETH LP.
    function twap_1(address _token, uint256 _amountIn) internal view returns (uint144 _amountOut) {
        if (priceAppreciation > 0) {
            uint256 _added = _amountIn.mul(priceAppreciation).div(1e18);
            _amountIn = _amountIn.add(_added);
        }
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = PancakeswapOracleLibrary.currentCumulativePrices(address(pair));
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // Overflow is desired.
        require(timeElapsed > 0, "Oracle : Elapsed time Error1");
        if (_token == token0) {
            require(price0Cumulative >= price0CumulativeLast, "Oracle : Price Calculation Error");
            _amountOut = FixedPoint.uq112x112(uint224((price0Cumulative - price0CumulativeLast) / timeElapsed)).mul(_amountIn).decode144();
        } else if (_token == token1) {
            require(price1Cumulative >= price1CumulativeLast, "Oracle : Price Calculation Error");
            _amountOut = FixedPoint.uq112x112(uint224((price1Cumulative - price1CumulativeLast) / timeElapsed)).mul(_amountIn).decode144();
        }
    }

    // Twap of CHIP/BUSD LP.
    function twap_2(address _token, uint256 _amountIn) internal view returns (uint144 _amountOut) {
        if (priceAppreciation > 0) {
            uint256 _added = _amountIn.mul(priceAppreciation).div(1e18);
            _amountIn = _amountIn.add(_added);
        }
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = PancakeswapOracleLibrary.currentCumulativePrices(address(pair_1));
        uint32 timeElapsed = blockTimestamp - blockTimestampLast_1; // Overflow is desired.
        require(timeElapsed > 0, "Oracle : Elapsed time Error2");
        if (_token == token0_1) {
            require(price0Cumulative >= price0CumulativeLast_1, "Oracle : Price Calculation Error");
            _amountOut = FixedPoint.uq112x112(uint224((price0Cumulative - price0CumulativeLast_1) / timeElapsed)).mul(_amountIn).decode144();
        } else if (_token == token1_1) {
            require(price1Cumulative >= price1CumulativeLast_1, "Oracle : Price Calculation Error");
            _amountOut = FixedPoint.uq112x112(uint224((price1Cumulative - price1CumulativeLast_1) / timeElapsed)).mul(_amountIn).decode144();
        }
    }

    function twapPrice(address _token, uint256 _amountIn) external returns (uint256 _amountOut) {
        uint256 v1 = twap_1(_token, _amountIn);     // CHIP/ETH LP, ETH-based price of CHIP.
        uint256 v2 = twap_2(_token, _amountIn);     // CHIP/BUSD LP, BUSD-based price of CHIP.
        uint256 ETHPricePerBUSD = uint256(getETHPricePerBUSD());
        v2 = v2.mul(ETHPricePerBUSD).div(1e18);
        _amountOut = v1.add(v2).div(2);
    }

    function twap(address _token, uint256 _amountIn) external view returns (uint256 _amountOut) {

        uint256 v1 = twap_1(_token, _amountIn);     // CHIP/ETH LP, ETH-based price of CHIP.
        uint256 v2 = twap_2(_token, _amountIn);     // CHIP/BUSD LP, BUSD-based price of CHIP.
        uint256 ETHPricePerBUSD = uint256(getETHPricePerBUSD());
        v2 = v2.mul(ETHPricePerBUSD).div(1e18);
        _amountOut = v1.add(v2).div(2);
    }

    function getETHPricePerBUSD() public view returns (uint144 _amountOut) {
        uint256 _amountIn = 1 ether;
        if (BUSD == token0_EB) {
            _amountOut = price0Average_EB.mul(_amountIn).decode144();
        } else {
            require(BUSD == token1_EB, "Oracle: INVALID_TOKEN");
            _amountOut = price1Average_EB.mul(_amountIn).decode144();
        }
    }
}
