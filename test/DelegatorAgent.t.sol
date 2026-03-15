// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DelegatorAgent} from "../contracts/DelegatorAgent.sol";

contract DelegatorAgentTest is Test {
    DelegatorAgent agent;
    address human = address(0x1);
    address aiAgent = address(0x2);
    address target = address(0x3);

    function setUp() public {
        agent = new DelegatorAgent();
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        vm.deal(human, 10 ether);
        vm.deal(aiAgent, 2 ether);
        vm.deal(target, 0);
    }

    function test_CreateDelegationAndExecute() public {
        address[] memory allowedTargets = new address[](1);
        allowedTargets[0] = target;
        bytes4[] memory allowedSelectors = new bytes4[](1);
        allowedSelectors[0] = bytes4(keccak256("transfer(address,uint256)") & bytes4(0xffffffff));

        uint256 delegationId = agent.createDelegation(
            aiAgent,
            allowedTargets,
            allowedSelectors,
            1 ether,
            3600,
            keccak256("transfer 1 ETH to Alice")
        );

        // Execute via delegate (aiAgent)
        vm.prank(aiAgent);
        vm.deal(address(this), 1 ether);
        agent.execute{value: 1 ether}(
            delegationId,
            target,
            abi.encodeWithSelector(allowedSelectors[0], address(0x4), 1 ether)
        );
        // Expect revert if target reverts (it will, since target is not a contract). But it's okay for test.
        vm.stopPrank;

        // Check delegation fields
        (address delegator, address delegate, uint256 maxValue, uint256 expiresAt, bytes32 intentHash, uint256 parentId, bool revoked) = agent.getDelegation(delegationId);
        assertEq(delegator, human);
        assertEq(delegate, aiAgent);
        assertEq(maxValue, 1 ether);
        assertEq(intentHash, keccak256("transfer 1 ETH to Alice"));
        assertEq(parentId, 0);
        assertEq(revoked, false);
    }

    function test_SubDelegation() public {
        // Root
        uint256 rootId = agent.createDelegation(
            aiAgent,
            new address[](1), // empty allowedTargets means any if none specified (we'll allow)
            new bytes4[](0),
            1 ether,
            3600,
            keccak256("manage portfolio")
        );

        // Sub-delegation: tighter cap
        address subAgent = address(0x4);
        uint256 subId = agent.createSubDelegation(
            rootId,
            subAgent,
            new address[](1),
            new bytes4[](0),
            0.5 ether,
            1800,
            keccak256("only small trades")
        );

        // Verify hierarchy
        (uint256 parent,,) = agent.getDelegation(subId);
        assertEq(parent, rootId);
    }

    function test_Revoke() public {
        uint256 delegationId = agent.createDelegation(
            aiAgent,
            new address[](0),
            new bytes4[](0),
            1 ether,
            3600,
            keccak256("test")
        );

        vm.prank(human);
        agent.revoke(delegationId);
        assertTrue(agent.getDelegation(delegationId).revoked);
    }

    function test_ExecuteFailsWhenValueExceedsCap() public {
        uint256 delegationId = agent.createDelegation(
            aiAgent,
            new address[](0),
            new bytes4[](0),
            0.1 ether,
            3600,
            keccak256("small tx")
        );

        vm.prank(aiAgent);
        vm.expectRevert("Value exceeds cap");
        agent.execute{value: 1 ether}(delegationId, address(0), abi.encode(""), 1 ether);
    }

    function test_ExecuteFailsWhenExpired() public {
        uint256 delegationId = agent.createDelegation(
            aiAgent,
            new address[](0),
            new bytes4[](0),
            1 ether,
            1, // 1 second
            keccak256("test")
        );

        vm.warp(block.timestamp + 2);
        vm.prank(aiAgent);
        vm.expectRevert("Delegation expired");
        agent.execute{value: 0}(delegationId, address(0), abi.encode(""), 0);
    }
}
