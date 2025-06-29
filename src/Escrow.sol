// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IEscrowInterface} from "./interfaces/IEscrowInterface.sol";
import {Escrow} from "./types/EscrowDetails.sol";

contract EscrowBuilder is IEscrowInterface {
    event EscrowDetails(
        address indexed seller,
        address indexed arbiter,
        address indexed buyer,
        uint256 id,
        string description
    );
    event FundSentToSeller(address indexed seller, uint256 amount);
    event AcceptedBuyersDetails(address indexed seller, uint256 id);
    event EscrowDisputed(address indexed disputer, uint256 id);
    event RefundRequested(address indexed buyer, uint256 id);
    event DisputeResolved(address indexed arbiter, uint256 id, uint256 amount);

    error WaitUntilYourDeadline();
    error YouAreNotOwner();
    error ContractPaused();
    error NotYetDeposited();
    error currentlyInDispute();
    error RefundHasBeenAsked();
    error EscrowNotCreated();
    error NotAuthorized();
    error NotEscrowBuyer();
    error AlreadyDeposited();
    error ZeroValue();
    error InsufficientFunds();
    error NotArbiter();
    error NotInDispute();

    uint256 public constant DEADLINE = 5 days;
    uint256 public EscrowId;

    address owner;

    bool public paused = false;

    mapping(uint256 id => Escrow.EscrowDetails) public escrow;
    mapping(uint256 => mapping(address => bool)) public buyerEscrowId;
    mapping(address => bool) public hasDeposited;
    mapping(uint256 => Escrow.EscrowState) public state;

    mapping(uint256 => Escrow.EscrowState) public stateOfEach;

    constructor(address _owner) {
        owner = _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert YouAreNotOwner();
        _;
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function resume() external onlyOwner {
        paused = false;
    }

    function createEscrow(
        address seller,
        address arbiter,
        uint256 amount,
        uint256 deadline,
        string memory description
    ) external returns (uint256 escrowId) {
        if (paused) revert ContractPaused();
        require(msg.sender != address(0));
        require(seller != address(0) && arbiter != address(0));
        require(amount > 0);

        escrowId = EscrowId++;

        escrow[escrowId] = Escrow.EscrowDetails({
            seller: seller,
            buyer: msg.sender,
            arbiter: arbiter,
            amount: amount,
            deadline: deadline,
            description: description
        });

        state[escrowId] = Escrow.EscrowState.Created;
        buyerEscrowId[escrowId][msg.sender] = true;

        emit EscrowDetails(seller, arbiter, msg.sender, escrowId, description);
        return escrowId;
    }

    function acceptBuyerEscrowDetails(uint256 escrowId) external {
        if (paused) revert ContractPaused();
        require(
            state[escrowId] == Escrow.EscrowState.Created,
            "Escrow Not Created Yet"
        );
        require(msg.sender == escrow[escrowId].seller);
        state[escrowId] = Escrow.EscrowState.Accepted;
        emit AcceptedBuyersDetails(msg.sender, escrowId);
    }

    function dispute(uint256 escrowId) external {
        if (paused) revert ContractPaused();
        if (state[escrowId] != Escrow.EscrowState.Created)
            revert EscrowNotCreated();
        if (
            !(msg.sender == escrow[escrowId].seller &&
                block.timestamp < escrow[escrowId].deadline) &&
            !(msg.sender == escrow[escrowId].buyer &&
                block.timestamp >= escrow[escrowId].deadline)
        ) revert NotAuthorized();
        state[escrowId] = Escrow.EscrowState.InDisput;
        emit EscrowDisputed(msg.sender, escrowId);
    }

    function fundEscrow(uint256 escrowId) external payable {
        if (paused) revert ContractPaused();
        if (!buyerEscrowId[escrowId][msg.sender]) revert NotEscrowBuyer();
        if (hasDeposited[msg.sender]) revert AlreadyDeposited();
        if (msg.value == 0) revert ZeroValue();
        if (msg.value < escrow[escrowId].amount) revert InsufficientFunds();
        hasDeposited[msg.sender] = true;
    }

    //seller is the one who will call this function
    function releaseFunds(uint256 escrowId) external {
        if (paused) revert ContractPaused();
        if (state[escrowId] == Escrow.EscrowState.InDisput)
            revert currentlyInDispute();
        if (state[escrowId] == Escrow.EscrowState.Refund)
            revert RefundHasBeenAsked();
        require(msg.sender == escrow[escrowId].seller);
        uint256 amountToSendToSeller = escrow[escrowId].amount;
        require(amountToSendToSeller > 0, "No funds to release");

        escrow[escrowId].amount = 0;
        payable(escrow[escrowId].seller).transfer(amountToSendToSeller);

        emit FundSentToSeller(escrow[escrowId].seller, amountToSendToSeller);
    }

    function requestRefund(uint256 escrowId) external {
        if (paused) revert ContractPaused();
        if (!hasDeposited[msg.sender]) revert NotYetDeposited();
        if (!buyerEscrowId[escrowId][msg.sender]) revert NotEscrowBuyer();
        if (block.timestamp < escrow[escrowId].deadline)
            revert WaitUntilYourDeadline();
        state[escrowId] = Escrow.EscrowState.Refund;
        emit RefundRequested(msg.sender, escrowId);
    }

function resolveDispute(uint256 escrowId, bool releaseFund) external {
    if (paused) revert ContractPaused();
    if (escrow[escrowId].arbiter != msg.sender) revert NotArbiter();
    if (state[escrowId] != Escrow.EscrowState.InDisput) revert NotInDispute();
    if (escrow[escrowId].amount == 0) revert InsufficientFunds();

    if (releaseFund) {
        uint256 amountToSend = escrow[escrowId].amount;
        escrow[escrowId].amount = 0;
        (bool success, ) = payable(escrow[escrowId].seller).call{value: amountToSend}("");
        require(success, "Transfer to seller failed");
    } else {
        uint256 amountToSend = escrow[escrowId].amount;
        escrow[escrowId].amount = 0;
        (bool success, ) = payable(escrow[escrowId].buyer).call{value: amountToSend}("");
        require(success, "Transfer to buyer failed");
    }
    state[escrowId] = Escrow.EscrowState.Resolved;
    emit DisputeResolved(msg.sender, escrowId, escrow[escrowId].amount);
}

    function getEscrowDetails(
        uint256 escrowId
    ) external view returns (Escrow.EscrowDetails memory) {
        return escrow[escrowId];
    }
}
