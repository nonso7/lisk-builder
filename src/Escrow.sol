// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IEscrowInterface} from "./interfaces/IEscrowInterface.sol";
import {Escrow} from "./types/EscrowDetails.sol";

contract EscrowBuilder is IEscrowInterface {

    event EscrowDetails(address indexed seller, address indexed arbiter, address indexed buyer, uint256 id, string description);
    event FundSentToSeller(address indexed seller, uint256 amount);
    event AcceptedBuyersDetails(address indexed seller, uint256 id);

    error WaitUntilYourDeadline();
    error YouAreNotOwner();
    error ContractPaused();
    error NotYetDeposited();
    error currentlyInDispute();
    error RefundHasBeenAsked();

    uint256 public constant DEADLINE = 5 days;
    uint256 public EscrowId;

    address owner;

    bool public paused = false;
    
    mapping(uint256 id => Escrow.EscrowDetails) public escrow;
    mapping(uint256 => mapping(address => bool) ) public buyerEscrowId;
    mapping(address => bool) public hasDeposited;
    mapping(uint256 => Escrow.EscrowState) public state;
    

    
    mapping(uint256 => Escrow.EscrowState) public stateOfEach;

    constructor(address _owner){
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

    function createEscrow(address seller, address arbiter, uint256 amount, uint256 deadline, string memory description) external returns (uint256 escrowId) {
        if(paused) revert ContractPaused();
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

        state[escrowId]= Escrow.EscrowState.Created;
        buyerEscrowId[escrowId][msg.sender] = true;

        emit EscrowDetails(seller, arbiter, msg.sender, escrowId, description);      
        return escrowId;
    
    }
    
    function acceptBuyerEscrowDetails(uint256 escrowId) external {
        if(paused) revert ContractPaused();
        require(state[escrowId] == Escrow.EscrowState.Created, "Escrow Not Created Yet");
        require(msg.sender == escrow[escrowId].seller);
        state[escrowId] = Escrow.EscrowState.Accepted;
        emit AcceptedBuyersDetails(msg.sender, escrowId);
    }

    function dispute(uint256 escrowId) external {
        if(paused) revert ContractPaused();
        require(msg.sender == escrow[escrowId].seller);
        if(block.timestamp >= escrow[escrowId].deadline) {
            require(msg.sender == escrow[escrowId].buyer);
        }
        state[escrowId] = Escrow.EscrowState.InDisput;
    }

// Escrow Creation: Buyers should be able to initiate an escrow agreement with the seller.
// Fund Escrow: Enable buyers to deposit the agreed-upon amount into the escrow contract.
// Release Funds: Allow sellers to release the funds once the transaction conditions are met.
// Request Refund: Allow buyers to request refunds under specific and unjustified conditions (e.g., time-out or unfulfilled terms).
// Dispute Resolution: In case there’s disagreement between the buyer and the seller, allow the arbiter to make the final decision by either releasing the funds or refunding them to the buyer.
    function fundEscrow(uint256 escrowId) external payable {
        if(paused) revert ContractPaused();
        require(buyerEscrowId[escrowId][msg.sender] == false);
        require(hasDeposited[msg.sender] == false);
        require(msg.value > 0);
        require(msg.value >= escrow[escrowId].amount);
        hasDeposited[msg.sender] = true;
        
    }

    //seller is the one who will call this function
    function releaseFunds(uint256 escrowId) external {
        if(paused) revert ContractPaused();
        if (state[escrowId] == Escrow.EscrowState.InDisput) revert currentlyInDispute();
        if(state[escrowId] == Escrow.EscrowState.Refund) revert RefundHasBeenAsked();
        require(msg.sender == escrow[escrowId].seller);
        uint256 amountToSendToSeller = escrow[escrowId].amount;
        require(amountToSendToSeller > 0, "No funds to release");
        
        escrow[escrowId].amount = 0;
        payable(escrow[escrowId].seller).transfer(amountToSendToSeller);
        
        emit FundSentToSeller(escrow[escrowId].seller, amountToSendToSeller);
    }


    function requestRefund(uint256 escrowId) external {
        if(paused) revert ContractPaused();
        if(hasDeposited[msg.sender]) revert NotYetDeposited();
        require(buyerEscrowId[escrowId][msg.sender] == true);
        if(block.timestamp >= escrow[escrowId].deadline) {
           state[escrowId] = Escrow.EscrowState.Refund;

        }else {
            revert WaitUntilYourDeadline();
        }    
    }


    function resolveDispute(uint256 escrowId, bool releaseFund) external{
        require (escrow[escrowId].arbiter == msg.sender);
        require(state[escrowId] == Escrow.EscrowState.InDisput, "They can sort themselves");
        if(releaseFund) {
           payable(escrow[escrowId].seller).transfer(escrow[escrowId].amount);
        } else if(state[escrowId] == Escrow.EscrowState.Refund){
            uint256 amountToSendToBuyer = escrow[escrowId].amount;
            escrow[escrowId].amount -= amountToSendToBuyer;
            payable(escrow[escrowId].buyer).transfer(amountToSendToBuyer);
        }
        state[escrowId] == Escrow.EscrowState.Resolved;

    }

    function getEscrowDetails(uint256 escrowId) external view returns (Escrow.EscrowDetails memory){
        return escrow[escrowId];
    }
    
}


