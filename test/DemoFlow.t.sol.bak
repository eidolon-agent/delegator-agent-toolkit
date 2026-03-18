// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DelegatorAgent} from "../contracts/DelegatorAgent.sol";

contract DemoFlow is Test {
    DelegatorAgent agent;
    address human = address(0x1);
    address aiAgent = address(0x2);
    address subAgent = address(0x3);
    address target = address(0x4); // some contract

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        vm.deal(human, 10 ether);
        vm.deal(aiAgent, 2 ether);
        vm.deal(subAgent, 1 ether);
        agent = new DelegatorAgent();
        vm.startPrank(human);
    }

    function tearDown() public {
        vm.stopPrank();
    }

    function test_FullDelegationFlow() public {
        // 1. Human creates root delegation to AI agent
        uint256 rootId = agent.createDelegation(
            aiAgent,
            new address[](1), // empty means any target allowed? Actually empty means no target restrictions; we'll allow any
            new bytes4[](0), // any selector
            1 ether,
            86400,
            keccak256("manage portfolio on Base, max $100 per tx")
        );
        emit log("Root delegation created", rootId);

        // 2. AI agent creates sub-delegation to sub-agent with tighter limits
        vm.startPrank(aiAgent);
        uint256 subId = agent.createSubDelegation(
            rootId,
            subAgent,
            new address[](1),
            new bytes4[](0),
            0.5 ether,
            3600,
            keccak256("only small trades")
        );
        vm.stopPrank();
        emit log("Sub-delegation created", subId);

        // 3. Verify constraints: sub-delegation value must be <= parent
        // Already enforced by contract

        // 4. Sub-agent attempts to execute a call within limits
        vm.startPrank(subAgent);
        // Simulate a call to target with 0.4 ether
        bytes memory dummyData = abi.encodePacked(bytes4(keccak256("foo()")));
        vm.expectEmit(true, true, true, true);
        emit CallExecuted(subId, target, bytes4(keccak256("foo()")), 0.4 ether, true);
        agent.execute{value: 0.4 ether}(
            subId,
            target,
            dummyData
        );
        vm.stopPrank();

        // 5. Try to exceed sub-delegation cap -> should revert
        vm.startPrank(subAgent);
        vm.expectRevert("Value exceeds cap");
        agent.execute{value: 0.6 ether}(subId, target, dummyData);
        vm.stopPrank();

        // 6. Human revokes root delegation
        vm.startPrank(human);
        agent.revoke(rootId);
        vm.stopPrank();
        assertTrue(agent.getDelegation(rootId).revoked);
    }
}
