// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "./lib/Babylonian.sol";
import "./lib/FixedPoint.sol";
import "./lib/UniswapV2Library.sol";
import "./lib/UniswapV2OracleLibrary.sol";
import "./utils/Epoch.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";

// fixed window oracle that recomputes the average price for the entire period once every period
// note that the price average is only guaranteed to be over at least 1 period, but may be over a longer period
contract OracleMultiPair is Epoch {
    using FixedPoint for *;
    using SafeMath for uint256;

    IUniswapV2Pair public busdWbnbPair = IUniswapV2Pair(0x1B96B92314C44b159149f7E0303511fB2Fc4774f);

    /* ========== STATE VARIABLES ========== */

    // uniswap
    address[] public token0;
    address[] public token1;
    IUniswapV2Pair[] public pair;

    address public mainToken;
    address[] public sideTokens;
    address[] public pairWithBusd;

    // oracle
    uint32[] public blockTimestampLast;
    uint256[] public price0CumulativeLast;
    uint256[] public price1CumulativeLast;
    FixedPoint.uq112x112[] public price0Average;
    FixedPoint.uq112x112[] public price1Average;

    event PairUpdated(uint256 pairIndex, uint256 price0CumulativeLast, uint256 price1CumulativeLast);

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _factory,
        address _mainToken,
        address[] memory _sideTokens,
        address[] memory _pairWithBusd,
        uint256 _period,
        uint256 _startTime
    ) public Epoch(_period, _startTime, 0) {
        uint256 _nPairs = _sideTokens.length;
        mainToken = _mainToken;
        for (uint256 i = 0; i < _nPairs; ++i) {
            IUniswapV2Pair _pair = IUniswapV2Pair(UniswapV2Library.pairFor(_factory, mainToken, _sideTokens[i]));
            (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) = _pair.getReserves();
            require(_reserve0 != 0 && _reserve1 != 0, "Oracle: NO_RESERVES"); // ensure that there's liquidity in the pair
            sideTokens.push(_sideTokens[i]);
            pairWithBusd.push(_pairWithBusd[i]);
            pair.push(_pair);
            token0.push(_pair.token0());
            token1.push(_pair.token1());
            price0CumulativeLast.push(_pair.price0CumulativeLast()); // fetch the current accumulated price value (1 / 0)
            price1CumulativeLast.push(_pair.price1CumulativeLast()); // fetch the current accumulated price value (0 / 1)
            blockTimestampLast.push(_blockTimestampLast);
        }
    }

    /* ========== MUTABLE FUNCTIONS ========== */

    /** @dev Updates 1-day EMA price from Uniswap.  */
    function _updatePair(uint256 _pi) internal {
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = UniswapV2OracleLibrary.currentCumulativePrices(address(pair[_pi]));
        uint32 timeElapsed = blockTimestamp - blockTimestampLast[_pi]; // overflow is desired

        if (timeElapsed == 0) {
            // prevent divided by zero
            return;
        }

        // overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        price0Average[_pi] = FixedPoint.uq112x112(uint224((price0Cumulative - price0CumulativeLast[_pi]) / timeElapsed));
        price1Average[_pi] = FixedPoint.uq112x112(uint224((price1Cumulative - price1CumulativeLast[_pi]) / timeElapsed));

        price0CumulativeLast[_pi] = price0Cumulative;
        price1CumulativeLast[_pi] = price1Cumulative;
        blockTimestampLast[_pi] = blockTimestamp;

        emit PairUpdated(_pi, price0Cumulative, price1Cumulative);
    }

    /** @dev Updates 1-day EMA price from Uniswap.  */
    function update() external checkEpoch {
        uint256 _nPairs = sideTokens.length;
        for (uint256 _pi = 0; _pi < _nPairs; ++_pi) {
            _updatePair(_pi);
        }
    }

    function consultPair(uint256 _pairIndex, address _token, uint256 _amountIn) external view returns (uint144 amountOut) {
        if (_token == token0[_pairIndex]) {
            amountOut = price0Average[_pairIndex].mul(_amountIn).decode144();
        } else if (_token == token1[_pairIndex]) {
            amountOut = price1Average[_pairIndex].mul(_amountIn).decode144();
        }
    }

    // note this will always return 0 before update has been called successfully for the first time.
    function consult(address token, uint256 amountIn) external view returns (uint144 amountOut) {
        uint256 _nPairs = sideTokens.length;
        uint256 _totalTokenReserve = 0;
        uint256 _accumulateAmountOut = 0;
        for (uint256 _pi = 0; _pi < _nPairs; ++_pi) {
            if (token == token0[_pi]) {
                (uint112 _reserve0, ,) = pair[_pi].getReserves();
                uint144 _token1AmountOut = price0Average[_pi].mul(amountIn).decode144();
                uint256 _busdAmountOut = (pairWithBusd[_pi] == address(0)) ? uint256(_token1AmountOut) : getOtherTokenAmountFromPair(IUniswapV2Pair(pairWithBusd[_pi]), token1[_pi], _token1AmountOut);
                _totalTokenReserve = _totalTokenReserve.add(_reserve0);
                _accumulateAmountOut = _accumulateAmountOut.add(_busdAmountOut.mul(_reserve0));
            } else if (token == token1[_pi]) {
                (, uint112 _reserve1,) = pair[_pi].getReserves();
                uint144 _token0AmountOut = price1Average[_pi].mul(amountIn).decode144();
                uint256 _busdAmountOut = (pairWithBusd[_pi] == address(0)) ? uint256(_token0AmountOut) : getOtherTokenAmountFromPair(IUniswapV2Pair(pairWithBusd[_pi]), token0[_pi], _token0AmountOut);
                _totalTokenReserve = _totalTokenReserve.add(_reserve1);
                _accumulateAmountOut = _accumulateAmountOut.add(_busdAmountOut.mul(_reserve1));
            }
        }
        require(_totalTokenReserve > 0, "All pairs is dried");
        amountOut = uint144(_accumulateAmountOut.div(_totalTokenReserve));
    }

    function getOtherTokenAmountFromPair(IUniswapV2Pair _pair, address _token, uint256 _tokenAmount) public view returns (uint256 _otherTokenAmount) {
        if (_token == _pair.token0()) {
            (uint112 _reserve0, uint112 _reserve1,) = _pair.getReserves();
            _otherTokenAmount = _tokenAmount.mul(_reserve1).div(_reserve0);
        } else {
            require(_token == _pair.token1(), "Oracle: INVALID_TOKEN");
            (uint112 _reserve0, uint112 _reserve1,) = _pair.getReserves();
            _otherTokenAmount = _tokenAmount.mul(_reserve0).div(_reserve1);
        }
    }

    function pairFor(
        address factory,
        address tokenA,
        address tokenB
    ) external pure returns (address lpt) {
        return UniswapV2Library.pairFor(factory, tokenA, tokenB);
    }
}
