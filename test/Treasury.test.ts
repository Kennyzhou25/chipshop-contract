import chai, { expect } from 'chai';
import { ethers } from 'hardhat';
import { solidity } from 'ethereum-waffle';
import { Contract, ContractFactory, BigNumber, utils } from 'ethers';
import { Provider } from '@ethersproject/providers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address';

import { advanceTimeAndBlock } from './shared/utilities';

chai.use(solidity);

const DAY = 86400;
const ETH = utils.parseEther('1');
const ZERO = BigNumber.from(0);
const ZERO_ADDR = '0x0000000000000000000000000000000000000000';
const INITIAL_BSD_AMOUNT = utils.parseEther('50000');
const INITIAL_BSS_AMOUNT = utils.parseEther('10000');
const INITIAL_BSB_AMOUNT = utils.parseEther('50000');

async function latestBlocktime(provider: Provider): Promise<number> {
  const { timestamp } = await provider.getBlock('latest');
  return timestamp;
}

async function swapToken(
  provider: Provider,
  router: Contract,
  account: SignerWithAddress,
  amount: BigNumber,
  tokenA: Contract,
  tokenB: Contract
): Promise<void> {
  await router
    .connect(account)
    .swapExactTokensForTokens(
      amount,
      ZERO,
      [tokenA.address, tokenB.address],
      account.address,
      (await latestBlocktime(provider)) + 1800
    );
}

