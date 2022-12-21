import { ethers } from "hardhat";

async function main() {
  const settings = {
    name: "1 MATIC Game",
    symbol: "1MG",
    startDatetime: Date.now(),
    totalSupply: 100,
    initialPrice: ethers.utils.parseEther("1"),
    maxPriceFactorPercentage: 100,
    transferFeePercentage: 50,
  };
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());
  const Nft = await ethers.getContractFactory("NFT", deployer);
  const nft = await Nft.deploy(
    settings.name,
    settings.symbol,
    settings.startDatetime,
    settings.totalSupply,
    settings.initialPrice,
    settings.maxPriceFactorPercentage,
    settings.transferFeePercentage,
  );
  await nft.deployed();
  console.log("Token address:", nft.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
