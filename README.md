# bDollar

[![Twitter Follow](https://img.shields.io/twitter/follow/bDollar_Fi?label=Follow)](https://twitter.com/bDollar_Fi)

bDollar is a lightweight implementation of the [Basis Protocol](basis.io) on Ethereum.

## Contract Addresses
| Contract  | Address |
| ------------- | ------------- |
| bDollar (BDO) | [0x190b589cf9Fb8DDEabBFeae36a813FFb2A702454](https://bscscan.com/token/0x190b589cf9Fb8DDEabBFeae36a813FFb2A702454) |
| bDollar Share (sBDO) | [0x0d9319565be7f53CeFE84Ad201Be3f40feAE2740](https://bscscan.com/token/0x0d9319565be7f53CeFE84Ad201Be3f40feAE2740) |
| bDollar Bond (bBDO) | [0x9586b02B09bd68A7cD4aa9167a61B78F43092063](https://bscscan.com/token/0x9586b02B09bd68A7cD4aa9167a61B78F43092063) |
| BdoRewardPool | [0x7A4cFC24841c799832fFF4E5038BBA14c0e73ced](https://bscscan.com/address/0x7A4cFC24841c799832fFF4E5038BBA14c0e73ced#code) |
| ShareRewardPool | [0x948dB1713D4392EC04C86189070557C5A8566766](https://bscscan.com/address/0x948dB1713D4392EC04C86189070557C5A8566766#code) |
| Treasury | [0x15A90e6157a870CD335AF03c6df776d0B1ebf94F](https://bscscan.com/address/0x15A90e6157a870CD335AF03c6df776d0B1ebf94F#code) |
| Boardroom | [0x9D39cd20901c88030032073Fb014AaF79D84d2C5](https://bscscan.com/address/0x9D39cd20901c88030032073Fb014AaF79D84d2C5#code) |
| CommunityFund | [0xeaDa3d1CCBBb1c6B4C40a16D34F64cb0df0225Fd](https://bscscan.com/address/0xeaDa3d1CCBBb1c6B4C40a16D34F64cb0df0225Fd#code) |
| OracleSinglePair | [0xfAB911c54f7CF3ffFdE0482d2267a751D87B5B20](https://bscscan.com/address/0xfAB911c54f7CF3ffFdE0482d2267a751D87B5B20#code) |
| Timelock 24h | [0x92a082Ad5A942140bCC791081F775900d0A514D9](https://bscscan.com/address/0x92a082Ad5A942140bCC791081F775900d0A514D9#code) |

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

## Conclusion

bDollar is the latest product of the Bearn.Fi ecosystem as we are strong supporters of algorithmic stablecoins in particular and DeFi in general. However, bDollar is an experiment, and participants should take great caution and learn more about the seigniorage concept to avoid any potential loss.

#### Community channels:

- Telegram: https://t.me/Bearn_Fi
- Discord: https://discord.gg/j2TRcSHRe3
- Medium: https://medium.com/@bearn.defi
- Twitter: https://twitter.com/BearnFi
- GitHub: https://github.com/bearn-defi/bdollar-smartcontracts

## Disclaimer

Use at your own risk. This product is perpetually in beta.

_© Copyright 2020, [bDollar.Fi](https://bdollar.fi)_
