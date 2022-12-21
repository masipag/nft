import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("NFT", function () {
  const settings = {
    name: "100000 SHIB Game",
    symbol: "1KSHIB",
    startDatetime: Date.now(),
    totalSupply: 100,
    initialPrice: ethers.utils.parseEther('0.5'),
    maxPriceFactorPercentage: 100,
    transferFeePercentag: 1,
  };
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployNftFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();
    const Nft = await ethers.getContractFactory("NFT", owner);
    const masipagNft = await Nft.deploy(
      settings.name,
      settings.symbol,
      settings.startDatetime,
      settings.totalSupply,
      settings.initialPrice,
      settings.maxPriceFactorPercentage,
      settings.transferFeePercentag,
    );
    await masipagNft.deployed();

    return { Nft, masipagNft, owner, otherAccount };
  }

  describe("Deployment", async function () {
    const { masipagNft } = await loadFixture(deployNftFixture);

    it("Should set the correct name", async function () {
      expect(await masipagNft.name()).to.equal(settings.name);
    });

    it("Should set the correct symbol", async function () {
      expect(await masipagNft.symbol()).to.equal(settings.symbol);
    });
  });

  describe("Buy and Sell", async function () {
    const { masipagNft, owner, otherAccount } = await loadFixture(deployNftFixture);
    const seller = owner;
    const buyer = otherAccount;

    it("Should be able to buy tickets", async function () {
      await masipagNft.connect(seller).buyTicket({ value: settings.initialPrice });
      const ticket = await masipagNft.getTicket(0);
      expect(ticket.price).to.equal(settings.initialPrice);
      expect(ticket.sale).to.equal(false);
      expect(ticket.used).to.equal(false);
      const balance = await masipagNft.balanceOf(seller.address);
      expect(balance).to.equal(1);

      // await masipagNft.connect(buyer).buyTicketFromAttendee(0);
    });
  });
});
