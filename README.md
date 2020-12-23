# Basis Dollar

[![Twitter Follow](https://img.shields.io/twitter/follow/basisdollar?label=Follow)](https://twitter.com/basisdollar)
[![License](https://img.shields.io/github/license/Basis-dollar/basisdollarprotocol)](https://github.com/Basis-Dollar/basisdollar-protocol/blob/master/LICENSE)
[![Coverage Status](https://coveralls.io/repos/github/Basis-Dollar/basisdollar-protocol/badge.svg?branch=master)](https://coveralls.io/github/Basis-Dollar/basisdollar-protocol?branch=master)

Basis Dollar is a lightweight implementation of the [Basis Protocol](basis.io) on Ethereum.

## Contract Addresses
| Contract  | Address |
| ------------- | ------------- |
| Basis Dollar (BSD) | [0x003e0af2916e598Fa5eA5Cb2Da4EDfdA9aEd9Fde](https://etherscan.io/token/0x003e0af2916e598Fa5eA5Cb2Da4EDfdA9aEd9Fde) |
| Basis Dollar Share (BSDS) | [0xE7C9C188138f7D70945D420d75F8Ca7d8ab9c700](https://etherscan.io/token/0xE7C9C188138f7D70945D420d75F8Ca7d8ab9c700) |
| Basis Dollar Bond (BSDB) | [0x9f48b2f14517770F2d238c787356F3b961a6616F](https://etherscan.io/token/0x9f48b2f14517770F2d238c787356F3b961a6616F) |
| Stables Farming Pool | [0xa249ee8255dF0AA00A15262b16BCA3eFD66c3E4C](https://etherscan.io/address/0xa249ee8255dF0AA00A15262b16BCA3eFD66c3E4C#code) |
| Timelock 24h | [0x95DB610b7A86c57410470cf48AebD743E05113Bc](https://etherscan.io/address/0x95DB610b7A86c57410470cf48AebD743E05113Bc#code) |

### DiffChecker
[Diff checker: BasisCash and BasisDollar](https://www.diffchecker.com/cAbZZfEX)

[Diff checker: MasterChef (Sushiswap) and StablesPool](https://www.diffchecker.com/75LLSt63)

## Audit
[Sushiswap - by PeckShield](https://github.com/peckshield/publications/blob/master/audit_reports/PeckShield-Audit-Report-SushiSwap-v1.0.pdf)

[Timelock - by Openzeppelin Security](https://blog.openzeppelin.com/compound-finance-patch-audit)

[BasisCash - by CertiK](https://www.dropbox.com/s/ed5vxvaple5e740/REP-Basis-Cash-06_11_2020.pdf)

## History of Basis

Basis is an algorithmic stablecoin protocol where the money supply is dynamically adjusted to meet changes in money demand.  

- When demand is rising, the blockchain will create more Basis Dollar. The expanded supply is designed to bring the Basis price back down.
- When demand is falling, the blockchain will buy back Basis Dollar. The contracted supply is designed to restore Basis price.
- The Basis protocol is designed to expand and contract supply similarly to the way central banks buy and sell fiscal debt to stabilize purchasing power. For this reason, we refer to Basis Dollar as having an algorithmic central bank.

Read the [Basis Whitepaper](http://basis.io/basis_whitepaper_en.pdf) for more details into the protocol. 

Basis was shut down in 2018, due to regulatory concerns its Bond and Share tokens have security characteristics. The project team opted for compliance, and shut down operations, returned money to investors and discontinued development of the project. 

## The Basis Dollar Protocol

Basis Dollar differs from the original Basis Project in several meaningful ways: 

1. **Rationally simplified** - several core mechanisms of the Basis protocol has been simplified, especially around bond issuance and seigniorage distribution. We've thought deeply about the tradeoffs for these changes, and believe they allow significant gains in UX and contract simplicity, while preserving the intended behavior of the original monetary policy design. 
2. **Censorship resistant** - we launch this project anonymously, protected by the guise of characters from the popular SciFi series Rick and Morty. We believe this will allow the project to avoid the censorship of regulators that scuttled the original Basis Protocol, but will also allow Basis Dollar to avoid founder glorification & single points of failure that have plagued so many other projects. 
3. **Fairly distributed** - both Basis Dollar Shares and Basis Dollar has zero premine and no investors - community members can earn the initial supply of both assets by helping to contribute to bootstrap liquidity & adoption of Basis Dollar. 

### A Three-token System

There exists three types of assets in the Basis Dollar system. 

- **Basis Dollar ($BSD)**: a stablecoin, which the protocol aims to keep value-pegged to 1 US Dollar. 
- **Basis Dollar Bonds ($BSDB)**: IOUs issued by the system to buy back Basis Dollar when price($BSD) < $1. Bonds are sold at a meaningful discount to price($BSD), and redeemed at $1 when price($BSD) normalizes to $1. 
- **Basis Dollar Shares ($BSDS)**: receives surplus seigniorage (seigniorage left remaining after all the bonds have been redeemed).

### Stability Mechanism

- **Contraction**: When the price($BSD) < ($1 - epsilon), users can trade in $BSD for $BSDB at the BSDBBSD exchange rate of price($BSD). This allows bonds to be always sold at a discount to dollar during a contraction.
- **Expansion**: When the price($BSD) > ($1 + epsilon), users can trade in 1 $BSDB for 1 $BSD. This allows bonds to be redeemed always at a premium to the purchase price. 
- **Seigniorage Allocation**: If there are no more bonds to be redeemed, (i.e. bond Supply is negligibly small), more $BSD is minted totalSupply($BSD) * (price($BSD) - 1), and placed in a pool for $BSDS holders to claim pro-rata in a 24 hour period. 

Read the official [Basis Dollar Documentation](https://docs.basisdollar.fi) for more details.

## How to Contribute

To chat with us & stay up to date, join our [Telegram](https://t.me/basisdollar).

Contribution guidelines are [here](./CONTRIBUTING.md)

For security concerns, please submit an issue [here](https://github.com/Basis-Dollar/basisdollar-contracts/issues/new).

## Disclaimer

Use at your own risk. This product is perpetually in beta.

There is a real possibility that a user could lose ALL of their money. Basis Dollar team assumes no responsibility for loss of funds. Audit us please, we have bounty fund for that.

_© Copyright 2020, Basis Dollar_