describe('Treasury', () => {
  const { provider } = ethers;

  let operator: SignerWithAddress;
  let ant: SignerWithAddress;

  before('provider & accounts setting', async () => {
    [operator, ant] = await ethers.getSigners();
  });

  // core
  let Bond: ContractFactory;
  let Dollar: ContractFactory;
  let Share: ContractFactory;
  let Treasury: ContractFactory;
  let MockOracle: ContractFactory;
  let MockBoardroom: ContractFactory;

  before('fetch contract factories', async () => {
    Bond = await ethers.getContractFactory('Bond');
    Dollar = await ethers.getContractFactory('Dollar');
    Share = await ethers.getContractFactory('Share');
    Treasury = await ethers.getContractFactory('Treasury');
    MockOracle = await ethers.getContractFactory('MockOracle');
    MockBoardroom = await ethers.getContractFactory('MockBoardroom');
  });

  let bond: Contract;
  let dollar: Contract;
  let share: Contract;
  let oracle: Contract;
  let treasury: Contract;
  let boardroom: Contract;

  let startTime: BigNumber;

  beforeEach('deploy contracts', async () => {
    dollar = await Dollar.connect(operator).deploy();
    bond = await Bond.connect(operator).deploy();
    share = await Share.connect(operator).deploy();
    oracle = await MockOracle.connect(operator).deploy();
    boardroom = await MockBoardroom.connect(operator).deploy(dollar.address);

    startTime = BigNumber.from(await latestBlocktime(provider)).add(DAY);
    treasury = await Treasury.connect(operator).deploy(
      dollar.address,
      bond.address,
      share.address,
      oracle.address,
      boardroom.address,
      startTime
    );
  });

  describe('governance', () => {
    let newTreasury: Contract;

    beforeEach('deploy new treasury', async () => {
      newTreasury = await Treasury.connect(operator).deploy(
        dollar.address,
        bond.address,
        share.address,
        oracle.address,
        boardroom.address,
        await latestBlocktime(provider)
      );

      for await (const token of [dollar, bond, share]) {
        await token.connect(operator).mint(treasury.address, ETH);
        await token.connect(operator).transferOperator(treasury.address);
        await token.connect(operator).transferOwnership(treasury.address);
      }
      await boardroom.connect(operator).transferOperator(treasury.address);
    });

    describe('#initialize', () => {
      it('should works correctly', async () => {
        await treasury.connect(operator).migrate(newTreasury.address);
        await boardroom.connect(operator).transferOperator(newTreasury.address);

        await expect(newTreasury.initialize())
          .to.emit(newTreasury, 'Initialized')
          .to.emit(dollar, 'Transfer')
          .withArgs(newTreasury.address, ZERO_ADDR, ETH)
          .to.emit(dollar, 'Transfer')
          .withArgs(ZERO_ADDR, newTreasury.address, ETH.mul(1001));

        expect(await newTreasury.getReserve()).to.eq(ETH.mul(1001));
      });

      it('should fail if newTreasury is not the operator of core contracts', async () => {
        await boardroom.connect(operator).transferOperator(ant.address);
        await expect(newTreasury.initialize()).to.revertedWith(
          'Treasury: need more permission'
        );
      });

      it('should fail if abuser tries to initialize twice', async () => {
        await treasury.connect(operator).migrate(newTreasury.address);
        await boardroom.connect(operator).transferOperator(newTreasury.address);

        await newTreasury.initialize();
        await expect(newTreasury.initialize()).to.revertedWith(
          'Treasury: already initialized'
        );
      });
    });

    describe('#migrate', () => {
      it('should works correctly', async () => {
        await expect(treasury.connect(operator).migrate(newTreasury.address))
          .to.emit(treasury, 'Migration')
          .withArgs(newTreasury.address);

        for await (const token of [dollar, bond, share]) {
          expect(await token.balanceOf(newTreasury.address)).to.eq(ETH);
          expect(await token.owner()).to.eq(newTreasury.address);
          expect(await token.operator()).to.eq(newTreasury.address);
        }
      });

      it('should fail if treasury is not the operator of core contracts', async () => {
        await boardroom.connect(operator).transferOperator(ant.address);
        await expect(
          treasury.connect(operator).migrate(newTreasury.address)
        ).to.revertedWith('Treasury: need more permission');
      });

      it('should fail if already migrated', async () => {
        await treasury.connect(operator).migrate(newTreasury.address);
        await boardroom.connect(operator).transferOperator(newTreasury.address);

        await newTreasury.connect(operator).migrate(treasury.address);
        await boardroom.connect(operator).transferOperator(treasury.address);

        await expect(
          treasury.connect(operator).migrate(newTreasury.address)
        ).to.revertedWith('Treasury: migrated');
      });
    });
  });

  describe('seigniorage', () => {
    describe('#allocateSeigniorage', () => {
      beforeEach('transfer permissions', async () => {
        await dollar.mint(operator.address, INITIAL_BSD_AMOUNT);
        await dollar.mint(treasury.address, INITIAL_BSD_AMOUNT);
        await share.mint(operator.address, INITIAL_BSS_AMOUNT);
        for await (const contract of [dollar, bond, share, boardroom]) {
          await contract.connect(operator).transferOperator(treasury.address);
        }
      });

      describe('after migration', () => {
        it('should fail if contract migrated', async () => {
          for await (const contract of [dollar, bond, share]) {
            await contract
              .connect(operator)
              .transferOwnership(treasury.address);
          }

          await treasury.connect(operator).migrate(operator.address);
          expect(await treasury.isMigrated()).to.be.true;

          await expect(treasury.allocateSeigniorage()).to.revertedWith(
            'Treasury: migrated'
          );
        });
      });

      describe('before startTime', () => {
        it('should fail if not started yet', async () => {
          await expect(treasury.allocateSeigniorage()).to.revertedWith(
            'Treasury: not started yet'
          );
        });
      });

      describe('after startTime', () => {
        beforeEach('advance blocktime', async () => {
          // wait til first epoch
          await advanceTimeAndBlock(
            provider,
            startTime.sub(await latestBlocktime(provider)).toNumber()
          );
        });

        it('should funded to treasury when seigniorageSaved below depletion floor', async () => {
          const dollarPrice = ETH.mul(106).div(100);
          await oracle.setPrice(dollarPrice);

          // calculate with circulating supply
          const treasuryReserve = await treasury.getReserve();
          const dollarSupply = (await dollar.totalSupply()).sub(treasuryReserve);
          const expectedSeigniorage = dollarSupply
            .mul(dollarPrice.sub(ETH))
            .div(ETH);

          await expect(treasury.allocateSeigniorage())
            .to.emit(treasury, 'TreasuryFunded')
            .withArgs(await latestBlocktime(provider), expectedSeigniorage);

          expect(await treasury.getReserve()).to.eq(
            expectedSeigniorage.add(treasuryReserve)
          );
        });

        it('should funded to boardroom when seigniorageSaved over depletion floor', async () => {
          // set treasury's balance to 1001 dollar
          await treasury.connect(operator).initialize();

          const dollarPrice = ETH.mul(106).div(100);
          await oracle.setPrice(dollarPrice);

          const treasuryReserve = await treasury.getReserve();
          const dollarSupply = (await dollar.totalSupply()).sub(treasuryReserve);
          const expectedSeigniorage = dollarSupply
            .mul(dollarPrice.sub(ETH))
            .div(ETH);

          await expect(treasury.allocateSeigniorage())
            .to.emit(treasury, 'BoardroomFunded')
            .withArgs(await latestBlocktime(provider), expectedSeigniorage)
            .to.emit(boardroom, 'RewardAdded')
            .withArgs(treasury.address, expectedSeigniorage);

          expect(await dollar.balanceOf(boardroom.address)).to.eq(
            expectedSeigniorage
          );
        });

        it('should funded even fails to call update function in oracle', async () => {
          const dollarPrice = ETH.mul(106).div(100);
          await oracle.setRevert(true);
          await oracle.setPrice(dollarPrice);

          await expect(treasury.allocateSeigniorage()).to.emit(
            treasury,
            'TreasuryFunded'
          );
        });

        it('should move to next epoch after allocation', async () => {
          const dollarPrice = ETH.mul(106).div(100);
          await oracle.setPrice(dollarPrice);

          expect(await treasury.epoch()).to.eq(BigNumber.from(0));
          expect(await treasury.nextEpochPoint()).to.eq(startTime);
          await treasury.allocateSeigniorage();
          expect(await treasury.epoch()).to.eq(BigNumber.from(1));
          expect(await treasury.nextEpochPoint()).to.eq(startTime.add(DAY));
        });

        describe('should fail', () => {
          it('if treasury is not the operator of core contract', async () => {
            const dollarPrice = ETH.mul(106).div(100);
            await oracle.setPrice(dollarPrice);

            for await (const target of [dollar, bond, share, boardroom]) {
              await target.connect(operator).transferOperator(ant.address);
              await expect(treasury.allocateSeigniorage()).to.revertedWith(
                'Treasury: need more permission'
              );
            }
          });

          it('if dollar price below $1+ε', async () => {
            await oracle.setPrice(ETH.mul(104).div(100));
            await expect(treasury.allocateSeigniorage()).to.revertedWith(
              'Treasury: there is no seigniorage to be allocated'
            );
          });

          it('if seigniorage already allocated in this epoch', async () => {
            const dollarPrice = ETH.mul(106).div(100);
            await oracle.setPrice(dollarPrice);
            await treasury.allocateSeigniorage();
            await expect(treasury.allocateSeigniorage()).to.revertedWith(
              'Treasury: not opened yet'
            );
          });
        });
      });
    });
  });

  describe('bonds', async () => {
    beforeEach('transfer permissions', async () => {
      await dollar.mint(operator.address, INITIAL_BSD_AMOUNT);
      await bond.mint(operator.address, INITIAL_BSB_AMOUNT);
      for await (const contract of [dollar, bond, share, boardroom]) {
        await contract.connect(operator).transferOperator(treasury.address);
      }
    });

    describe('after migration', () => {
      it('should fail if contract migrated', async () => {
        for await (const contract of [dollar, bond, share]) {
          await contract.connect(operator).transferOwnership(treasury.address);
        }

        await treasury.connect(operator).migrate(operator.address);
        expect(await treasury.isMigrated()).to.be.true;

        await expect(treasury.buyBonds(ETH, ETH)).to.revertedWith(
          'Treasury: migrated'
        );
        await expect(treasury.redeemBonds(ETH, ETH)).to.revertedWith(
          'Treasury: migrated'
        );
      });
    });

    describe('before startTime', () => {
      it('should fail if not started yet', async () => {
        await expect(treasury.buyBonds(ETH, ETH)).to.revertedWith(
          'Treasury: not started yet'
        );
        await expect(treasury.redeemBonds(ETH, ETH)).to.revertedWith(
          'Treasury: not started yet'
        );
      });
    });

    describe('after startTime', () => {
      beforeEach('advance blocktime', async () => {
        // wait til first epoch
        await advanceTimeAndBlock(
          provider,
          startTime.sub(await latestBlocktime(provider)).toNumber()
        );
      });

      describe('#buyBonds', () => {
        it('should work if dollar price below $1', async () => {
          const dollarPrice = ETH.mul(99).div(100); // $0.99
          await oracle.setPrice(dollarPrice);
          await dollar.connect(operator).transfer(ant.address, ETH);
          await dollar.connect(ant).approve(treasury.address, ETH);

          await expect(treasury.connect(ant).buyBonds(ETH, dollarPrice))
            .to.emit(treasury, 'BoughtBonds')
            .withArgs(ant.address, ETH);

          expect(await dollar.balanceOf(ant.address)).to.eq(ZERO);
          expect(await bond.balanceOf(ant.address)).to.eq(
            ETH.mul(ETH).div(dollarPrice)
          );
        });

        it('should fail if dollar price over $1', async () => {
          const dollarPrice = ETH.mul(101).div(100); // $1.01
          await oracle.setPrice(dollarPrice);
          await dollar.connect(operator).transfer(ant.address, ETH);
          await dollar.connect(ant).approve(treasury.address, ETH);

          await expect(
            treasury.connect(ant).buyBonds(ETH, dollarPrice)
          ).to.revertedWith(
            'Treasury: dollarPrice not eligible for bond purchase'
          );
        });

        it('should fail if price changed', async () => {
          const dollarPrice = ETH.mul(99).div(100); // $0.99
          await oracle.setPrice(dollarPrice);
          await dollar.connect(operator).transfer(ant.address, ETH);
          await dollar.connect(ant).approve(treasury.address, ETH);

          await expect(
            treasury.connect(ant).buyBonds(ETH, ETH)
          ).to.revertedWith('Treasury: dollar price moved');
        });

        it('should fail if purchase bonds with zero amount', async () => {
          const dollarPrice = ETH.mul(99).div(100); // $0.99
          await oracle.setPrice(dollarPrice);

          await expect(
            treasury.connect(ant).buyBonds(ZERO, dollarPrice)
          ).to.revertedWith('Treasury: cannot purchase bonds with zero amount');
        });
      });
      describe('#redeemBonds', () => {
        beforeEach('initialize treasury', async () => {
          await treasury.initialize();
        });

        it('should work if dollar price exceeds $1.05', async () => {
          const dollarPrice = ETH.mul(106).div(100);
          await oracle.setPrice(dollarPrice);

          await bond.connect(operator).transfer(ant.address, ETH);
          await bond.connect(ant).approve(treasury.address, ETH);
          await expect(treasury.connect(ant).redeemBonds(ETH, dollarPrice))
            .to.emit(treasury, 'RedeemedBonds')
            .withArgs(ant.address, ETH);

          expect(await treasury.getReserve()).to.eq(ETH.mul(1000));
          expect(await bond.balanceOf(ant.address)).to.eq(ZERO); // 1:1
          expect(await dollar.balanceOf(ant.address)).to.eq(ETH);
        });

        it("should drain over seigniorage and even contract's budget", async () => {
          const dollarPrice = ETH.mul(106).div(100);
          await oracle.setPrice(dollarPrice);

          await dollar.connect(operator).transfer(treasury.address, ETH); // $1002

          const treasuryBalance = await dollar.balanceOf(treasury.address);
          await bond.connect(operator).transfer(ant.address, treasuryBalance);
          await bond.connect(ant).approve(treasury.address, treasuryBalance);
          await treasury.connect(ant).redeemBonds(treasuryBalance, dollarPrice);

          expect(await treasury.getReserve()).to.eq(ZERO);
          expect(await bond.balanceOf(ant.address)).to.eq(ZERO);
          expect(await dollar.balanceOf(ant.address)).to.eq(treasuryBalance); // 1:1
        });

        it('should fail if price changed', async () => {
          const dollarPrice = ETH.mul(106).div(100);
          await oracle.setPrice(dollarPrice);

          await bond.connect(operator).transfer(ant.address, ETH);
          await bond.connect(ant).approve(treasury.address, ETH);
          await expect(
            treasury.connect(ant).redeemBonds(ETH, ETH)
          ).to.revertedWith('Treasury: dollar price moved');
        });

        it('should fail if redeem bonds with zero amount', async () => {
          const dollarPrice = ETH.mul(106).div(100);
          await oracle.setPrice(dollarPrice);

          await expect(
            treasury.connect(ant).redeemBonds(ZERO, dollarPrice)
          ).to.revertedWith('Treasury: cannot redeem bonds with zero amount');
        });

        it('should fail if dollar price is below $1+ε', async () => {
          const dollarPrice = ETH.mul(104).div(100);
          await oracle.setPrice(dollarPrice);

          await bond.connect(operator).transfer(ant.address, ETH);
          await bond.connect(ant).approve(treasury.address, ETH);
          await expect(
            treasury.connect(ant).redeemBonds(ETH, dollarPrice)
          ).to.revertedWith(
            'Treasury: dollarPrice not eligible for bond purchase'
          );
        });

        it("should fail if redeem bonds over contract's budget", async () => {
          const dollarPrice = ETH.mul(106).div(100);
          await oracle.setPrice(dollarPrice);

          const treasuryBalance = await dollar.balanceOf(treasury.address);
          const redeemAmount = treasuryBalance.add(ETH);
          await bond.connect(operator).transfer(ant.address, redeemAmount);
          await bond.connect(ant).approve(treasury.address, redeemAmount);

          await expect(
            treasury.connect(ant).redeemBonds(redeemAmount, dollarPrice)
          ).to.revertedWith('Treasury: treasury has no more budget');
        });
      });
    });
  });
});
