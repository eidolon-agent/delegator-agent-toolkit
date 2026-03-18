// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DelegatorAgent} from "../contracts/DelegatorAgent.sol";

contract DelegatorAgentTest is Test {
    DelegatorAgent agent;
    address human = address(0x1);
    address aiAgent = address(0x2);
    address target = address(0x3);
    address subAgent = address(0x4);

    function setUp() public {
        agent = new DelegatorAgent();
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        vm.deal(human, 10 ether);
        vm.deal(aiAgent, 2 ether);
        vm.deal(target, 0);
        vm.deal(subAgent, 1 ether);
    }

    function test_CreateDelegationAndExecute() public {
        address[] memory allowedTargets = new address[](1);
        allowedTargets[0] = target;
        bytes4[] memory allowedSelectors = new bytes4[](1);
        allowedSelectors[0] = bytes4(keccak256("transfer(address,uint256)") & bytes4(0xffffffff));

        // Human creates delegation to AI agent
        vm.startPrank(human);
        uint256 delegationId = agent.createDelegation(
            aiAgent,
            allowedTargets,
            allowedSelectors,
            1 ether,
            3600,
            keccak256("transfer 1 ETH to Alice")
        );
        vm.stopPrank();

        // Execute via delegate (aiAgent) - simulate a call with value
        vm.prank(aiAgent);
        vm.deal(address(this), 1 ether); // this contract gets ETH to forward
        bytes memory data = abi.encodeWithSelector(allowedSelectors[0], address(0x4), 1 ether);
        bytes memory result = agent.execute{value: 1 ether}(
            delegationId,
            target,
            data,
            1 ether
        );
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

    function test_SubDelegation_EnforcesValueCap() public {
        // Root delegation: any target, any selector, cap 1 ether
        vm.startPrank(human);
        uint256 rootId = agent.createDelegation(
            aiAgent,
            new address[](0), // any target
            new bytes4[](0),  // any selector
            1 ether,
            3600,
            keccak256("manage portfolio")
        );
        vm.stopPrank();

        // Sub-delegation with tighter cap (0.5 ether) should succeed
        vm.startPrank(aiAgent);
        uint256 subId = agent.createSubDelegation(
            rootId,
            subAgent,
            new address[](0),
            new bytes4[](0),
            0.5 ether,
            1800,
            keccak256("only small trades")
        );
        vm.stopPrank();

        // Verify parent-child relationship
        // Verify parent-child relationship
        (address dummyA, address dummyB, uint256 dummyC, uint256 dummyD, bytes32 dummyE, uint256 parentDelegationId, bool dummyF) = agent.getDelegation(subId);
        assertEq(parentDelegationId, rootId);

        // Sub-delegation with higher cap should revert
        vm.startPrank(aiAgent);
        vm.expectRevert("Value cap too high");
        agent.createSubDelegation(
            rootId,
            subAgent,
            new address[](0),
            new bytes4[](0),
            2 ether, // too high
            1800,
            keccak256("big trade")
        );
        vm.stopPrank();
    }

    function test_SubDelegation_EnforcesTargetSubset() public {
        // Root delegation restricts target to `target`
        address[] memory rootTargets = new address[](1);
        rootTargets[0] = target;
        vm.startPrank(human);
        uint256 rootId = agent.createDelegation(
            aiAgent,
            rootTargets,
            new bytes4[](0),
            1 ether,
            3600,
            keccak256("trade only on Uniswap")
        );
        vm.stopPrank();

        // Sub-delegation with subset (same target) should succeed
        vm.startPrank(aiAgent);
        uint256 subId = agent.createSubDelegation(
            rootId,
            subAgent,
            rootTargets,
            new bytes4[](0),
            0.5 ether,
            1800,
            keccak256("small trades on same target")
        );
        vm.stopPrank();

        // Sub-delegation with non-subset target should revert
        address other = address(0x5);
        address[] memory badTargets = new address[](1);
        badTargets[0] = other;
        vm.startPrank(aiAgent);
        vm.expectRevert("Sub target not in parent set");
        agent.createSubDelegation(
            rootId,
            subAgent,
            badTargets,
            new bytes4[](0),
            0.5 ether,
            1800,
            keccak256("bad target")
        );
        vm.stopPrank();
    }

    function test_SubDelegation_EnforcesSelectorSubset() public {
        bytes4 selA = bytes4(keccak256("swap(address,uint256)") & bytes4(0xffffffff));
        bytes4 selB = bytes4(keccak256("addLiquidity(address,uint256,uint256)") & bytes4(0xffffffff));
        bytes4[] memory rootSelectors = new bytes4[](2);
        rootSelectors[0] = selA;
        rootSelectors[1] = selB;

        vm.startPrank(human);
        uint256 rootId = agent.createDelegation(
            aiAgent,
            new address[](0),
            rootSelectors,
            1 ether,
            3600,
            keccak256("limited selectors")
        );
        vm.stopPrank();

        // Sub with subset (selA) should succeed
        bytes4[] memory subSelectors = new bytes4[](1);
        subSelectors[0] = selA;
        vm.startPrank(aiAgent);
        uint256 subId = agent.createSubDelegation(
            rootId,
            subAgent,
            new address[](0),
            subSelectors,
            0.5 ether,
            1800,
            keccak256("subset")
        );
        vm.stopPrank();

        // Sub with non-subset should revert
        bytes4 selC = bytes4(keccak256("removeLiquidity(address,uint256)") & bytes4(0xffffffff));
        bytes4[] memory badSelectors = new bytes4[](1);
        badSelectors[0] = selC;
        vm.startPrank(aiAgent);
        vm.expectRevert("Sub selector not in parent set");
        agent.createSubDelegation(
            rootId,
            subAgent,
            new address[](0),
            badSelectors,
            0.5 ether,
            1800,
            keccak256("bad selector")
        );
        vm.stopPrank();
    }

    function test_ExecuteFailsWhenValueExceedsCap() public {
        address[] memory allowedTargets = new address[](1);
        allowedTargets[0] = target;
        bytes4[] memory allowedSelectors = new bytes4[](1);
        allowedSelectors[0] = bytes4(keccak256("transfer(address,uint256)") & bytes4(0xffffffff));

        vm.startPrank(human);
        uint256 delegationId = agent.createDelegation(
            aiAgent,
            allowedTargets,
            allowedSelectors,
            0.1 ether,
            3600,
            keccak256("small tx")
        );
        vm.stopPrank();

        vm.prank(aiAgent);
        vm.expectRevert("Value exceeds cap");
        agent.execute{value: 1 ether}(
            delegationId,
            target,
            abi.encodeWithSelector(allowedSelectors[0], address(0x4), 1 ether),
            1 ether
        );
        vm.stopPrank();
    }

    function test_ExecuteFailsWhenExpired() public {
        vm.startPrank(human);
        uint256 delegationId = agent.createDelegation(
            aiAgent,
            new address[](0),
            new bytes4[](0),
            1 ether,
            1, // 1 second
            keccak256("test")
        );
        vm.stopPrank();

        vm.warp(block.timestamp + 2);
        vm.prank(aiAgent);
        vm.expectRevert("Delegation expired");
        agent.execute{value: 0}(
            delegationId,
            address(0),
            abi.encode(""),
            0
        );
        vm.stopPrank();
    }

    function test_ExecuteFailsWhenSelectorRestrictedButMissing() public {
        address[] memory allowedTargets = new address[](1);
        allowedTargets[0] = target;
        bytes4[] memory allowedSelectors = new bytes4[](1);
        allowedSelectors[0] = bytes4(keccak256("transfer(address,uint256)") & bytes4(0xffffffff));

        vm.startPrank(human);
        uint256 delegationId = agent.createDelegation(
            aiAgent,
            allowedTargets,
            allowedSelectors,
            1 ether,
            3600,
            keccak256("only transfer")
        );
        vm.stopPrank();

        vm.prank(aiAgent);
        // data length < 4 should revert
        vm.expectRevert("Selector required but missing");
        agent.execute{value: 0}(
            delegationId,
            target,
            abi.encode(""), // empty data
            0
        );
        vm.stopPrank();
    }

    function test_ExecuteFailsWhenTargetNotAllowed() public {
        // root allows only `target`
        address[] memory allowedTargets = new address[](1);
        allowedTargets[0] = target;

        vm.startPrank(human);
        uint256 delegationId = agent.createDelegation(
            aiAgent,
            allowedTargets,
            new bytes4[](0),
            1 ether,
            3600,
            keccak256("only target")
        );
        vm.stopPrank();

        vm.prank(aiAgent);
        vm.expectRevert("Target not allowed");
        agent.execute{value: 0}(
            delegationId,
            address(0x5), // not allowed
            abi.encode(""),
            0
        );
        vm.stopPrank();
    }

    function test_RevokeWorks() public {
        vm.startPrank(human);
        uint256 delegationId = agent.createDelegation(
            aiAgent,
            new address[](0),
            new bytes4[](0),
            1 ether,
            3600,
            keccak256("test")
        );
        vm.stopPrank();

        vm.startPrank(human);
        agent.revoke(delegationId);
        vm.stopPrank();

        (address dummyA, address dummyB, uint256 dummyC, uint256 dummyD, bytes32 dummyE, uint256 dummyF, bool revoked) = agent.getDelegation(delegationId);
        assertTrue(revoked);
    }
}
