// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

contract NFT is ERC721, Ownable {
    struct Ticket {
        uint256 price;
        bool sale;
        bool used;
    }
    mapping(address => Ticket) tickets;
    address[] ticketKeys;

    uint64 public startAt;
    uint256 public initPrice;
    uint64 public feePct;
    address payable payoutAddr;

    constructor(
        string memory _name,
        string memory _symbol,
        uint64 _startAt,
        uint256 _initPrice,
        uint64 _feePct
    ) ERC721(_name, _symbol) {
        payoutAddr = payable(msg.sender);
        startAt = uint64(_startAt);
        initPrice = uint256(_initPrice);
        feePct = uint64(_feePct);
    }

    event TicketCreated(address id);
    event TicketSale(address id, uint256 price);
    event TicketSaleCancelled(address id);
    event TicketSold(
        address to,
        address id,
        uint256 price,
        uint256 fee
    );
    event TicketPriceChanged(address id, uint256 price);
    event Withdrawal(address by, address to, uint256 amount);

    modifier started() {
        require((uint64(block.timestamp) >= startAt), "event not started");
        _;
    }

    modifier unused(address id) {
        require(tickets[id].used != true, "ticket already used");
        _;
    }

    modifier isOwned(address id) {
        uint256 tokenId = uint256(uint160(id));
        require((ownerOf(tokenId) == msg.sender), "no permission");
        _;
    }

    function use(address id) public onlyOwner {
        tickets[id].used = true;
    }

    function setPrice(
        address id,
        uint256 price
    ) public started unused(id) isOwned(id) {
        require((price >= initPrice), "price must be >= initial price");
        tickets[id].price = price;
        emit TicketPriceChanged(msg.sender, price);
    }

    function setStartAt(uint64 _startAt) public started onlyOwner {
        startAt = _startAt;
    }

    function setFeePct(uint64 _feePct) public started onlyOwner {
        feePct = _feePct;
    }

    function setSale(address id) external started unused(id) isOwned(id) {
        tickets[id].sale = true;
        emit TicketSale(msg.sender, tickets[id].price);
    }

    function cancelTicketSale(address id) external started isOwned(id) {
        tickets[id].sale = false;
        emit TicketSaleCancelled(msg.sender);
    }

    function get(address id) external view returns (Ticket memory) {
        return tickets[id];
    }

    function getPrice(address id) public view returns (uint256) {
        return tickets[id].price;
    }

    function getFee(address id) public view returns (uint256) {
        return (tickets[id].price * feePct) / 100;
    }

    function isUsed(address id) public view returns (bool) {
        return tickets[id].used;
    }

    function isForSale(address id) public view returns (bool) {
        return tickets[id].sale;
    }

    function isOwner(address id) external view returns (bool) {
        uint256 tokenId = uint256(uint160(id));
        require(
            (ownerOf(tokenId) == msg.sender),
            "no ownership of the given ticket"
        );
        return true;
    }

    function buy() external payable started returns (address) {
        require((msg.value >= initPrice), "not enough payment");
        address id = msg.sender;
        if (msg.value > initPrice) {
            payable(id).transfer(msg.value - initPrice);
        }
        Ticket memory _ticket = Ticket({
            price: initPrice,
            sale: bool(false),
            used: bool(false)
        });
        tickets[id] = _ticket;
        ticketKeys.push(id);
        _mint(id, uint256(uint160(id)));
        emit TicketCreated(id);
        return id;
    }

    function approveBuy(
        address id,
        address _buyer
    ) public started isOwned(id) {
        uint256 tokenId = uint256(uint160(id));
        approve(_buyer, tokenId);
    }

    function buyFromReseller(address id) external payable started {
        uint256 tokenId = uint256(uint160(id));
        require(tickets[id].sale == true, "ticket not for sale");
        require(getApproved(tokenId) == msg.sender, "not approved");
        uint256 fee = getFee(id);
        uint256 priceToPay = tickets[id].price;
        uint256 _netPrice = priceToPay + fee;
        require((msg.value >= _netPrice), "not enough payment");
        if (msg.value > _netPrice) {
            payable(msg.sender).transfer(msg.value - _netPrice);
        }
        payFee(fee);
        address payable _seller = payable(address(uint160(ownerOf(tokenId))));
        _seller.transfer(priceToPay);
        emit TicketSold(_seller, msg.sender, priceToPay, fee);
        safeTransferFrom(_seller, msg.sender, tokenId);
        tickets[id].sale = false;
    }

    function payFee(uint256 fee) internal {
        payoutAddr.transfer(fee);
    }

    function payout() public onlyOwner {
        uint256 balance = uint256(address(this).balance);
        // uint256 fee = (balance * feePct) / 100;
        // winnerAddress.transfer(balance - fee);
        // payoutAddr.transfer(fee);
        emit Withdrawal(msg.sender, payoutAddr, balance);
    }

    function random() internal view returns (uint) {
        return
            uint(
                keccak256(
                    abi.encodePacked(block.difficulty, block.timestamp, ticketKeys)
                )
            );
    }

    function winner() public view returns (Ticket memory) {
        uint256 idx = random() % ticketKeys.length;
        return tickets[ticketKeys[idx]];
    }
}
