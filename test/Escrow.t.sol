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
    
    function test_disputSuccess() public {

    }

}
