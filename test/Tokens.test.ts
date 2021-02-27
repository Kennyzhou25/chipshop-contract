// @ts-ignore
import chai from "chai";
import {deployments, ethers} from 'hardhat';
import {expect} from './chai-setup';
import {solidity} from 'ethereum-waffle';
import {Contract, ContractFactory, BigNumber, utils} from "ethers";
import {SignerWithAddress} from 'hardhat-deploy-ethers/dist/src/signer-with-address';

chai.use(solidity);

describe("Tokens", () => {
    const ETH = utils.parseEther("1");
    const ZERO = BigNumber.from(0);
    const ZERO_ADDR = "0x0000000000000000000000000000000000000000";

    const {provider} = ethers;

    let operator: SignerWithAddress;
    let rewardPool: SignerWithAddress;

    before("setup accounts", async () => {
        [operator, rewardPool] = await ethers.getSigners();
    });

    let Bond: ContractFactory;
    let WantanMee: ContractFactory;
    let Share: ContractFactory;

    before("fetch contract factories", async () => {
        Bond = await ethers.getContractFactory("Bond");
        WantanMee = await ethers.getContractFactory("WantanMee");
        Share = await ethers.getContractFactory("Share");
    });

    describe("Bond", () => {
        let token: Contract;

        before("deploy token", async () => {
            token = await Bond.connect(operator).deploy();
        });

        it("mint", async () => {
            const mintAmount = ETH.mul(2);
            await expect(token.connect(operator).mint(operator.address, mintAmount))
                .to.emit(token, "Transfer")
                .withArgs(ZERO_ADDR, operator.address, mintAmount);
            expect(await token.balanceOf(operator.address)).to.eq(mintAmount);
        });

        it("burn", async () => {
            await expect(token.connect(operator).burn(ETH)).to.emit(token, "Transfer").withArgs(operator.address, ZERO_ADDR, ETH);
            expect(await token.balanceOf(operator.address)).to.eq(ETH);
        });

        it("burnFrom", async () => {
            await expect(token.connect(operator).approve(operator.address, ETH));
            await expect(token.connect(operator).burnFrom(operator.address, ETH)).to.emit(token, "Transfer").withArgs(operator.address, ZERO_ADDR, ETH);
            expect(await token.balanceOf(operator.address)).to.eq(ZERO);
        });
    });

    describe("Mee", () => {
        let token: Contract;

        before("deploy token", async () => {
            token = await WantanMee.connect(operator).deploy();
        });

        it("mint", async () => {
            await expect(token.connect(operator).mint(operator.address, ETH)).to.emit(token, "Transfer").withArgs(ZERO_ADDR, operator.address, ETH);
            expect(await token.balanceOf(operator.address)).to.eq(ETH.mul(2));
        });

        it("burn", async () => {
            await expect(token.connect(operator).burn(ETH)).to.emit(token, "Transfer").withArgs(operator.address, ZERO_ADDR, ETH);
            expect(await token.balanceOf(operator.address)).to.eq(ETH);
        });

        it("burnFrom", async () => {
            await expect(token.connect(operator).approve(operator.address, ETH));
            await expect(token.connect(operator).burnFrom(operator.address, ETH)).to.emit(token, "Transfer").withArgs(operator.address, ZERO_ADDR, ETH);
            expect(await token.balanceOf(operator.address)).to.eq(ZERO);
        });
    });

    describe("Share", () => {
        let token: Contract;

        before("deploy token", async () => {
            token = await Share.connect(operator).deploy();
        });

        it("distributeReward", async () => {
            await token.connect(operator).distributeReward(rewardPool.address);
            await expect(token.connect(rewardPool).transfer(operator.address, ETH))
                .to.emit(token, "Transfer")
                .withArgs(rewardPool.address, operator.address, ETH);
            expect(await token.balanceOf(rewardPool.address)).to.eq(utils.parseEther('863.2021'));
            expect(await token.balanceOf(operator.address)).to.eq(utils.parseEther('1.2021'));
        });

        it("burn", async () => {
            await expect(token.connect(operator).burn(ETH)).to.emit(token, "Transfer").withArgs(operator.address, ZERO_ADDR, ETH);
            expect(await token.balanceOf(operator.address)).to.eq(utils.parseEther('0.2021'));
        });

        it("burnFrom", async () => {
            let amt = utils.parseEther('0.2021');
            await expect(token.connect(operator).approve(operator.address, amt));
            await expect(token.connect(operator).burnFrom(operator.address, amt)).to.emit(token, "Transfer").withArgs(operator.address, ZERO_ADDR, amt);
            expect(await token.balanceOf(operator.address)).to.eq(ZERO);
        });
    });
});
