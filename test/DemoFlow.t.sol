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
        // 1. Human creates root delegation to AI agent (any target, any selector, 1 ETH cap)
        uint256 rootId = agent.createDelegation(
            aiAgent,
            new address[](0), // empty = any target
            new bytes4[](0),  // empty = any selector
            1 ether,
            86400,
            keccak256("manage portfolio on Base, max $100 per tx")
        );

        // 2. AI agent creates sub-delegation to sub-agent with tighter limits (0.5 ETH cap)
        vm.startPrank(aiAgent);
        uint256 subId = agent.createSubDelegation(
            rootId,
            subAgent,
            new address[](0),
            new bytes4[](0),
            0.5 ether,
            3600,
            keccak256("only small trades")
        );
        vm.stopPrank();

        // 3. Verify parent-child relationship
        (address d1, address d2, uint256 d3, uint256 d4, bytes32 d5, uint256 parentDelegationId, bool d6) = agent.getDelegation(subId);
        assertEq(parentDelegationId, rootId);

        // 4. Sub-agent executes a call within limits
        vm.startPrank(subAgent);
        vm.deal(address(this), 0.4 ether); // fund this test contract to forward
        bytes memory dummyData = abi.encodePacked(bytes4(keccak256("foo()")));
        vm.expectEmit(true, true, true, true);
        agent.execute{value: 0.4 ether}(
            subId,
            target,
            dummyData,
            0.4 ether
        );
        vm.stopPrank();

        // 5. Exceed sub-delegation cap -> should revert
        vm.startPrank(subAgent);
        vm.expectRevert("Value exceeds cap");
        agent.execute{value: 0.6 ether}(
            subId,
            target,
            dummyData,
            0.6 ether
        );
        vm.stopPrank();

        // 6. Human revokes root delegation
        vm.startPrank(human);
        agent.revoke(rootId);
        vm.stopPrank();
        (address da, address db, uint256 dc, uint256 dd, bytes32 de, uint256 df, bool revoked) = agent.getDelegation(rootId);
        assertTrue(revoked);
    }

    function test_SelectorRestrictedExecute_success() public {
        // Root: only allow selector "transfer(address,uint256)"
        bytes4 transferSel = bytes4(keccak256("transfer(address,uint256)") & bytes4(0xffffffff));
        address[] memory targets = new address[](0); // any target
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = transferSel;

        vm.startPrank(human);
        uint256 rootId = agent.createDelegation(
            aiAgent,
            targets,
            selectors,
            1 ether,
            3600,
            keccak256("only transfer")
        );
        vm.stopPrank();

        // AI executes a transfer call to a fake token (call will revert) but selector check passes
        vm.prank(aiAgent);
        vm.deal(address(this), 1 ether);
        address token = address(0x5);
        bytes memory data = abi.encodeWithSelector(transferSel, address(0x6), 100);
        vm.expectRevert(); // call fails because token doesn't exist
        agent.execute{value: 0}(
            rootId,
            token,
            data,
            0
        );
        vm.stopPrank();
    }

    function test_VerifyCall() public {
        // Create delegation with specific target and selector
        bytes4 sel = bytes4(keccak256("foo()") & bytes4(0xffffffff));
        address t = address(0x123);
        address[] memory targets = new address[](1);
        targets[0] = t;
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = sel;

        vm.startPrank(human);
        uint256 rootId = agent.createDelegation(
            aiAgent,
            targets,
            selectors,
            1 ether,
            3600,
            keccak256("test")
        );
        vm.stopPrank();

        // Verify valid call parameters
        assertTrue(agent.verifyCall(rootId, t, abi.encodePacked(sel), 0.1 ether));

        // Wrong target
        assertFalse(agent.verifyCall(rootId, address(0x456), abi.encodePacked(sel), 0.1 ether));

        // Wrong selector
        bytes4 badSel = bytes4(keccak256("bar()") & bytes4(0xffffffff));
        assertFalse(agent.verifyCall(rootId, t, abi.encodePacked(badSel), 0.1 ether));

        // Too much value
        assertFalse(agent.verifyCall(rootId, t, abi.encodePacked(sel), 2 ether));

        // Missing selector when selectors are restricted
        bytes memory emptyData = abi.encode("");
        assertFalse(agent.verifyCall(rootId, t, emptyData, 0.1 ether));
    }
}
