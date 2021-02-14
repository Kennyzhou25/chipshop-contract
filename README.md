# Midas Dollar

[![Twitter Follow](https://img.shields.io/twitter/follow/MidasDollar?label=Follow)](https://twitter.com/MidasDollar)

Midas Dollar is a lightweight implementation of the [Basis Protocol](basis.io) on Ethereum.

## Contract Addresses
| Contract  | Address |
| ------------- | ------------- |
| Midas Dollar (MDO) | [0x35e869B7456462b81cdB5e6e42434bD27f3F788c](https://bscscan.com/token/0x35e869B7456462b81cdB5e6e42434bD27f3F788c) |
| Midas Dollar Share (MDS) | [0x242E46490397ACCa94ED930F2C4EdF16250237fa](https://bscscan.com/token/0x242E46490397ACCa94ED930F2C4EdF16250237fa) |
| Midas Dollar Bond (MDB) | [0xCaD2109CC2816D47a796cB7a0B57988EC7611541](https://bscscan.com/token/0xCaD2109CC2816D47a796cB7a0B57988EC7611541) |
| MdoRewardPool | [0x3C4583375870573897154d8fAf71663e1e017Ef7](https://bscscan.com/address/0x3C4583375870573897154d8fAf71663e1e017Ef7#code) |
| ShareRewardPool | [0xecC17b190581C60811862E5dF8c9183dA98BD08a](https://bscscan.com/address/0xecC17b190581C60811862E5dF8c9183dA98BD08a#code) |
| Treasury | [0xD3372603Db4087FF5D797F91839c0Ca6b9aF294a](https://bscscan.com/address/0xD3372603Db4087FF5D797F91839c0Ca6b9aF294a#code) |
| Boardroom | [0xFF0b41ad7a85430FEbBC5220fd4c7a68013F2C0d](https://bscscan.com/address/0xFF0b41ad7a85430FEbBC5220fd4c7a68013F2C0d#code) |
| CommunityFund | [0xFaE8eDE4588aC961B7eAe5e6e2341369B43C4d92](https://bscscan.com/address/0xFaE8eDE4588aC961B7eAe5e6e2341369B43C4d92#code) |
| OracleSinglePair | [0x26593B4E6a803aac7f39955bd33C6826f266D7Fc](https://bscscan.com/address/0x26593B4E6a803aac7f39955bd33C6826f266D7Fc#code) |

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

1. (Boardroom) Epoch duration: 8 hours during expansion and 6 hours during contraction — the protocol reacts faster to stabilize MDO price to peg as compared to other protocols with longer epoch durations
2. Epoch Expansion: Capped at 6% if there are bonds to be redeemed, 4% if treasury is sufficiently full to meet bond redemption
3. MDB tokens do not expire and this greatly reduces the risk for bond buyers
4. Price feed oracle for TWAP is based on the average of 2 liquidity pool pairs (i.e. MDO/BUSD and MDO/USDT) which makes it more difficult to manipulate
5. The protocol keeps 75% of the expanded MDO supply for MDS boardroom stakers for each epoch expansion, 25% toward Midas DAO Fund. During debt phase, 50% of minted MDO will be sent to the treasury for MDS holders to participate in bond redemption.
6. No discount for bond purchase, but premium bonus for bond redemptions if users were to wait for MDO to increase even more than the 1 $BUSD peg
7. Riding on [Midas.eco](https://midas.eco) & [Mcashchain.eco](https://mcashchain.eco)’s various resources and ecosystem pillars, MDO will find its ever growing utilities right after launch, which is its great advantage over other algorithmic stablecoins.
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
