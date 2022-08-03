const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Deployment", () => {
  it("Should deploy Stake contract with correct parameters", async () => {
    const Stake = await ethers.getContractFactory("Stake");

    let interestRate = ethers.utils.parseUnits("1", "gwei") / 100; // 1%
    let minStakeSeconds = 5; // 10 seconds
    let maxStakeSeconds = 10; // 10 seconds
    let withdrawalPeriodEndsSeconds = 15; // 15 seconds

    const stake = await Stake.deploy(
      interestRate,
      minStakeSeconds,
      maxStakeSeconds,
      withdrawalPeriodEndsSeconds
    );

    await stake.deployed();

    expect(await stake.interestRate()).to.equal(interestRate);
    expect(await stake.minStakeSeconds()).to.equal(minStakeSeconds);
    expect(await stake.maxStakeSeconds()).to.equal(maxStakeSeconds);
    expect(await stake.withdrawalPeriodEndsSeconds()).to.equal(
      withdrawalPeriodEndsSeconds
    );
  });

  it("Should deploy Treasury contract with correct settings", async () => {
    const Stake = await ethers.getContractFactory("Stake");

    let interestRate = ethers.utils.parseUnits("1", "gwei") / 100; // 1%
    let minStakeSeconds = 5; // 10 seconds
    let maxStakeSeconds = 10; // 10 seconds
    let withdrawalPeriodEndsSeconds = 15; // 15 seconds

    const stake = await Stake.deploy(
      interestRate,
      minStakeSeconds,
      maxStakeSeconds,
      withdrawalPeriodEndsSeconds
    );

    await stake.deployed();

    const Treasury = await ethers.getContractFactory("Treasury");
    const treasury = await Treasury.deploy(stake.address);
    await treasury.deployed();

    expect(await treasury.allowedCaller()).to.equal(stake.address);

    await stake.setTreasury(treasury.address);
    expect(await stake.treasury()).to.equal(treasury.address);
  });
});

