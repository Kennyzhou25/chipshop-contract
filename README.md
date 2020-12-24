# bDollar

[![Twitter Follow](https://img.shields.io/twitter/follow/BearnFi?label=Follow)](https://twitter.com/BearnFi)

bDollar is a lightweight implementation of the [Basis Protocol](basis.io) on Ethereum.

## Contract Addresses
| Contract  | Address |
| ------------- | ------------- |
| bDollar (BDO) | [](https://etherscan.io/token/) |
| bDollar Share (sBDO) | [](https://etherscan.io/token/) |
| bDollar Bond (bBDO) | [](https://etherscan.io/token/) |
| BdoRewardPool | [](https://etherscan.io/address/#code) |
| Timelock 24h | [](https://etherscan.io/address/#code) |

## Audit
[Sushiswap - by PeckShield](https://github.com/peckshield/publications/blob/master/audit_reports/PeckShield-Audit-Report-SushiSwap-v1.0.pdf)

[Timelock - by Openzeppelin Security](https://blog.openzeppelin.com/compound-finance-patch-audit)

[BasisCash - by CertiK](https://www.dropbox.com/s/ed5vxvaple5e740/REP-Basis-Cash-06_11_2020.pdf)

## History of Basis

Basis is an algorithmic stablecoin protocol where the money supply is dynamically adjusted to meet changes in money demand.  

- When demand is rising, the blockchain will create more bDollar. The expanded supply is designed to bring the Basis price back down.
- When demand is falling, the blockchain will buy back bDollar. The contracted supply is designed to restore Basis price.
- The Basis protocol is designed to expand and contract supply similarly to the way central banks buy and sell fiscal debt to stabilize purchasing power. For this reason, we refer to bDollar as having an algorithmic central bank.

Read the [Basis Whitepaper](http://basis.io/basis_whitepaper_en.pdf) for more details into the protocol. 

Basis was shut down in 2018, due to regulatory concerns its Bond and Share tokens have security characteristics. 

## The bDollar Protocol

bDollar differs from the original Basis Project in several meaningful ways: 

1. **Rationally simplified** - several core mechanisms of the Basis protocol has been simplified, especially around bond issuance and seigniorage distribution. We've thought deeply about the tradeoffs for these changes, and believe they allow significant gains in UX and contract simplicity, while preserving the intended behavior of the original monetary policy design. 
2. **Censorship resistant** - we launch this project anonymously, protected by the guise of characters from the popular SciFi series Rick and Morty. We believe this will allow the project to avoid the censorship of regulators that scuttled the original Basis Protocol, but will also allow bDollar to avoid founder glorification & single points of failure that have plagued so many other projects. 
3. **Fairly distributed** - both bDollar Shares and bDollar has zero premine and no investors - community members can earn the initial supply of both assets by helping to contribute to bootstrap liquidity & adoption of bDollar. 

### A Three-token System

There exists three types of assets in the bDollar system. 

- **bDollar ($BDO)**: a stablecoin, which the protocol aims to keep value-pegged to 1 US Dollar. 
- **bDollar Bonds ($bBDO)**: IOUs issued by the system to buy back bDollar when price($BDO) < $1. Bonds are sold at a meaningful discount to price($BDO), and redeemed at $1 when price($BDO) normalizes to $1. 
- **bDollar Shares ($sBDO)**: receives surplus seigniorage (seigniorage left remaining after all the bonds have been redeemed).

## Disclaimer

Use at your own risk. This product is perpetually in beta.

_© Copyright 2020, bDollar_
