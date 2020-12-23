// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IBPool.sol";
import "./lib/FixedPoint.sol";
import './lib/UQ112x112.sol';
import "./interfaces/IDecimals.sol";

// fixed window oracle that recomputes the average price for the entire epochPeriod once every epochPeriod
// note that the price average is only guaranteed to be over at least 1 epochPeriod, but may be over a longer epochPeriod
contract OracleMultiPair is Ownable {
    using FixedPoint for *;
    using SafeMath for uint256;
    using UQ112x112 for uint224;

    /* ========= CONSTANT VARIABLES ======== */

    uint256 public constant BPOOL_BONE = 10**18;
    uint256 public constant ORACLE_RESERVE_MINIMUM = 10000 ether; // $10,000

    /* ========== STATE VARIABLES ========== */

    // governance
    address public operator;

    // epoch
    uint256 public startTime;
    uint256 public lastEpochTime;
    uint256 public epoch; // for display only
    uint256 public epochPeriod;

    mapping(uint256 => uint112) public epochPrice;

    // BPool
    address public mainToken;
    address[] public sideTokens;
    uint256[] public sideTokenDecimals;
    IBPool[] public pools;

    // Pool price for update in cumulative epochPeriod
    uint32 public blockTimestampCumulativeLast;
    uint public priceCumulative;

    // oracle
    uint32 public blockTimestampLast;
    uint256 public priceCumulativeLast;
    FixedPoint.uq112x112 public priceAverage;

    event Updated(uint256 priceCumulativeLast);

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address[] memory _pools,
        address _mainToken,
        address[] memory _sideTokens,
        uint256 _epochPeriod,
        uint256 _startTime
    ) public {
        require(_pools.length == _sideTokens.length, "ERR_LENGTH_MISMATCH");

        for (uint256 i = 0; i < _pools.length; i++) {
            IBPool pool = IBPool(_pools[i]);
            require(pool.isBound(_mainToken) && pool.isBound(_sideTokens[i]), "!bound");
            require(pool.getBalance(_mainToken) != 0 && pool.getBalance(_sideTokens[i]) != 0, "OracleMultiPair: NO_RESERVES"); // ensure that there's liquidity in the pool

            pools.push(pool);
            sideTokens.push(_sideTokens[i]);
            sideTokenDecimals.push(IDecimals(_sideTokens[i]).decimals());
        }

        mainToken = _mainToken;
        epochPeriod = _epochPeriod;
        lastEpochTime = _startTime.sub(epochPeriod);
        operator = msg.sender;
    }

    /* ========== GOVERNANCE ========== */

    function setOperator(address _operator) external onlyOperator {
        operator = _operator;
    }

    function setEpochPeriod(uint256 _epochPeriod) external onlyOperator {
        require(_epochPeriod >= 1 hours && _epochPeriod <= 48 hours, '_epochPeriod out of range');
        epochPeriod = _epochPeriod;
    }

    function setEpoch(uint256 _epoch) external onlyOperator {
        epoch = _epoch;
    }

    function addPool(address _pool, address _sideToken) public onlyOperator {
        IBPool pool = IBPool(_pool);
        require(pool.isBound(mainToken) && pool.isBound(_sideToken), "!bound");
        require(pool.getBalance(mainToken) != 0 && pool.getBalance(_sideToken) != 0, "OracleMultiPair: NO_RESERVES");
        // ensure that there's liquidity in the pool

        pools.push(pool);
        sideTokens.push(_sideToken);
        sideTokenDecimals.push(IDecimals(_sideToken).decimals());
    }

    function removePool(address _pool, address _sideToken) public onlyOperator {
        uint last = pools.length - 1;

        for (uint256 i = 0; i < pools.length; i++) {
            if (address(pools[i]) == _pool && sideTokens[i] == _sideToken) {
                pools[i] = pools[last];
                sideTokens[i] = sideTokens[last];
                sideTokenDecimals[i] = sideTokenDecimals[last];

                pools.pop();
                sideTokens.pop();
                sideTokenDecimals.pop();

                break;
            }
        }
    }

    /* =================== Modifier =================== */

    modifier checkEpoch {
        uint256 _nextEpochPoint = nextEpochPoint();
        require(now >= _nextEpochPoint, "OracleMultiPair: not opened yet");

        _;

        for (;;) {
            lastEpochTime = _nextEpochPoint;
            ++epoch;
            _nextEpochPoint = nextEpochPoint();
            if (now < _nextEpochPoint) break;
        }
    }

    modifier onlyOperator() {
        require(operator == msg.sender, "OracleMultiPair: caller is not the operator");
        _;
    }

    /* ========== VIEW FUNCTIONS ========== */

    function nextEpochPoint() public view returns (uint256) {
        return lastEpochTime.add(epochPeriod);
    }

    /* ========== MUTABLE FUNCTIONS ========== */
    // update reserves and, on the first call per block, price accumulators
    function updateCumulative() public {
        uint totalMainPriceWeight;
        uint totalMainPoolBal;

        for (uint256 i = 0; i < pools.length; i++) {
            uint _decimalFactor = 10 ** (uint256(18).sub(sideTokenDecimals[i]));
            uint tokenMainPrice = pools[i].getSpotPrice(sideTokens[i], mainToken).mul(_decimalFactor);
            require(tokenMainPrice != 0, "!price");

            uint reserveBal = pools[i].getBalance(sideTokens[i]).mul(_decimalFactor);
            require(reserveBal >= ORACLE_RESERVE_MINIMUM, "!min reserve");

            uint tokenBal = pools[i].getBalance(mainToken);
            totalMainPriceWeight = totalMainPriceWeight.add(tokenMainPrice.mul(tokenBal).div(BPOOL_BONE));
            totalMainPoolBal = totalMainPoolBal.add(tokenBal);
        }

        require(totalMainPriceWeight <= uint112(- 1) && totalMainPoolBal <= uint112(- 1), 'BPool: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed = blockTimestamp - blockTimestampCumulativeLast; // overflow is desired

        if (timeElapsed > 0 && totalMainPoolBal != 0) {
            // * never overflows, and + overflow is desired
            priceCumulative += uint(UQ112x112.encode(uint112(totalMainPriceWeight)).uqdiv(uint112(totalMainPoolBal))) * timeElapsed;

            blockTimestampCumulativeLast = blockTimestamp;
        }
    }

    /** @dev Updates 1-day EMA price.  */
    function update() external checkEpoch {
        updateCumulative();

        uint32 timeElapsed = blockTimestampCumulativeLast - blockTimestampLast; // overflow is desired

        if (timeElapsed == 0) {
            // prevent divided by zero
            return;
        }

        // overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        priceAverage = FixedPoint.uq112x112(uint224((priceCumulative - priceCumulativeLast) / timeElapsed));

        priceCumulativeLast = priceCumulative;
        blockTimestampLast = blockTimestampCumulativeLast;

        epochPrice[epoch] = priceAverage.decode();
        emit Updated(priceCumulative);
    }

    // note this will always return 0 before update has been called successfully for the first time.
    function consult(address token, uint256 amountIn) external view returns (uint144 amountOut) {
        require(token == mainToken, "OracleMultiPair: INVALID_TOKEN");
        require(now.sub(blockTimestampLast) <= epochPeriod, "OracleMultiPair: Price out-of-date");
        amountOut = priceAverage.mul(amountIn).decode144();
    }

    function twap(uint256 _amountIn) external view returns (uint144) {
        uint32 timeElapsed = blockTimestampCumulativeLast - blockTimestampLast;
        return (timeElapsed == 0) ? priceAverage.mul(_amountIn).decode144() : FixedPoint.uq112x112(uint224((priceCumulative - priceCumulativeLast) / timeElapsed)).mul(_amountIn).decode144();
    }

    function governanceRecoverUnsupported(IERC20 _token, uint256 _amount, address _to) external onlyOperator {
        _token.transfer(_to, _amount);
    }
}

