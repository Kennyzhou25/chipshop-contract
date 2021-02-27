# Wantan Mee

[![Twitter Follow](https://img.shields.io/twitter/follow/Our_Wantanmee?label=Follow)](https://twitter.com/Our_Wantanmee)

Wantan Mee is a lightweight implementation of the [Basis Protocol](basis.io) on Ethereum.

## Contract Addresses
| Contract  | Address |
| ------------- | ------------- |
| Wantan Mee (MEE) | [0x57aE681cF079740d1f2d7E0078a779B7443c2a21](https://bscscan.com/token/0x57aE681cF079740d1f2d7E0078a779B7443c2a21) |
| Wantan Mee Share (MES) | [0x5573d653Dd0b7265Af26D77055F4F6E9AeA291fC](https://bscscan.com/token/0x5573d653Dd0b7265Af26D77055F4F6E9AeA291fC) |
| Wantan Mee Bond (MEB) | [0xe5082ee0D854AB28cdf3D8beBf2e8C1826D90523](https://bscscan.com/token/0xe5082ee0D854AB28cdf3D8beBf2e8C1826D90523) |
| MeeRewardPool | [0x4c8170476eF5aC641F9a1045adFF75e42E51c33A](https://bscscan.com/address/0x4c8170476eF5aC641F9a1045adFF75e42E51c33A#code) |
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

- When demand is rising, the blockchain will create more Wantan Mee. The expanded supply is designed to bring the Basis price back down.
- When demand is falling, the blockchain will buy back Wantan Mee. The contracted supply is designed to restore Basis price.
- The Basis protocol is designed to expand and contract supply similarly to the way central banks buy and sell fiscal debt to stabilize purchasing power. For this reason, we refer to Wantan Mee as having an algorithmic central bank.

Read the [Basis Whitepaper](http://basis.io/basis_whitepaper_en.pdf) for more details into the protocol. 

Basis was shut down in 2018, due to regulatory concerns its Bond and Share tokens have security characteristics. 

## The Wantan Mee Protocol

Wantan Mee differs from the original Basis Project in several meaningful ways: 

1. (Boardroom) Epoch duration: 8 hours during expansion and 6 hours during contraction — the protocol reacts faster to stabilize MEE price to peg as compared to other protocols with longer epoch durations
2. Epoch Expansion: Capped at 6% if there are bonds to be redeemed, 4% if treasury is sufficiently full to meet bond redemption
3. MEB tokens do not expire and this greatly reduces the risk for bond buyers
4. Price feed oracle for TWAP is based on the average of 2 liquidity pool pairs (i.e. MEE/BETH and MEE/ETH) which makes it more difficult to manipulate
5. The protocol keeps 75% of the expanded MEE supply for MES boardroom stakers for each epoch expansion, 3% to MEE/WBNB farming pool, 22% toward DAO Fund. During debt phase, 50% of minted MEE will be sent to the treasury for MES holders to participate in bond redemption.
6. No discount for bond purchase, but premium bonus for bond redemptions if users were to wait for MEE to increase even more than the 1 BETH peg
### A Three-token System

There exists three types of assets in the Wantan Mee system. 

- **Wantan Mee ($MEE)**: a stablecoin, which the protocol aims to keep value-pegged to 1 BETH
- **Wantan Mee Bonds ($MEB)**: IOUs issued by the system to buy back Wantan Mee when price($MEE) < 1 BETH. Bonds are sold at a meaningful discount to price($MEE), and redeemed at $1 when price($MEE) normalizes to 1 BETH. 
- **Wantan Mee Shares ($MES)**: receives surplus seigniorage (seigniorage left remaining after all the bonds have been redeemed).

## Conclusion

Wantan Mee is the latest product of the Midas Protocol ecosystem as we are strong supporters of algorithmic stablecoins in particular and DeFi in general. However, Wantan Mee is an experiment, and participants should take great caution and learn more about the seigniorage concept to avoid any potential loss.

#### Community channels:

- Telegram: https://t.me/Wantamme_News
- Medium: https://wantanmee.medium.com/
- Twitter: https://twitter.com/Our_Wantanmee
- GitHub: https://github.com/wantanmee-finance/wantanmee-contracts

## Disclaimer

Use at your own risk. This product is perpetually in beta.

_© Copyright 2021, [WantanMee Protocol](https://wantanmee.finance)_
