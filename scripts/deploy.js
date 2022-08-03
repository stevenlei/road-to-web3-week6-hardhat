async function main() {
  const Stake = await hre.ethers.getContractFactory("Stake");
  const stake = await Stake.deploy(
    hre.ethers.utils.parseUnits("1", "gwei") / 100,
    10,
    120,
    600
  );
  await stake.deployed();

  console.log(`Contract Stake deployed to ${stake.address}`);

  console.log(
    await stake.calculateInterest(
      hre.ethers.utils.parseUnits("1", "ether"),
      120
    )
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
