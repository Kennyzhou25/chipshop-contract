import chai, {expect} from 'chai';
import {ethers} from 'hardhat';
import {solidity} from 'ethereum-waffle';
import {Contract, ContractFactory, BigNumber, utils} from 'ethers';
import {Provider} from '@ethersproject/providers';
import {SignerWithAddress} from 'hardhat-deploy-ethers/dist/src/signer-with-address';

import { advanceBlock, advanceTimeAndBlock } from './shared/utilities';

chai.use(solidity);

const DAY = 86400;
const ETH = utils.parseEther('1');
const ZERO = BigNumber.from(0);
const ZERO_ADDR = '0x0000000000000000000000000000000000000000';
const INITIAL_AMOUNT = utils.parseEther('1000');
const MAX_UINT256 = '0xffffffffffffffffffffffffffffffffffffffff';

async function latestBlocktime(provider: Provider): Promise<number> {
    const {timestamp} = await provider.getBlock('latest');
    return timestamp;
}

async function latestBlocknumber(provider: Provider): Promise<number> {
    return await provider.getBlockNumber();
}

describe('ShareRewardPool.test', () => {
    const {provider} = ethers;

    let operator: SignerWithAddress;
    let bob: SignerWithAddress;
    let carol: SignerWithAddress;
    let david: SignerWithAddress;

    before('provider & accounts setting', async () => {
        [operator, bob, carol, david] = await ethers.getSigners();
    });

    // core
    let ShareRewardPool: ContractFactory;
    let Share: ContractFactory;
    let MockERC20: ContractFactory;

    before('fetch contract factories', async () => {
        ShareRewardPool = await ethers.getContractFactory('ShareRewardPool');
        Share = await ethers.getContractFactory('Share');
        MockERC20 = await ethers.getContractFactory('MockERC20');
    });

    let pool: Contract;
    let share: Contract;
    let dai: Contract;
    let usdc: Contract;
    let usdt: Contract;
    let busd: Contract;
    let esd: Contract;

    let startBlock: BigNumber;

    before('deploy contracts', async () => {
        share = await Share.connect(operator).deploy();
        dai = await MockERC20.connect(operator).deploy('Dai Stablecoin', 'DAI', 18);
        usdc = await MockERC20.connect(operator).deploy('USD Circle', 'USDC', 6);
        usdt = await MockERC20.connect(operator).deploy('Tether', 'USDT', 6);
        busd = await MockERC20.connect(operator).deploy('Binance USD', 'BUSD', 18);
        esd = await MockERC20.connect(operator).deploy('Empty Set Share', 'ESD', 18);

        startBlock = BigNumber.from(await latestBlocknumber(provider)).add(4);
        pool = await ShareRewardPool.connect(operator).deploy(share.address, startBlock);
        await pool.connect(operator).add(8000, dai.address, false, 0);
        await pool.connect(operator).add(2000, busd.address, false, 0);
        await pool.connect(operator).add(1000, usdt.address, false, 0);

        await share.connect(operator).distributeReward(pool.address);

        for await (const user of [bob, carol, david]) {
            await dai.connect(operator).mint(user.address, INITIAL_AMOUNT);
            await usdc.connect(operator).mint(user.address, '1000000000');
            await usdt.connect(operator).mint(user.address, '1000000000');
            await busd.connect(operator).mint(user.address, INITIAL_AMOUNT);
            await esd.connect(operator).mint(user.address, INITIAL_AMOUNT);

            for await (const token of [dai, usdc, usdt, busd, esd]) {
                await token.connect(user).approve(pool.address, MAX_UINT256);
            }
        }
    });

    describe('#constructor', () => {
        it('should works correctly', async () => {
            expect(String(await share.balanceOf(pool.address))).to.eq(utils.parseEther('85000'));
            expect(String(await pool.startBlock())).to.eq('10');
            expect(String(await pool.runningBlocks())).to.eq(String(10625000));
            expect(String(await pool.endBlock())).to.eq(String(10625000 + 10));
            expect(String(await pool.sbdoPerBlock())).to.eq(utils.parseEther('0.008'));
            expect(String(await pool.getGeneratedReward(10, 11))).to.eq(utils.parseEther('0.008'));
            expect(String(await pool.getGeneratedReward(20, 30))).to.eq(utils.parseEther('0.08'));
            expect(String(await pool.getGeneratedReward(10625009, 10625011))).to.eq(utils.parseEther('0.008'));
        });

        it('Share.claimRewards', async () => {
            await share.connect(operator).claimRewards();
            expect(String(await share.balanceOf(operator.address))).to.gt(ZERO);
        });
    });

    describe('#deposit/withdraw', () => {
        it('bob deposit 10 DAI', async () => {
            await expect(async () => {
                await pool.connect(bob).deposit(0, utils.parseEther('10'));
            }).to.changeTokenBalances(dai, [bob, pool], [utils.parseEther('-10'), utils.parseEther('10')]);
        });

        it('carol deposit 20 DAI and 10 USDT', async () => {
            let _beforeUSDT = await usdt.balanceOf(carol.address);
            await expect(async () => {
                await pool.connect(carol).deposit(0, utils.parseEther('20'));
                await pool.connect(carol).deposit(2, '10000000');
            }).to.changeTokenBalances(dai, [carol, pool], [utils.parseEther('-20'), utils.parseEther('20')]);
            let _afterUSDT = await usdt.balanceOf(carol.address);
            expect(_beforeUSDT.sub(_afterUSDT)).to.eq('10000000');
        });

        it('david deposit 10 DAI and 10 BNB', async () => {
            await expect(async () => {
                await pool.connect(david).deposit(0, utils.parseEther('10'));
                await pool.connect(david).deposit(1, utils.parseEther('10'));
            }).to.changeTokenBalances(busd, [david, pool], [utils.parseEther('-10'), utils.parseEther('10')]);
        });

        it('pendingShare()', async () => {
            await advanceBlock(provider);
            expect(await pool.pendingShare(0, bob.address)).to.eq(utils.parseEther('0.01260606060606058'));
            expect(await pool.pendingShare(2, bob.address)).to.eq(utils.parseEther('0'));
            expect(await pool.pendingShare(0, carol.address)).to.eq(utils.parseEther('0.01357575757575754'));
            expect(await pool.pendingShare(2, carol.address)).to.eq(utils.parseEther('0.002181818181818181'));
            expect(await pool.pendingShare(0, david.address)).to.eq(utils.parseEther('0.0029090909090909'));
            expect(await pool.pendingShare(2, david.address)).to.eq(utils.parseEther('0'));
            expect(await pool.pendingShare(1, david.address)).to.eq(utils.parseEther('0.00145454545454545'));
        });

        it('carol withdraw 20 DAI', async () => {
            await advanceBlock(provider);
            await expect(pool.connect(carol).withdraw(0, utils.parseEther('20.01'))).to.revertedWith('withdraw: not good');
            let _beforeDAI = await dai.balanceOf(carol.address);
            await expect(async () => {
                await pool.connect(carol).withdraw(0, utils.parseEther('20'));
            }).to.changeTokenBalances(share, [carol, pool], [utils.parseEther('0.02230303030303028'), utils.parseEther('-0.02230303030303028')]);
            let _afterDAI = await dai.balanceOf(carol.address);
            expect(_afterDAI.sub(_beforeDAI)).to.eq(utils.parseEther('20'));
        });
    });
});
