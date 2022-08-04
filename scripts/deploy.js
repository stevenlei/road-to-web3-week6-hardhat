async function main() {
  let minStakeSeconds = 120; // 2 minute
  let maxStakeSeconds = 240; // 4 minute
  let withdrawalPeriodEndsSeconds = 360; // 6 minute

  // Deploy Stake contract
  const Stake = await hre.ethers.getContractFactory("Stake");
  const stake = await Stake.deploy(
    hre.ethers.utils.parseUnits("1", "gwei") / 100,
    minStakeSeconds,
    maxStakeSeconds,
    withdrawalPeriodEndsSeconds
  );
  await stake.deployed();

  console.log(`Contract Stake deployed to ${stake.address}`);

  // Deposit some interest
  await stake.depositInterest({
    value: hre.ethers.utils.parseEther("1"),
  });

  // Deploy Treasury contract
  const Treasury = await hre.ethers.getContractFactory("Treasury");
  const treasury = await Treasury.deploy(stake.address);
  await treasury.deployed();

  console.log(`Contract Treasury deployed to ${treasury.address}`);

  // Set the treasury address
  await stake.setTreasury(treasury.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
