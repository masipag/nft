import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("NFT", function () {
  const settings = {
    name: "2 MATIC Game",
    symbol: "2MG",
    startDatetime: Date.now(),
    initialPrice: ethers.utils.parseEther("2"),
    feePercentage: 50,
  };
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployNftFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, buyer, seller] = await ethers.getSigners();
    const NFT = await ethers.getContractFactory("NFT", owner);
    const masipagNft = await NFT.deploy(
      settings.name,
      settings.symbol,
      settings.startDatetime,
      settings.initialPrice,
      settings.feePercentage,
    );
    await masipagNft.deployed();

    return { NFT, masipagNft, owner, buyer, seller };
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

    it("Should be able to manage tickets", async function () {
      const { masipagNft, owner, buyer, seller } = await loadFixture(deployNftFixture);

      await masipagNft.connect(buyer).buy({ value: settings.initialPrice });
      let ticket = await masipagNft.get(0);
      expect(ticket.price).to.equal(settings.initialPrice);
      expect(ticket.sale).to.equal(false);
      expect(ticket.used).to.equal(false);

      let tickets = await masipagNft.getAll();
      expect(tickets.length).to.equal(1);

      await masipagNft.connect(seller).buy({ value: settings.initialPrice });
      tickets = await masipagNft.getAll();
      expect(tickets.length).to.equal(2);

      const newPrice = settings.initialPrice.add(1);
      await masipagNft.connect(seller).setPrice(1, settings.initialPrice.add(1));
      ticket = await masipagNft.get(1);
      expect(ticket.price).to.equal(newPrice);

      await masipagNft.connect(owner).destroy(0);
      tickets = await masipagNft.getAll();
      expect(tickets.length).to.equal(1);
    });

    it("Should be able to buy tickets", async function () {
      const { masipagNft, owner, buyer, seller } = await loadFixture(deployNftFixture);

      const ownerBalance = await ethers.provider.getBalance(owner.address);
      const contractBalance = await ethers.provider.getBalance(masipagNft.address);

      await masipagNft.connect(seller).buy({ value: settings.initialPrice });
      expect(await masipagNft.balanceOf(seller.address)).to.equal(1);
      expect(await ethers.provider.getBalance(masipagNft.address)).to.equal(contractBalance.add(settings.initialPrice));
      
      await masipagNft.connect(seller).setSale(0);
      expect(await masipagNft.balanceOf(buyer.address)).to.equal(0);

      await masipagNft.connect(seller).approveBuy(0, buyer.address);
      const priceToPay = await masipagNft.getPrice(0);
      const fee = await masipagNft.getFee(0);
      const netPrice = priceToPay.add(fee);
      await masipagNft.connect(buyer).buyFromReseller(0, { value: netPrice });
      expect(await masipagNft.balanceOf(seller.address)).to.equal(0);
      expect(await masipagNft.balanceOf(buyer.address)).to.equal(1);
      expect(await ethers.provider.getBalance(owner.address)).to.equal(ownerBalance.add(fee));
    });
  });
});
