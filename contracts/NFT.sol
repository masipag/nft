// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title NFT
 * @dev Create and manage tickets for an event using NFTs
 */
contract NFT is ERC721, Ownable {
    struct Ticket {
        uint256 price;
        bool sale;
        bool used;
    }
    Ticket[] tickets;

    uint64 public startDateTime;
    uint64 public totalSupply;
    uint256 public initialPrice;
    uint64 public maxPriceFactorPercentage;
    uint64 public transferFeePercentage;
    address payable withdrawalAddress;

    constructor(
        string memory _name,
        string memory _symbol,
        uint64 _startDateTime,
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
        startDateTime = uint64(_startDateTime);
        totalSupply = uint64(_totalSupply);
        initialPrice = uint256(_initialPrice);
        maxPriceFactorPercentage = uint64(_maxPriceFactorPercentage);
        transferFeePercentage = uint64(_transferFeePercentage);
    }

    event TicketCreated(address _by, uint256 _id);
    event TicketDestroyed(address _by, uint256 _id);
    event TicketSale(address _by, uint256 _id, uint256 _price);
    event TicketSaleCancelled(address _by, uint256 _id);
    event TicketSold(
        address _by,
        address _to,
        uint256 _id,
        uint256 _price
    );
    event TicketPriceChanged(address _by, uint256 _id, uint256 _price);
    event Withdrawal(address _by, address _to, uint256 _amount);

    /* MODIFIERS */

    modifier belowPriceCap(uint256 _price) {
        uint256 _maxPrice = initialPrice * (maxPriceFactorPercentage / 100);
        require(
            (_price <= _maxPrice),
            "price must be lower than the maximum price"
        );
        _;
    }

    modifier notStarted() {
        require(
            (uint64(block.timestamp) < startDateTime),
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
    modifier unused(uint256 _id) {
        require(tickets[_id].used != true, "ticket already used");
        _;
    }

    // check if the function caller is the ticket owner
    modifier isOwned(uint256 _id) {
        require((ownerOf(_id) == msg.sender), "no permission");
        _;
    }

    /* SETTERS */

    function use(uint256 _id) public onlyOwner {
        tickets[_id].used = true;
    }

    function setPrice(
        uint256 _id,
        uint256 _price
    )
        public
        notStarted
        unused(_id)
        isOwned(_id)
        belowPriceCap(_price)
    {
        tickets[_id].price = _price;
        emit TicketPriceChanged(msg.sender, _id, _price);
    }

    function setStartDateTime(
        uint64 _startDateTime
    ) public notStarted onlyOwner {
        startDateTime = _startDateTime;
    }

    function setTotalSupply(
        uint64 _totalSupply
    ) public notStarted onlyOwner {
        totalSupply = _totalSupply;
    }

    function setMaxPriceFactorPercentage(
        uint64 _maxPriceFactorPercentage
    ) public notStarted onlyOwner {
        require(
            (_maxPriceFactorPercentage >= 100),
            "only percentages equal or greater than 100% are allowed"
        );
        maxPriceFactorPercentage = _maxPriceFactorPercentage;
    }

    function setTransferFeePercentage(
        uint64 _transferFeePercentage
    ) public notStarted onlyOwner {
        transferFeePercentage = _transferFeePercentage;
    }

    function setWithdrawalAddress(address payable _address) public onlyOwner {
        require((_address != address(0)), "must be a valid address");
        withdrawalAddress = _address;
    }

    // offer ticket for sale, pre-approve transfer
    function setSale(
        uint256 _id
    )
        external
        notStarted
        unused(_id)
        isOwned(_id)
    {
        tickets[_id].sale = true;
        emit TicketSale(msg.sender, _id, tickets[_id].price);
    }

    function cancelTicketSale(
        uint256 _id
    ) external notStarted isOwned(_id) {
        tickets[_id].sale = false;
        emit TicketSaleCancelled(msg.sender, _id);
    }

    /* GETTERS */

    // Returns all the relevant information about a specific ticket
    function get(
        uint256 _id
    ) external view returns (uint256 price, bool sale, bool used) {
        price = uint256(tickets[_id].price);
        sale = bool(tickets[_id].sale);
        used = bool(tickets[_id].used);
    }

    // Returns the price of a specific ticket
    function getPrice(uint256 _id) public view returns (uint256) {
        return tickets[_id].price;
    }

    // Returns the maximum price allowed for a specific ticket
    function getMaxPrice(
        uint256 _id
    ) public view returns (uint256) {
        return tickets[_id].price * (maxPriceFactorPercentage / 100);
    }

    // Returns the transfer fee of a specific ticket
    function getCalculatedTransferFee(
        uint256 _id
    ) public view returns (uint256) {
        return tickets[_id].price * (transferFeePercentage / 100);
    }

    // Returns the status of a specific ticket
    function isUsed(uint256 _id) public view returns (bool) {
        return tickets[_id].used;
    }

    // Returns the resale status of a specific ticket
    function isForSale(
        uint256 _id
    ) public view returns (bool) {
        return tickets[_id].sale;
    }

    // check ownership of ticket
    function isOwner(
        uint256 _id
    ) external view returns (bool) {
        require(
            (ownerOf(_id) == msg.sender),
            "no ownership of the given ticket"
        );
        return true;
    }

    /* Additional functions */

    // create initial ticket struct and generate ID (only ever called by buy function)
    function create()
        internal
        notStarted
        supplyIsSufficient
        returns (uint256)
    {
        Ticket memory _ticket = Ticket({
            price: initialPrice,
            sale: bool(false),
            used: bool(false)
        });
        tickets.push(_ticket);
        uint256 _id = tickets.length - 1;
        return _id;
    }

    // mint a Ticket (primary market)
    function buy() external payable notStarted returns (uint256) {
        require((msg.value >= initialPrice), "not enough balance");
        if (msg.value > initialPrice) {
            payable(msg.sender).transfer(msg.value - initialPrice);
        }
        uint256 _id = create();
        _mint(msg.sender, _id);
        emit TicketCreated(msg.sender, _id);
        return _id;
    }

    // approve a specific buyer of the ticket to buy my ticket
    function approveBuy(
        uint256 _id,
        address _buyer
    ) public notStarted isOwned(_id) {
        approve(_buyer, _id);
    }

    // buy request for a ticket available on secondary market (callable from any approved account/contract)
    function buyFromUser(
        uint256 _id
    ) external payable notStarted {
        require(tickets[_id].sale == true, "ticket not for sale");
        require(getApproved(_id) == msg.sender, "not approved");
        uint256 _priceToPay = tickets[_id].price;
        address payable _seller = payable(address(uint160(ownerOf(_id))));
        require((msg.value >= _priceToPay), "not enough balance");
        // return overpaid amount to sender if necessary
        if (msg.value > _priceToPay) {
            payable(msg.sender).transfer(msg.value - _priceToPay);
        }
        // pay the seller (price - fee)
        uint256 _fee = _priceToPay * (transferFeePercentage / 100);
        uint256 _netPrice = _priceToPay - _fee;
        _seller.transfer(_netPrice);
        emit TicketSold(_seller, msg.sender, _id, _priceToPay);
        safeTransferFrom(_seller, msg.sender, _id);
        tickets[_id].sale = false;
    }

    function destroy(
        uint256 _id
    ) public isOwned(_id) {
        _burn(_id);
        emit TicketDestroyed(msg.sender, _id);
    }

    function withdraw() public onlyOwner {
        uint256 balance = uint256(address(this).balance);
        withdrawalAddress.transfer(balance);
        emit Withdrawal(msg.sender, withdrawalAddress, balance);
    }
}
