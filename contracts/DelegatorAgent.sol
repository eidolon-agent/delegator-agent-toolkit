// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title DelegatorAgent
 * @dev Minimal prototype for intent-based delegations and sub-delegation chains.
 * Not production; for hackathon demo.
 */
contract DelegatorAgent {
    struct Delegation {
        address delegator;
        address delegate;
        address[] allowedTargets;
        bytes4[] allowedSelectors;
        uint256 maxValue;
        uint256 expiresAt;
        bytes32 intentHash;
        uint256 parentDelegationId; // 0 if root
        bool revoked;
    }

    // delegationId => Delegation
    mapping(uint256 => Delegation) public delegations;
    uint256 public nextDelegationId = 1;

    // Track sub-delegations for UI tree
    mapping(uint256 => uint256[]) public children;

    // Events
    event DelegationCreated(
        uint256 indexed delegationId,
        address indexed delegator,
        address indexed delegate,
        bytes32 intentHash,
        uint256 parentDelegationId
    );
    event DelegationRevoked(uint256 indexed delegationId, address indexed revoker);
    event CallExecuted(
        uint256 indexed delegationId,
        address indexed target,
        bytes4 selector,
        uint256 value,
        bool success
    );

    /**
     * @notice Create a new root delegation (human -> agent).
     */
    function createDelegation(
        address delegate,
        address[] calldata allowedTargets,
        bytes4[] calldata allowedSelectors,
        uint256 maxValue,
        uint256 ttlSeconds,
        bytes32 intentHash
    ) external returns (uint256 delegationId) {
        require(delegate != msg.sender, "Delegate self not allowed");
        delegationId = nextDelegationId++;
        Delegation storage d = delegations[delegationId];
        d.delegator = msg.sender;
        d.delegate = delegate;
        d.allowedTargets = allowedTargets;
        d.allowedSelectors = allowedSelectors;
        d.maxValue = maxValue;
        d.expiresAt = block.timestamp + ttlSeconds;
        d.intentHash = intentHash;
        d.parentDelegationId = 0;
        children[0].push(delegationId);

        emit DelegationCreated(delegationId, msg.sender, delegate, intentHash, 0);
    }

    /**
     * @notice Create a sub-delegation (agent -> sub-agent) with tighter limits.
     * Only the current delegate can call.
     */
    function createSubDelegation(
        uint256 parentDelegationId,
        address subDelegate,
        address[] calldata allowedTargets,
        bytes4[] calldata allowedSelectors,
        uint256 maxValue,
        uint256 ttlSeconds,
        bytes32 intentHash
    ) external returns (uint256 subDelegationId) {
        Delegation storage parent = delegations[parentDelegationId];
        require(parent.delegate == msg.sender, "Not delegate");
        require(!parent.revoked, "Parent revoked");
        require(block.timestamp < parent.expiresAt, "Parent expired");

        // Ensure sub-delegation constraints are tighter:
        require(maxValue <= parent.maxValue, "Value cap too high");
        // Also could check that allowedTargets is subset of parent.allowedTargets, but skip for brevity.

        subDelegationId = nextDelegationId++;
        Delegation storage sd = delegations[subDelegationId];
        sd.delegator = msg.sender; // the current delegate becomes the delegator for the sub-delegation
        sd.delegate = subDelegate;
        sd.allowedTargets = allowedTargets;
        sd.allowedSelectors = allowedSelectors;
        sd.maxValue = maxValue;
        sd.expiresAt = block.timestamp + ttlSeconds;
        sd.intentHash = intentHash;
        sd.parentDelegationId = parentDelegationId;

        children[parentDelegationId].push(subDelegationId);

        emit DelegationCreated(subDelegationId, msg.sender, subDelegate, intentHash, parentDelegationId);
    }

    /**
     * @notice Execute a call following a delegation's constraints.
     * Anyone can call as a relayer; agent could bemsg.sender.
     */
    function execute(
        uint256 delegationId,
        address target,
        bytes calldata data,
        uint256 value
    ) external payable returns (bytes memory result) {
        require(msg.value == value, "ETH value mismatch");
        Delegation storage d = delegations[delegationId];
        require(d.delegate != address(0), "Invalid delegation");
        require(!d.revoked, "Delegation revoked");
        require(block.timestamp < d.expiresAt, "Delegation expired");
        require(value <= d.maxValue, "Value exceeds cap");

        // Check target allowed
        if (d.allowedTargets.length > 0) {
            bool targetAllowed;
            for (uint256 i = 0; i < d.allowedTargets.length; i++) {
                if (d.allowedTargets[i] == target) {
                    targetAllowed = true;
                    break;
                }
            }
            require(targetAllowed, "Target not allowed");
        }

        // Check selector (if any restrictions)
        if (d.allowedSelectors.length > 0 && data.length >= 4) {
            bytes4 selector;
            assembly {
                selector := mload(add(data, 0x20))
            }
            bool selectorAllowed;
            for (uint256 i = 0; i < d.allowedSelectors.length; i++) {
                if (d.allowedSelectors[i] == selector) {
                    selectorAllowed = true;
                    break;
                }
            }
            require(selectorAllowed, "Selector not allowed");
        }

        // Capture selector for event
        bytes4 emittedSelector;
        if (data.length >= 4) {
            assembly {
                emittedSelector := mload(add(data, 0x20))
            }
        }

        // Execute call
        (bool success, bytes memory returndata) = target.call{value: msg.value}(data);
        emit CallExecuted(delegationId, target, emittedSelector, value, success);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("Call failed");
            }
        }
        return returndata;
    }

    /**
     * @notice Revoke a delegation (delegator only).
     */
    function revoke(uint256 delegationId) external {
        Delegation storage d = delegations[delegationId];
        require(d.delegator == msg.sender, "Not delegator");
        require(!d.revoked, "Already revoked");
        d.revoked = true;
        emit DelegationRevoked(delegationId, msg.sender);
    }

    /**
     * @notice Get delegation details.
     */
    function getDelegation(uint256 delegationId) external view returns (
        address delegator,
        address delegate,
        uint256 maxValue,
        uint256 expiresAt,
        bytes32 intentHash,
        uint256 parentDelegationId,
        bool revoked
    ) {
        Delegation storage d = delegations[delegationId];
        return (
            d.delegator,
            d.delegate,
            d.maxValue,
            d.expiresAt,
            d.intentHash,
            d.parentDelegationId,
            d.revoked
        );
    }

    /**
     * @notice Get allowed targets/selectors for a delegation (helper for offchain).
     */
    function getDelegationDetails(uint256 delegationId) external view returns (
        address[] memory allowedTargets,
        bytes4[] memory allowedSelectors
    ) {
        Delegation storage d = delegations[delegationId];
        return (d.allowedTargets, d.allowedSelectors);
    }

    /**
     * @notice Verify that a call would pass constraints without executing.
     */
    function verifyCall(
        uint256 delegationId,
        address target,
        bytes calldata data,
        uint256 value
    ) external view returns (bool) {
        Delegation storage d = delegations[delegationId];
        if (d.delegate == address(0)) return false;
        if (d.revoked) return false;
        if (block.timestamp >= d.expiresAt) return false;
        if (value > d.maxValue) return false;

        if (d.allowedTargets.length > 0) {
            bool targetAllowed;
            for (uint256 i = 0; i < d.allowedTargets.length; i++) {
                if (d.allowedTargets[i] == target) {
                    targetAllowed = true;
                    break;
                }
            }
            if (!targetAllowed) return false;
        }

        if (d.allowedSelectors.length > 0 && data.length >= 4) {
            bytes4 selector;
            assembly {
                selector := mload(add(data, 0x20))
            }
            bool selectorAllowed;
            for (uint256 i = 0; i < d.allowedSelectors.length; i++) {
                if (d.allowedSelectors[i] == selector) {
                    selectorAllowed = true;
                    break;
                }
            }
            if (!selectorAllowed) return false;
        }

        return true;
    }

    // Fallback to receive ETH
    receive() external payable {}
}
