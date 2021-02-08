# Midas Dollar

[![Twitter Follow](https://img.shields.io/twitter/follow/Midas_Dollar_Fi?label=Follow)](https://twitter.com/Midas_Dollar_Fi)

Midas Dollar is a lightweight implementation of the [Basis Protocol](basis.io) on Ethereum.

## Contract Addresses
| Contract  | Address |
| ------------- | ------------- |
| Midas Dollar (MDO) | [0x35e869B7456462b81cdB5e6e42434bD27f3F788c](https://bscscan.com/token/0x35e869B7456462b81cdB5e6e42434bD27f3F788c) |
| Midas Dollar Share (MDS) | [0x242E46490397ACCa94ED930F2C4EdF16250237fa](https://bscscan.com/token/0x242E46490397ACCa94ED930F2C4EdF16250237fa) |
| Midas Dollar Bond (MDB) | [0xCaD2109CC2816D47a796cB7a0B57988EC7611541](https://bscscan.com/token/0xCaD2109CC2816D47a796cB7a0B57988EC7611541) |
| MdoRewardPool | [0x3C4583375870573897154d8fAf71663e1e017Ef7](https://bscscan.com/address/0x3C4583375870573897154d8fAf71663e1e017Ef7#code) |
| ShareRewardPool | [](https://bscscan.com/address/#code) |
| Treasury | [](https://bscscan.com/address/#code) |
| Boardroom | [](https://bscscan.com/address/#code) |
| CommunityFund | [](https://bscscan.com/address/#code) |
| OracleSinglePair | [](https://bscscan.com/address/#code) |

## Audit
[Sushiswap - by PeckShield](https://github.com/peckshield/publications/blob/master/audit_reports/PeckShield-Audit-Report-SushiSwap-v1.0.pdf)

[Timelock - by Openzeppelin Security](https://blog.openzeppelin.com/compound-finance-patch-audit)

[BasisCash - by CertiK](https://www.dropbox.com/s/ed5vxvaple5e740/REP-Basis-Cash-06_11_2020.pdf)

## History of Basis

Basis is an algorithmic stablecoin protocol where the money supply is dynamically adjusted to meet changes in money demand.  

- When demand is rising, the blockchain will create more Midas Dollar. The expanded supply is designed to bring the Basis price back down.
- When demand is falling, the blockchain will buy back Midas Dollar. The contracted supply is designed to restore Basis price.
- The Basis protocol is designed to expand and contract supply similarly to the way central banks buy and sell fiscal debt to stabilize purchasing power. For this reason, we refer to Midas Dollar as having an algorithmic central bank.

Read the [Basis Whitepaper](http://basis.io/basis_whitepaper_en.pdf) for more details into the protocol. 

Basis was shut down in 2018, due to regulatory concerns its Bond and Share tokens have security characteristics. 

## The Midas Dollar Protocol

Midas Dollar differs from the original Basis Project in several meaningful ways: 

1. **Rationally simplified** - several core mechanisms of the Basis protocol has been simplified, especially around bond issuance and seigniorage distribution. We've thought deeply about the tradeoffs for these changes, and believe they allow significant gains in UX and contract simplicity, while preserving the intended behavior of the original monetary policy design. 
2. **Censorship resistant** - we launch this project anonymously, protected by the guise of characters from the popular SciFi series Rick and Morty. We believe this will allow the project to avoid the censorship of regulators that scuttled the original Basis Protocol, but will also allow Midas Dollar to avoid founder glorification & single points of failure that have plagued so many other projects. 
3. **Fairly distributed** - both Midas Dollar Shares and Midas Dollar has zero premine and no investors - community members can earn the initial supply of both assets by helping to contribute to bootstrap liquidity & adoption of Midas Dollar. 

### A Three-token System

There exists three types of assets in the Midas Dollar system. 

- **Midas Dollar ($MDO)**: a stablecoin, which the protocol aims to keep value-pegged to 1 US Dollar. 
- **Midas Dollar Bonds ($MDB)**: IOUs issued by the system to buy back Midas Dollar when price($MDO) < $1. Bonds are sold at a meaningful discount to price($MDO), and redeemed at $1 when price($MDO) normalizes to $1. 
- **Midas Dollar Shares ($MDS)**: receives surplus seigniorage (seigniorage left remaining after all the bonds have been redeemed).

## Conclusion

Midas Dollar is the latest product of the Midas Protocol ecosystem as we are strong supporters of algorithmic stablecoins in particular and DeFi in general. However, Midas Dollar is an experiment, and participants should take great caution and learn more about the seigniorage concept to avoid any potential loss.

#### Community channels:

- Telegram: https://t.me/midasprotocolglobal
- Discord: https://discord.gg/eTkKDyVq
- Medium: https://medium.com/midasprotocol
- Twitter: https://twitter.com/MidasDollar
- GitHub: https://github.com/MidasCore/midasdollar-protocol

## Disclaimer

Use at your own risk. This product is perpetually in beta.

_© Copyright 2021, [Midas Protocol](https://midasdollar.fi)_
