import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("NFT", function () {
  const settings = {
    name: "0.01 MATIC Game",
    symbol: "PNT01MATIC",
    startDatetime: Date.now(),
    totalSupply: 100,
    initialPrice: ethers.utils.parseEther("0.01"),
    maxPriceFactorPercentage: 100,
    transferFeePercentage: 50,
  };
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployNftFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, buyer, seller] = await ethers.getSigners();
    const Nft = await ethers.getContractFactory("NFT", owner);
    const masipagNft = await Nft.deploy(
      settings.name,
      settings.symbol,
      settings.startDatetime,
      settings.totalSupply,
      settings.initialPrice,
      settings.maxPriceFactorPercentage,
      settings.transferFeePercentage,
    );
    await masipagNft.deployed();

    return { Nft, masipagNft, owner, buyer, seller };
  }

  describe("Deployment", async function () {

    it("Should set the correct name", async function () {
      const { masipagNft } = await loadFixture(deployNftFixture);
      expect(await masipagNft.name()).to.equal(settings.name);
    });

    it("Should set the correct symbol", async function () {
      const { masipagNft } = await loadFixture(deployNftFixture);
      expect(await masipagNft.symbol()).to.equal(settings.symbol);
    });
  });

  describe("Buy and Sell", async function () {

    it("Should be able to buy tickets", async function () {
      const { masipagNft, owner, buyer, seller } = await loadFixture(deployNftFixture);
      console.log("before", {
        contract: ethers.utils.formatEther(await ethers.provider.getBalance(masipagNft.address)),
        owner: {
          eth: ethers.utils.formatEther(await ethers.provider.getBalance(owner.address)),
          token: (await masipagNft.balanceOf(owner.address)).toString(),
        },
        buyer: {
          eth: ethers.utils.formatEther(await ethers.provider.getBalance(buyer.address)),
          token: (await masipagNft.balanceOf(buyer.address)).toString(),
        },
        seller: {
          eth: ethers.utils.formatEther(await ethers.provider.getBalance(seller.address)),
          token: (await masipagNft.balanceOf(seller.address)).toString(),
        },
      });
      await masipagNft.connect(seller).buy({ value: settings.initialPrice });
      const ticket = await masipagNft.get(0);
      expect(ticket.price).to.equal(settings.initialPrice);
      expect(ticket.sale).to.equal(false);
      expect(ticket.used).to.equal(false);
      await masipagNft.connect(seller).setSale(0);
      expect(await masipagNft.balanceOf(seller.address)).to.equal(1);

      await masipagNft.connect(seller).approveBuy(0, buyer.address);
      await masipagNft.connect(buyer).buyFromUser(0, { value: settings.initialPrice });
      expect(await masipagNft.balanceOf(seller.address)).to.equal(0);
      expect(await masipagNft.balanceOf(buyer.address)).to.equal(1);
      console.log("after", {
        contract: ethers.utils.formatEther(await ethers.provider.getBalance(masipagNft.address)),
        owner: {
          eth: ethers.utils.formatEther(await ethers.provider.getBalance(owner.address)),
          token: (await masipagNft.balanceOf(owner.address)).toString(),
        },
        buyer: {
          eth: ethers.utils.formatEther(await ethers.provider.getBalance(buyer.address)),
          token: (await masipagNft.balanceOf(buyer.address)).toString(),
        },
        seller: {
          eth: ethers.utils.formatEther(await ethers.provider.getBalance(seller.address)),
          token: (await masipagNft.balanceOf(seller.address)).toString(),
        },
      });
    });
  });
});
