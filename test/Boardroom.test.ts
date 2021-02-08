import chai, {expect} from "chai";
import {ethers} from "hardhat";
import {solidity} from "ethereum-waffle";
import {Contract, ContractFactory, BigNumber, utils} from "ethers";
import {SignerWithAddress} from 'hardhat-deploy-ethers/dist/src/signer-with-address';
import { Provider } from '@ethersproject/providers';

chai.use(solidity);

async function latestBlocktime(provider: Provider): Promise<number> {
    const {timestamp} = await provider.getBlock("latest");
    return timestamp;
}

describe("Boardroom", () => {
    const DAY = 86400;
    const ETH = utils.parseEther("1");
    const ZERO = BigNumber.from(0);
    const STAKE_AMOUNT = ETH.mul(5000);
    const SEIGNIORAGE_AMOUNT = ETH.mul(10000);

    const {provider} = ethers;

    let operator: SignerWithAddress;
    let whale: SignerWithAddress;
    let abuser: SignerWithAddress;
    let rewardPool: SignerWithAddress;

    before("provider & accounts setting", async () => {
        [operator, whale, abuser, rewardPool] = await ethers.getSigners();
    });

    let Dollar: ContractFactory;
    let Bond: ContractFactory;
    let Share: ContractFactory;
    let Treasury: ContractFactory;
    let Boardroom: ContractFactory;

    before("fetch contract factories", async () => {
        Dollar = await ethers.getContractFactory("Dollar");
        Bond = await ethers.getContractFactory("Bond");
        Share = await ethers.getContractFactory("Share");
        Treasury = await ethers.getContractFactory("Treasury");
        Boardroom = await ethers.getContractFactory("Boardroom");
    });

    let dollar: Contract;
    let bond: Contract;
    let share: Contract;
    let treasury: Contract;
    let boardroom: Contract;

    let startTime: BigNumber;

    beforeEach("deploy contracts", async () => {
        dollar = await Dollar.connect(operator).deploy();
        bond = await Bond.connect(operator).deploy();
        share = await Share.connect(operator).deploy();
        treasury = await Treasury.connect(operator).deploy();
        startTime = BigNumber.from(await latestBlocktime(provider)).add(DAY);
        treasury = await Treasury.connect(operator).deploy();
        await dollar.connect(operator).mint(treasury.address, utils.parseEther("10000"));
        await treasury.connect(operator).initialize(dollar.address, bond.address, share.address, startTime);
        // boardroom = await Boardroom.connect(operator).deploy(dollar.address, share.address, treasury.address);
        boardroom = await Boardroom.connect(operator).deploy();
        await boardroom.connect(operator).initialize(dollar.address, share.address, treasury.address);
        await boardroom.connect(operator).setLockUp(0, 0);
    });

    describe("#stake", () => {
        it("should work correctly", async () => {
            await Promise.all([
                share.connect(operator).distributeReward(rewardPool.address),
                share.connect(rewardPool).transfer(whale.address, STAKE_AMOUNT),
                share.connect(whale).approve(boardroom.address, STAKE_AMOUNT),
            ]);

            await expect(boardroom.connect(whale).stake(STAKE_AMOUNT)).to.emit(boardroom, "Staked").withArgs(whale.address, STAKE_AMOUNT);

            const latestSnapshotIndex = await boardroom.latestSnapshotIndex();

            expect(await boardroom.balanceOf(whale.address)).to.eq(STAKE_AMOUNT);

            expect(await boardroom.getLastSnapshotIndexOf(whale.address)).to.eq(latestSnapshotIndex);
        });

        it("should fail when user tries to stake with zero amount", async () => {
            await expect(boardroom.connect(whale).stake(ZERO)).to.revertedWith("Boardroom: Cannot stake 0");
        });

        it("should fail initialize twice", async () => {
            await expect(boardroom.initialize(dollar.address, share.address, treasury.address)).to.revertedWith("Boardroom: already initialized");
        });
    });

    describe("#withdraw", () => {
        beforeEach("stake", async () => {
            await Promise.all([
                share.connect(operator).distributeReward(rewardPool.address),
                share.connect(rewardPool).transfer(whale.address, STAKE_AMOUNT),
                share.connect(whale).approve(boardroom.address, STAKE_AMOUNT),
            ]);
            await boardroom.connect(whale).stake(STAKE_AMOUNT);
        });

        it("should work correctly", async () => {
            await expect(boardroom.connect(whale).withdraw(STAKE_AMOUNT)).to.emit(boardroom, "Withdrawn").withArgs(whale.address, STAKE_AMOUNT);

            expect(await share.balanceOf(whale.address)).to.eq(STAKE_AMOUNT);
            expect(await boardroom.balanceOf(whale.address)).to.eq(ZERO);
        });

        it("should fail when user tries to withdraw with zero amount", async () => {
            await expect(boardroom.connect(whale).withdraw(ZERO)).to.revertedWith("Boardroom: Cannot withdraw 0");
        });

        it("should fail when user tries to withdraw more than staked amount", async () => {
            await expect(boardroom.connect(whale).withdraw(STAKE_AMOUNT.add(1))).to.revertedWith("Boardroom: withdraw request greater than staked amount");
        });

        it("should fail when non-director tries to withdraw", async () => {
            await expect(boardroom.connect(abuser).withdraw(ZERO)).to.revertedWith("Boardroom: The director does not exist");
        });

        it("should fail to withdraw if withdrawLockupEpochs > 0", async () => {
            await boardroom.connect(operator).setLockUp(5, 3); // set withdrawLockupEpochs = 5

            await expect(boardroom.connect(whale).withdraw(STAKE_AMOUNT)).to.revertedWith("Boardroom: still in withdraw lockup");

            expect(await share.balanceOf(whale.address)).to.eq(ZERO);
            expect(await boardroom.balanceOf(whale.address)).to.eq(STAKE_AMOUNT);
        });
    });

    describe("#exit", async () => {
        beforeEach("stake", async () => {
            await Promise.all([
                share.connect(operator).distributeReward(rewardPool.address),
                share.connect(rewardPool).transfer(whale.address, STAKE_AMOUNT),
                share.connect(whale).approve(boardroom.address, STAKE_AMOUNT),
            ]);
            await boardroom.connect(whale).stake(STAKE_AMOUNT);
        });

        it("should work correctly", async () => {
            await expect(boardroom.connect(whale).exit()).to.emit(boardroom, "Withdrawn").withArgs(whale.address, STAKE_AMOUNT);

            expect(await share.balanceOf(whale.address)).to.eq(STAKE_AMOUNT);
            expect(await boardroom.balanceOf(whale.address)).to.eq(ZERO);
        });
    });

    describe("#allocateSeigniorage", () => {
        beforeEach("stake", async () => {
            await Promise.all([
                share.connect(operator).distributeReward(rewardPool.address),
                share.connect(rewardPool).transfer(whale.address, STAKE_AMOUNT),
                share.connect(whale).approve(boardroom.address, STAKE_AMOUNT),
            ]);
            await boardroom.connect(whale).stake(STAKE_AMOUNT);
        });

        it("should allocate seigniorage to stakers", async () => {
            await dollar.connect(operator).mint(operator.address, SEIGNIORAGE_AMOUNT);
            await dollar.connect(operator).approve(boardroom.address, SEIGNIORAGE_AMOUNT);

            await expect(boardroom.connect(operator).allocateSeigniorage(SEIGNIORAGE_AMOUNT))
                .to.emit(boardroom, "RewardAdded")
                .withArgs(operator.address, SEIGNIORAGE_AMOUNT);

            expect(await boardroom.earned(whale.address)).to.eq(SEIGNIORAGE_AMOUNT);
        });

        it("should fail when user tries to allocate with zero amount", async () => {
            await expect(boardroom.connect(operator).allocateSeigniorage(ZERO)).to.revertedWith("Boardroom: Cannot allocate 0");
        });

        it("should fail when non-operator tries to allocate seigniorage", async () => {
            await expect(boardroom.connect(abuser).allocateSeigniorage(ZERO)).to.revertedWith("Boardroom: caller is not the operator");
        });
    });

    describe("#claimDividends", () => {
        beforeEach("stake", async () => {
            await Promise.all([
                share.connect(operator).distributeReward(rewardPool.address),
                share.connect(rewardPool).transfer(whale.address, STAKE_AMOUNT),
                share.connect(whale).approve(boardroom.address, STAKE_AMOUNT),

                share.connect(rewardPool).transfer(abuser.address, STAKE_AMOUNT),
                share.connect(abuser).approve(boardroom.address, STAKE_AMOUNT),
            ]);
            await boardroom.connect(whale).stake(STAKE_AMOUNT);
        });

        it("should claim dividends", async () => {
            await dollar.connect(operator).mint(operator.address, SEIGNIORAGE_AMOUNT);
            await dollar.connect(operator).approve(boardroom.address, SEIGNIORAGE_AMOUNT);
            await boardroom.connect(operator).allocateSeigniorage(SEIGNIORAGE_AMOUNT);

            await expect(boardroom.connect(whale).claimReward()).to.emit(boardroom, "RewardPaid").withArgs(whale.address, SEIGNIORAGE_AMOUNT);
            expect(await boardroom.balanceOf(whale.address)).to.eq(STAKE_AMOUNT);
        });

        it("should claim dividends correctly even after other person stakes after snapshot", async () => {
            await dollar.connect(operator).mint(operator.address, SEIGNIORAGE_AMOUNT);
            await dollar.connect(operator).approve(boardroom.address, SEIGNIORAGE_AMOUNT);
            await boardroom.connect(operator).allocateSeigniorage(SEIGNIORAGE_AMOUNT);

            await boardroom.connect(abuser).stake(STAKE_AMOUNT);

            await expect(boardroom.connect(whale).claimReward()).to.emit(boardroom, "RewardPaid").withArgs(whale.address, SEIGNIORAGE_AMOUNT);
            expect(await boardroom.balanceOf(whale.address)).to.eq(STAKE_AMOUNT);
        });

        it("should not claim dividends if rewardLockupEpochs > 0", async () => {
            await dollar.connect(operator).mint(operator.address, SEIGNIORAGE_AMOUNT);
            await dollar.connect(operator).approve(boardroom.address, SEIGNIORAGE_AMOUNT);
            await boardroom.connect(operator).allocateSeigniorage(SEIGNIORAGE_AMOUNT);
            await boardroom.connect(operator).setLockUp(5, 3); // set rewardLockupEpochs = 3

            await expect(boardroom.connect(whale).claimReward()).to.revertedWith("Boardroom: still in reward lockup");
            expect(await boardroom.balanceOf(whale.address)).to.eq(STAKE_AMOUNT);
        });
    });
});
