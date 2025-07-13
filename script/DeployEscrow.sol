// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {EscrowBuilder} from "../src/Escrow.sol";

contract DeployEscrow is Script {
    function run() external returns (EscrowBuilder) {
        vm.startBroadcast();

        address owner = 0x6D2Dd04bF065c8A6ee9CeC97588AbB0f967E0df9;
        EscrowBuilder escrow = new EscrowBuilder(owner);

        vm.stopBroadcast();
        return escrow;
    }
}
