// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Escrow} from "../types/EscrowDetails.sol";

interface IEscrowInterface {
    function createEscrow(address seller, address arbiter, uint256 amount, uint256 deadline, string memory description)
        external
        returns (uint256 escrowId);

    function fundEscrow(uint256 escrowId) external payable;

    function releaseFunds(uint256 escrowId) external;

    function requestRefund(uint256 escrowId) external;

    function resolveDispute(uint256 escrowId, bool releaseFund) external;

    function getEscrowDetails(uint256 escrowId) external view returns (Escrow.EscrowDetails memory);
}
