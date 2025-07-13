// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {EscrowBuilder} from "../src/Escrow.sol";
import "../src/types/EscrowDetails.sol";

contract EscrowBuilderTest is Test {
    EscrowBuilder public escrow;
    address owner;
    address buyer;
    address seller;
    address arbiter;
    address buyer2;
    address seller2;
    address arbiter2;

    function setUp() public {
        escrow = new EscrowBuilder(owner);
        buyer = makeAddr("0x11111");
        seller = makeAddr("0x2222");
        arbiter = makeAddr("0x3333");
        arbiter2 = makeAddr("0x444");
        buyer2 = makeAddr("0x55555");
        seller2 = makeAddr("0x666");
        vm.deal(buyer, 10 ether);
        vm.deal(buyer2, 10 ether);
    }

    function test_pause() public {
        vm.startPrank(owner);
        bool pauseBefore = escrow.paused();
        escrow.pause();
        bool pauseAfter = escrow.paused();
        assertFalse(pauseBefore);
        assertTrue(pauseAfter);
    }

    function test_resume() public {
        vm.startPrank(owner);
        bool pauseBefore = escrow.paused();
        escrow.resume();
        bool pauseAfter = escrow.paused();
        assertFalse(pauseBefore);
        assertFalse(pauseAfter);
    }

    function test_createEscrowSuccess() public {
        vm.deal(buyer, 10 ether);
        vm.startPrank(buyer);
        escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "I am interested");
        uint256 escrowId = escrow.EscrowId();
        assertEq(escrowId, 1);
        vm.stopPrank();
    }

    function test_createEscrowMultiple() public {
        vm.deal(buyer, 10 ether);
        vm.startPrank(buyer);
        escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "I am interested");
        uint256 escrowId = escrow.EscrowId();
        assertEq(escrowId, 1);
        vm.stopPrank();

        vm.deal(buyer2, 10 ether);
        vm.startPrank(buyer2);
        escrow.createEscrow(seller2, arbiter2, 3 ether, block.timestamp, "New-port");
        uint256 escrowId2 = escrow.EscrowId();
        assertEq(escrowId2, 2);
        vm.stopPrank();
    }

    function test_CreateEscrowFailsWhenPaused() public {
        vm.startPrank(owner);
        escrow.pause();
        vm.stopPrank();

        vm.expectRevert();
        escrow.createEscrow(seller2, arbiter2, 3 ether, block.timestamp, "New-port");
    }

    function test_createEscrowFailsWhenCalledByZeroAddress() public {
        address ZERO_ADDRESS = address(0);
        vm.startPrank(ZERO_ADDRESS);
        vm.expectRevert();
        escrow.createEscrow(seller2, arbiter2, 3 ether, block.timestamp, "New-port");
    }

    function test_createEscrowCreated() public {
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller2, arbiter2, 3 ether, block.timestamp, "New-port");
        Escrow.EscrowState created = escrow.state(escrowId);
        assertEq(uint256(created), uint256(Escrow.EscrowState.Created));
    }

    function test_createEscrowBuyerIdIsSetTotrue() public {
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller2, arbiter2, 3 ether, block.timestamp, "New-port");
        bool id = escrow.buyerEscrowId(escrowId, buyer);
        assertTrue(id);
        vm.stopPrank();
    }

    function test_acceptBuyerEscrowDetailsSuccess() public {
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "I am interested");
        vm.stopPrank();

        vm.startPrank(seller);
        escrow.acceptBuyerEscrowDetails(escrowId);
        Escrow.EscrowState accepted = escrow.state(escrowId);
        assertEq(uint256(accepted), uint256(Escrow.EscrowState.Accepted));
        vm.stopPrank();
    }

    function test_acceptBuyerEscrowDetailsNotSellerAsCaller() public {
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "I am interested");
        vm.stopPrank();

        vm.startPrank(buyer);
        vm.expectRevert();
        escrow.acceptBuyerEscrowDetails(escrowId);
        vm.stopPrank();
    }

    function test_acceptBuyerEscrowDetailsNoEscrowCreated() public {
        vm.startPrank(seller);
        vm.expectRevert("Escrow Not Created Yet");
        escrow.acceptBuyerEscrowDetails(0);
        vm.stopPrank();
    }

    function test_acceptBuyerEscrowDetailsRevertIfContractIsPaused() public {
        vm.startPrank(owner);
        escrow.pause();
        vm.stopPrank();

        vm.startPrank(seller);
        vm.expectRevert();
        escrow.acceptBuyerEscrowDetails(0);
        vm.stopPrank();
    }

    function test_DisputeSuccessBySeller() public {
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "Test");
        vm.stopPrank();

        vm.startPrank(seller);
        escrow.dispute(escrowId);
        assertEq(uint256(escrow.state(escrowId)), uint256(Escrow.EscrowState.InDisput));
        vm.stopPrank();
    }

    function test_DisputeSuccessByBuyerAfterDeadline() public {
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp, "I am interested");
        vm.stopPrank();

        vm.warp(block.timestamp + 1);
        vm.startPrank(buyer);
        escrow.dispute(escrowId);
        Escrow.EscrowState disput = escrow.state(escrowId);
        assertEq(uint256(disput), uint256(Escrow.EscrowState.InDisput));
        vm.stopPrank();
    }

    function test_DisputeFailsNotAuthorized() public {
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "Test");
        vm.stopPrank();

        vm.startPrank(arbiter);
        vm.expectRevert();
        escrow.dispute(escrowId);
        vm.stopPrank();
    }

    function test_DisputeFailsNoEscrowCreated() public {
        vm.startPrank(seller);
        vm.expectRevert();
        escrow.dispute(1);
        vm.stopPrank();
    }

    function test_DisputeFailsWhenPaused() public {
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "Test");
        vm.stopPrank();

        vm.startPrank(owner);
        escrow.pause();
        vm.stopPrank();

        vm.startPrank(seller);
        vm.expectRevert();
        escrow.dispute(escrowId);
        vm.stopPrank();
    }

    function test_FundEscrowSuccess() public {
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "Test");
        vm.stopPrank();

        vm.startPrank(buyer);
        escrow.fundEscrow{value: 5 ether}(escrowId);
        assertTrue(escrow.hasDeposited(buyer));

        vm.stopPrank();
    }

    function test_FundEscrowFailsWhenPaused() public {
        // Create escrow
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "Test");
        vm.stopPrank();

        vm.startPrank(owner);
        escrow.pause();
        vm.stopPrank();

        vm.startPrank(buyer);
        vm.expectRevert();
        escrow.fundEscrow{value: 5 ether}(escrowId);
        vm.stopPrank();
    }

    function test_FundEscrowFailsNotEscrowBuyer() public {
        // Create escrow
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "Test");
        vm.stopPrank();

        vm.startPrank(buyer2);
        vm.expectRevert();
        escrow.fundEscrow{value: 5 ether}(escrowId);
        vm.stopPrank();
    }

    function test_FundEscrowFailsAlreadyDeposited() public {
        // Create escrow
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "Test");
        escrow.fundEscrow{value: 5 ether}(escrowId); // First deposit
        vm.stopPrank();

        // Try to fund again
        vm.startPrank(buyer);
        vm.expectRevert();
        escrow.fundEscrow{value: 5 ether}(escrowId);
        vm.stopPrank();
    }

    function test_FundEscrowFailsZeroValue() public {
        // Create escrow
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "Test");
        vm.stopPrank();

        // Try to fund with 0 Ether
        vm.startPrank(buyer);
        vm.expectRevert();
        escrow.fundEscrow{value: 0 ether}(escrowId);
        vm.stopPrank();
    }

    function test_FundEscrowFailsInsufficientFunds() public {
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "Test");
        vm.stopPrank();

        vm.startPrank(buyer);
        vm.expectRevert();
        escrow.fundEscrow{value: 4 ether}(escrowId);
        vm.stopPrank();
    }

    function test_FundEscrowFailsNonExistentEscrow() public {
        vm.startPrank(buyer);
        vm.expectRevert();
        escrow.fundEscrow{value: 5 ether}(1);
        vm.stopPrank();
    }

    function test_ReleaseFundsSuccess() public {
        // Create and fund escrow
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "Test");
        escrow.fundEscrow{value: 5 ether}(escrowId);
        vm.stopPrank();

        // Release funds as seller
        uint256 sellerBalanceBefore = seller.balance;
        vm.startPrank(seller);

        escrow.releaseFunds(escrowId);
        (,,, uint256 _amount,,) = escrow.escrow(escrowId);
        assertEq(_amount, 0);
        assertEq(seller.balance, sellerBalanceBefore + 5 ether);
        vm.stopPrank();
    }

    function test_ReleaseFundsFailsWhenPaused() public {
        // Create and fund escrow
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "Test");
        escrow.fundEscrow{value: 5 ether}(escrowId);
        vm.stopPrank();

        // Pause contract
        vm.startPrank(owner);
        escrow.pause();
        vm.stopPrank();

        // Try to release funds
        vm.startPrank(seller);
        vm.expectRevert();
        escrow.releaseFunds(escrowId);
        vm.stopPrank();
    }

    function test_ReleaseFundsFailsInDispute() public {
        // Create and fund escrow
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "Test");
        escrow.fundEscrow{value: 5 ether}(escrowId);
        vm.stopPrank();

        // Dispute escrow
        vm.startPrank(seller);
        escrow.dispute(escrowId);
        vm.stopPrank();

        // Try to release funds
        vm.startPrank(seller);
        vm.expectRevert();
        escrow.releaseFunds(escrowId);
        vm.stopPrank();
    }

    function test_ReleaseFundsFailsNotSeller() public {
        // Create and fund escrow
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "Test");
        escrow.fundEscrow{value: 5 ether}(escrowId);
        vm.stopPrank();

        // Try to release funds as buyer
        vm.startPrank(buyer);
        vm.expectRevert(); // Generic revert for msg.sender != seller
        escrow.releaseFunds(escrowId);
        vm.stopPrank();
    }

    function test_ReleaseFundsFailsNonExistentEscrow() public {
        // Try to release funds for non-existent escrow
        vm.startPrank(seller);
        vm.expectRevert(); // Reverts due to msg.sender != escrow[escrowId].seller (address(0))
        escrow.releaseFunds(1);
        vm.stopPrank();
    }

    function test_RequestRefundSuccess() public {
        // Create and fund escrow
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp, "Test");
        escrow.fundEscrow{value: 5 ether}(escrowId);
        vm.stopPrank();

        // Advance time to after deadline
        vm.warp(block.timestamp + 1);

        // Request refund
        vm.startPrank(buyer);
        escrow.requestRefund(escrowId);
        assertEq(uint256(escrow.state(escrowId)), uint256(Escrow.EscrowState.Refund));
        vm.stopPrank();
    }

    function test_RequestRefundFailsWhenPaused() public {
        // Create and fund escrow
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp, "Test");
        escrow.fundEscrow{value: 5 ether}(escrowId);
        vm.stopPrank();

        // Pause contract
        vm.startPrank(owner);
        escrow.pause();
        vm.stopPrank();

        // Try to request refund
        vm.startPrank(buyer);
        vm.expectRevert();
        escrow.requestRefund(escrowId);
        vm.stopPrank();
    }

    function test_RequestRefundFailsNotYetDeposited() public {
        // Create escrow but don’t fund
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp, "Test");
        vm.stopPrank();

        // Advance time to after deadline
        vm.warp(block.timestamp + 1);

        // Try to request refund
        vm.startPrank(buyer);
        vm.expectRevert();
        escrow.requestRefund(escrowId);
        vm.stopPrank();
    }

    function test_RequestRefundFailsNotEscrowBuyer() public {
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp, "Test");
        escrow.fundEscrow{value: 5 ether}(escrowId);
        vm.stopPrank();

        vm.warp(block.timestamp + 1);

        vm.startPrank(buyer2);
        vm.expectRevert();
        escrow.requestRefund(escrowId);
        vm.stopPrank();
    }

    function test_RequestRefundFailsBeforeDeadline() public {
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "Test");
        escrow.fundEscrow{value: 5 ether}(escrowId);
        vm.stopPrank();

        vm.startPrank(buyer);
        vm.expectRevert();
        escrow.requestRefund(escrowId);
        vm.stopPrank();
    }

    function test_RequestRefundFailsNonExistentEscrow() public {
        vm.startPrank(buyer);
        vm.expectRevert();
        escrow.requestRefund(1);
        vm.stopPrank();
    }

    function test_ResolveDisputeSuccessReleaseToSeller() public {
        // Create, fund, and dispute escrow
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "Test");
        escrow.fundEscrow{value: 5 ether}(escrowId);
        vm.stopPrank();
        vm.startPrank(seller);
        escrow.dispute(escrowId);
        vm.stopPrank();

        // Resolve dispute (release to seller)
        uint256 sellerBalanceBefore = seller.balance;
        vm.startPrank(arbiter);
        escrow.resolveDispute(escrowId, true);
        (,,, uint256 _amount,,) = escrow.escrow(escrowId);
        assertEq(uint256(escrow.state(escrowId)), uint256(Escrow.EscrowState.Resolved));
        assertEq(_amount, 0);
        assertEq(seller.balance, sellerBalanceBefore + 5 ether);
        vm.stopPrank();
    }

    function test_ResolveDisputeSuccessRefundToBuyer() public {
        // Create, fund, and dispute escrow
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "Test");
        escrow.fundEscrow{value: 5 ether}(escrowId);
        vm.stopPrank();
        vm.startPrank(seller);
        escrow.dispute(escrowId);
        vm.stopPrank();

        // Resolve dispute (refund to buyer)
        uint256 buyerBalanceBefore = buyer.balance;
        vm.startPrank(arbiter);
        escrow.resolveDispute(escrowId, false);
        (,,, uint256 _amount,,) = escrow.escrow(escrowId);
        assertEq(uint256(escrow.state(escrowId)), uint256(Escrow.EscrowState.Resolved));
        assertEq(_amount, 0);
        assertEq(buyer.balance, buyerBalanceBefore + 5 ether);
        vm.stopPrank();
    }

    function test_ResolveDisputeFailsWhenPaused() public {
        // Create, fund, and dispute escrow
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "Test");
        escrow.fundEscrow{value: 5 ether}(escrowId);
        vm.stopPrank();
        vm.startPrank(seller);
        escrow.dispute(escrowId);
        vm.stopPrank();

        // Pause contract
        vm.startPrank(owner);
        escrow.pause();
        vm.stopPrank();

        // Try to resolve dispute
        vm.startPrank(arbiter);
        vm.expectRevert();
        escrow.resolveDispute(escrowId, true);
        vm.stopPrank();
    }

    function test_ResolveDisputeFailsNotArbiter() public {
        // Create, fund, and dispute escrow
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "Test");
        escrow.fundEscrow{value: 5 ether}(escrowId);
        vm.stopPrank();
        vm.startPrank(seller);
        escrow.dispute(escrowId);
        vm.stopPrank();

        // Try to resolve as non-arbiter
        vm.startPrank(buyer);
        vm.expectRevert();
        escrow.resolveDispute(escrowId, true);
        vm.stopPrank();
    }

    function test_ResolveDisputeFailsNotInDispute() public {
        // Create and fund escrow (not disputed)
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "Test");
        escrow.fundEscrow{value: 5 ether}(escrowId);
        vm.stopPrank();

        // Try to resolve
        vm.startPrank(arbiter);
        vm.expectRevert();
        escrow.resolveDispute(escrowId, true);
        vm.stopPrank();
    }

    function test_ResolveDisputeFailsNonExistentEscrow() public {
        // Try to resolve non-existent escrow
        vm.startPrank(arbiter);
        vm.expectRevert(); // Reverts due to escrow[1].arbiter == address(0)
        escrow.resolveDispute(1, true);
        vm.stopPrank();
    }

    function test_GetEscrowDetailsSuccess() public {
        // Create escrow
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "Test Escrow");
        vm.stopPrank();

        // Get escrow details
        Escrow.EscrowDetails memory details = escrow.getEscrowDetails(escrowId);

        // Verify details
        assertEq(details.seller, seller);
        assertEq(details.buyer, buyer);
        assertEq(details.arbiter, arbiter);
        assertEq(details.amount, 5 ether);
        assertEq(details.deadline, block.timestamp + 2 days);
        assertEq(details.description, "Test Escrow");
    }

    function test_GetEscrowDetailsNonExistentEscrow() public {
        // Get details for non-existent escrow
        Escrow.EscrowDetails memory details = escrow.getEscrowDetails(1);

        // Verify default values
        assertEq(details.seller, address(0));
        assertEq(details.buyer, address(0));
        assertEq(details.arbiter, address(0));
        assertEq(details.amount, 0);
        assertEq(details.deadline, 0);
        assertEq(details.description, "");
    }

    function test_GetEscrowDetailsAfterFundsReleased() public {
        // Create and fund escrow
        vm.startPrank(buyer);
        uint256 escrowId = escrow.createEscrow(seller, arbiter, 5 ether, block.timestamp + 2 days, "Test Escrow");
        escrow.fundEscrow{value: 5 ether}(escrowId);
        vm.stopPrank();

        // Release funds
        vm.startPrank(seller);
        escrow.releaseFunds(escrowId);
        vm.stopPrank();

        // Get escrow details
        Escrow.EscrowDetails memory details = escrow.getEscrowDetails(escrowId);

        // Verify details (amount should be 0 after release)
        assertEq(details.seller, seller);
        assertEq(details.buyer, buyer);
        assertEq(details.arbiter, arbiter);
        assertEq(details.amount, 0);
        assertEq(details.deadline, block.timestamp + 2 days);
        assertEq(details.description, "Test Escrow");
    }
}