describe("Logic Test", () => {
  async function deployContractFixture() {
    const [owner, addr1, addr2] = await ethers.getSigners();
    const provider = ethers.provider;

    const Stake = await ethers.getContractFactory("Stake");

    let interestRate = ethers.utils.parseUnits("1", "gwei") / 100; // 1%
    let minStakeSeconds = 5; // 10 seconds
    let maxStakeSeconds = 10; // 10 seconds
    let withdrawalPeriodEndsSeconds = 15; // 15 seconds

    const stake = await Stake.deploy(
      interestRate,
      minStakeSeconds,
      maxStakeSeconds,
      withdrawalPeriodEndsSeconds
    );

    await stake.deployed();

    const Treasury = await ethers.getContractFactory("Treasury");
    const treasury = await Treasury.deploy(stake.address);
    await treasury.deployed();

    return {
      interestRate,
      minStakeSeconds,
      maxStakeSeconds,
      withdrawalPeriodEndsSeconds,
      stake,
      treasury,
      owner,
      addr1,
      addr2,
      provider,
    };
  }

  it("Should be able to receive ether", async () => {
    const { stake, treasury, addr1 } = await loadFixture(deployContractFixture);

    const amount = ethers.utils.parseUnits("1", "ether");
    await addr1.sendTransaction({
      to: stake.address,
      value: amount,
    });

    expect(await stake.getBalance(addr1.address)).to.equal(amount);
  });

  it("Should be able to withdraw ether", async () => {
    const { stake, treasury, addr1 } = await loadFixture(deployContractFixture);

    const amount = ethers.utils.parseUnits("1", "ether");
    await addr1.sendTransaction({
      to: stake.address,
      value: amount,
    });

    let currentBalance = await addr1.getBalance();

    // 1. let's do a withdrawal
    const tx = await stake.connect(addr1).withdraw();

    // 2. Let's calculate the gas spent
    const receipt = await tx.wait();
    const gasSpent = receipt.gasUsed.mul(receipt.effectiveGasPrice);

    expect(await addr1.getBalance()).to.equal(
      currentBalance.add(amount.sub(gasSpent))
    );
  });

  it("Should be able to deposit interest by owner", async () => {
    const { stake, treasury, owner } = await loadFixture(deployContractFixture);

    let amount = ethers.utils.parseUnits("1", "ether");

    await stake.depositInterest({
      value: amount,
    });

    expect(await stake.availableInterest()).to.equal(amount);
  });

  it("Should be able to stake", async () => {
    const { stake, treasury, owner, addr1, provider } = await loadFixture(
      deployContractFixture
    );

    await stake.setTreasury(treasury.address);

    await stake.depositInterest({
      value: ethers.utils.parseUnits("1", "ether"),
    });

    const amount = ethers.utils.parseUnits("1", "ether");
    await addr1.sendTransaction({
      to: stake.address,
      value: amount,
    });

    await stake.connect(addr1).stake(amount);

    expect(await stake.getStake(addr1.address)).to.equal(amount);
    expect(await provider.getBalance(treasury.address)).to.equal(amount);
  });

  it("Should NOT be able to unstake immediately", async () => {
    const { stake, treasury, owner, addr1, provider } = await loadFixture(
      deployContractFixture
    );

    await stake.setTreasury(treasury.address);

    await stake.depositInterest({
      value: ethers.utils.parseUnits("1", "ether"),
    });

    const amount = ethers.utils.parseUnits("1", "ether");
    await addr1.sendTransaction({
      to: stake.address,
      value: amount,
    });

    await stake.connect(addr1).stake(amount);

    await expect(stake.connect(addr1).unstake()).to.be.revertedWith(
      "You can't unstake yet"
    );
  });

  it("Should be able to unstake after 5 seconds", async () => {
    const { stake, treasury, owner, addr1, provider } = await loadFixture(
      deployContractFixture
    );

    await stake.setTreasury(treasury.address);

    await stake.depositInterest({
      value: ethers.utils.parseUnits("1", "ether"),
    });

    const amount = ethers.utils.parseUnits("1", "ether");
    await addr1.sendTransaction({
      to: stake.address,
      value: amount,
    });

    await stake.connect(addr1).stake(amount);

    await wait(5000);

    await stake.connect(addr1).unstake();

    expect(await stake.getStake(addr1.address)).to.equal(0);
    expect(await provider.getBalance(treasury.address)).to.equal(0);
  });

  it("Should be able to unstake after 10 seconds and get full interest", async () => {
    const { stake, treasury, owner, addr1, provider } = await loadFixture(
      deployContractFixture
    );

    await stake.setTreasury(treasury.address);

    await stake.depositInterest({
      value: ethers.utils.parseUnits("1", "ether"),
    });

    const amount = ethers.utils.parseUnits("1", "ether");
    await addr1.sendTransaction({
      to: stake.address,
      value: amount,
    });

    await stake.connect(addr1).stake(amount);

    await wait(10000);

    await stake.connect(addr1).unstake();

    expect(await stake.getBalance(addr1.address)).to.equal(
      ethers.utils.parseEther("1.01")
    );
  });

  it("Should NOT be able to unstake after 15 seconds", async () => {
    const { stake, treasury, owner, addr1, provider } = await loadFixture(
      deployContractFixture
    );

    await stake.setTreasury(treasury.address);

    await stake.depositInterest({
      value: ethers.utils.parseUnits("1", "ether"),
    });

    const amount = ethers.utils.parseUnits("1", "ether");
    await addr1.sendTransaction({
      to: stake.address,
      value: amount,
    });

    await stake.connect(addr1).stake(amount);

    await wait(16000);

    await expect(stake.connect(addr1).unstake()).to.be.revertedWith(
      "Unstake period exceeded"
    );
  });
});

async function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
