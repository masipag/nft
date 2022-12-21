// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "hardhat/console.sol";

/**
 * @title NFT
 * @dev Create and manage tickets for an event using NFTs
 */
contract NFT is ERC721URIStorage, Pausable, Ownable {
    struct Ticket {
        uint256 price;
        bool sale;
        bool used;
    }
    Ticket[] tickets;

    uint64 public startDatetime;
    uint64 public totalSupply;
    uint256 public initialPrice;
    uint64 public maxPriceFactorPercentage;
    uint64 public transferFeePercentage;
    address payable withdrawalAddress;

    constructor(
        string memory _name,
        string memory _symbol,
        uint64 _startDatetime,
        uint64 _totalSupply,
        uint256 _initialPrice,
        uint64 _maxPriceFactorPercentage,
        uint64 _transferFeePercentage
    ) ERC721(_name, _symbol) {
        require(
            (_maxPriceFactorPercentage >= 100),
            "only percentages equal or greater than 100% are allowed"
        );
        withdrawalAddress = payable(msg.sender);
        startDatetime = uint64(_startDatetime);
        totalSupply = uint64(_totalSupply);
        initialPrice = uint256(_initialPrice);
        maxPriceFactorPercentage = uint64(_maxPriceFactorPercentage);
        transferFeePercentage = uint64(_transferFeePercentage);
    }

    event TicketCreated(address _by, uint256 _ticketId);
    event TicketDestroyed(address _by, uint256 _ticketId);
    event TicketSale(address _by, uint256 _ticketId, uint256 _price);
    event TicketSaleCancelled(address _by, uint256 _ticketId);
    event TicketSold(
        address _by,
        address _to,
        uint256 _ticketId,
        uint256 _price
    );
    event TicketPriceChanged(address _by, uint256 _ticketId, uint256 _price);
    event BalanceWithdrawn(address _by, address _to, uint256 _amount);

    /* MODIFIERS */

    modifier isBelowPriceCap(uint256 _price) {
        uint256 _maxPrice = initialPrice * (maxPriceFactorPercentage / 100);
        require(
            (_price <= _maxPrice),
            "price must be lower than the maximum price"
        );
        _;
    }

    modifier eventNotStarted() {
        require(
            (uint64(block.timestamp) < startDatetime),
            "event has already started"
        );
        _;
    }

    modifier supplyIsSufficient() {
        require(
            (tickets.length < totalSupply),
            "no more supply is available for creating new tickets"
        );
        _;
    }

    // check if the ticket has not been used yet
    modifier ticketNotUsed(uint256 _ticketId) {
        require(tickets[_ticketId].used != true, "ticket already used");
        _;
    }

    // check if the function caller is the ticket owner
    modifier callerIsTicketOwner(uint256 _ticketId) {
        require((ownerOf(_ticketId) == msg.sender), "no permission");
        _;
    }

    /* SETTERS */

    function setTicketToUsed(uint256 _ticketId) public onlyOwner {
        tickets[_ticketId].used = true;
    }

    function setTicketPrice(
        uint256 _ticketId,
        uint256 _price
    )
        public
        eventNotStarted
        ticketNotUsed(_ticketId)
        callerIsTicketOwner(_ticketId)
        isBelowPriceCap(_price)
    {
        tickets[_ticketId].price = _price;
        emit TicketPriceChanged(msg.sender, _ticketId, _price);
    }

    function setStartDatetime(
        uint64 _startDatetime
    ) public eventNotStarted onlyOwner {
        startDatetime = _startDatetime;
    }

    function setTotalSupply(
        uint64 _totalSupply
    ) public eventNotStarted onlyOwner {
        totalSupply = _totalSupply;
    }

    function setMaxPriceFactorPercentage(
        uint64 _maxPriceFactorPercentage
    ) public eventNotStarted onlyOwner {
        require(
            (_maxPriceFactorPercentage >= 100),
            "only percentages equal or greater than 100% are allowed"
        );
        maxPriceFactorPercentage = _maxPriceFactorPercentage;
    }

    function setTransferFeePercentage(
        uint64 _transferFeePercentage
    ) public eventNotStarted onlyOwner {
        transferFeePercentage = _transferFeePercentage;
    }

    function setWithdrawalAddress(address payable _addr) public onlyOwner {
        require((_addr != address(0)), "must be a valid address");
        withdrawalAddress = _addr;
    }

    // offer ticket for sale, pre-approve transfer
    function setTicketSale(
        uint256 _ticketId
    )
        external
        eventNotStarted
        whenNotPaused
        ticketNotUsed(_ticketId)
        callerIsTicketOwner(_ticketId)
    {
        tickets[_ticketId].sale = true;
        emit TicketSale(msg.sender, _ticketId, tickets[_ticketId].price);
    }

    function cancelTicketSale(
        uint256 _ticketId
    ) external eventNotStarted whenNotPaused callerIsTicketOwner(_ticketId) {
        tickets[_ticketId].sale = false;
        emit TicketSaleCancelled(msg.sender, _ticketId);
    }

    /* GETTERS */

    // Returns all the relevant information about a specific ticket
    function getTicket(
        uint256 _id
    ) external view returns (uint256 price, bool sale, bool used) {
        price = uint256(tickets[_id].price);
        sale = bool(tickets[_id].sale);
        used = bool(tickets[_id].used);
    }

    // Returns the price of a specific ticket
    function getTicketPrice(uint256 _ticketId) public view returns (uint256) {
        return tickets[_ticketId].price;
    }

    // Returns the maximum price allowed for a specific ticket
    function getTicketMaxPrice(
        uint256 _ticketId
    ) public view returns (uint256) {
        return tickets[_ticketId].price * (maxPriceFactorPercentage / 100);
    }

    // Returns the transfer fee of a specific ticket
    function getTicketCalculatedTransferFee(
        uint256 _ticketId
    ) public view returns (uint256) {
        return tickets[_ticketId].price * (transferFeePercentage / 100);
    }

    // Returns the status of a specific ticket
    function getTicketStatus(uint256 _ticketId) public view returns (bool) {
        return tickets[_ticketId].used;
    }

    // Returns the resale status of a specific ticket
    function getTicketResaleStatus(
        uint256 _ticketId
    ) public view returns (bool) {
        return tickets[_ticketId].sale;
    }

    // check ownership of ticket
    function checkTicketOwnership(
        uint256 _ticketId
    ) external view returns (bool) {
        require(
            (ownerOf(_ticketId) == msg.sender),
            "no ownership of the given ticket"
        );
        return true;
    }

    /* Additional functions */

    // create initial ticket struct and generate ID (only ever called by buyTicket function)
    function _createTicket()
        internal
        eventNotStarted
        supplyIsSufficient
        returns (uint256)
    {
        Ticket memory _ticket = Ticket({
            price: initialPrice,
            sale: bool(false),
            used: bool(false)
        });
        tickets.push(_ticket);
        uint256 newTicketId = tickets.length - 1;
        return newTicketId;
    }

    // mint a Ticket (primary market)
    function buyTicket()
        external
        payable
        eventNotStarted
        whenNotPaused
        returns (uint256)
    {
        require((msg.value >= initialPrice), "not enough money");
        if (msg.value > initialPrice) {
            payable(msg.sender).transfer(msg.value - initialPrice);
        }
        uint256 _ticketId = _createTicket();
        _mint(msg.sender, _ticketId);
        emit TicketCreated(msg.sender, _ticketId);
        return _ticketId;
    }

    // approve a specific buyer of the ticket to buy my ticket
    function approveAsBuyerOfTicket(
        uint256 _ticketId,
        address _buyer
    ) public eventNotStarted whenNotPaused callerIsTicketOwner(_ticketId) {
        approve(_buyer, _ticketId);
    }

    // buy request for a ticket available on secondary market (callable from any approved account/contract)
    function buyTicketFromAttendee(
        uint256 _ticketId
    ) external payable eventNotStarted whenNotPaused {
        require(tickets[_ticketId].sale = true, "ticket not for sale");
        require(getApproved(_ticketId) == msg.sender, "not approved");
        uint256 _priceToPay = tickets[_ticketId].price;
        address payable _seller = payable(address(uint160(ownerOf(_ticketId))));
        require((msg.value >= _priceToPay), "not enough money");
        // return overpaid amount to sender if necessary
        if (msg.value > _priceToPay) {
            payable(msg.sender).transfer(msg.value - _priceToPay);
        }
        // pay the seller (price - fee)
        uint256 _fee = _priceToPay * (transferFeePercentage / 100);
        uint256 _netPrice = _priceToPay - _fee;
        _seller.transfer(_netPrice);
        emit TicketSold(_seller, msg.sender, _ticketId, _priceToPay);
        safeTransferFrom(_seller, msg.sender, _ticketId);
        tickets[_ticketId].sale = false;
    }

    function destroyTicket(
        uint256 _ticketId
    ) public callerIsTicketOwner(_ticketId) {
        _burn(_ticketId);
        emit TicketDestroyed(msg.sender, _ticketId);
    }

    // withdraw money stored in this contract
    function withdrawBalance() public onlyOwner {
        uint256 _contractBalance = uint256(address(this).balance);
        withdrawalAddress.transfer(_contractBalance);
        emit BalanceWithdrawn(msg.sender, withdrawalAddress, _contractBalance);
    }
}
