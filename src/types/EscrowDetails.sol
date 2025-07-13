// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

library Escrow {
    struct EscrowDetails {
        address seller;
        address buyer;
        address arbiter;
        uint256 amount;
        uint256 deadline;
        string description;
    }

    enum EscrowState {
        Accepted,
        InDisput,
        Created,
        Refund,
        Resolved
    }
}
