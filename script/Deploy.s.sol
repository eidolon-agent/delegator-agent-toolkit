// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DelegatorAgent} from "../contracts/DelegatorAgent.sol";
import {Console} from "forge-std/console.sol";

contract DeployDelegatorAgent is Script {
    DelegatorAgent public agent;

    function setUp() public {}

    function run() public returns (DelegatorAgent) {
        // Use Base Sepolia testnet RPC
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        agent = new DelegatorAgent();
        vm.stopBroadcast();

        Console.log("DelegatorAgent deployed to:", address(agent));
        Console.log("Deployer:", vm.envString("PRIVATE_KEY"));
        return agent;
    }
}
