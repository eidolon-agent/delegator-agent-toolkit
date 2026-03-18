// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// No ERC165 needed for now; kept for potential future extension
// import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
// import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title DelegatorAgent
 * @dev Minimal prototype for intent-based delegations and sub-delegation chains.
 * Not production; for hackathon demo.
 *
 * Key concepts:
 * - A delegation grants an agent (delegate) permission to act on behalf of the delegator within constraints.
 * - Sub-delegations allow the delegate to further delegate with tighter limits.
 * - `execute` allows anyone (relayer) to perform an onchain call that satisfies the delegation constraints.
 * - `intentHash` captures the offchain intent (e.g., a signed message) that can be verified later via zk proofs (future).
 *
 * Security model:
 * - Delegations can be revoked by the original delegator at any time.
 * - Expiration enforced via `expiresAt`.
 * - Sub-delegations cannot exceed parent's value cap and (if parent restricts targets/selectors) must be subsets.
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
     *
     * Requirements:
     - `delegate` must not be the caller (no self-delegation).
     *
     * @param delegate Address of the agent to delegate to.
     * @param allowedTargets List of allowed target addresses. Empty array means any target is allowed.
     * @param allowedSelectors List of allowed function selectors (4-byte). Empty array means any selector is allowed.
     * @param maxValue Maximum ETH value that can be sent in a single call.
     * @param ttlSeconds Time-to-live from now; `expiresAt = block.timestamp + ttlSeconds`.
     * @param intentHash Hash of the offchain intent (e.g., IPFS CID or keccak256 of signed intent). Can be used for future zk proofs.
     * @return delegationId Unique ID of the created delegation.
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
     * Only the current delegate (parent) can call.
     *
     * Constraints enforcement:
     * - `maxValue` must be <= `parent.maxValue`
     * - If `parent.allowedTargets` is non-empty, then `allowedTargets` must be a subset.
     * - If `parent.allowedSelectors` is non-empty, then `allowedSelectors` must be a subset.
     *
     * @param parentDelegationId ID of the parent delegation.
     * @param subDelegate Address of the sub-agent.
     * @param allowedTargets Allowed targets for the sub-delegation.
     * @param allowedSelectors Allowed selectors for the sub-delegation.
     * @param maxValue Value cap for the sub-delegation.
     * @param ttlSeconds TTL for the sub-delegation.
     * @param intentHash Intent hash for the sub-delegation.
     * @return subDelegationId ID of the created sub-delegation.
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

        // Ensure sub-delegation constraints are tighter or equal:
        require(maxValue <= parent.maxValue, "Value cap too high");

        // If parent restricts targets, sub must be a subset.
        if (parent.allowedTargets.length > 0) {
            for (uint256 i = 0; i < allowedTargets.length; i++) {
                bool found = false;
                for (uint256 j = 0; j < parent.allowedTargets.length; j++) {
                    if (allowedTargets[i] == parent.allowedTargets[j]) {
                        found = true;
                        break;
                    }
                }
                require(found, "Sub target not in parent set");
            }
        }

        // If parent restricts selectors, sub must be a subset.
        if (parent.allowedSelectors.length > 0) {
            for (uint256 i = 0; i < allowedSelectors.length; i++) {
                bool found = false;
                for (uint256 j = 0; j < parent.allowedSelectors.length; j++) {
                    if (allowedSelectors[i] == parent.allowedSelectors[j]) {
                        found = true;
                        break;
                    }
                }
                require(found, "Sub selector not in parent set");
            }
        }

        subDelegationId = nextDelegationId++;
        Delegation storage sd = delegations[subDelegationId];
        sd.delegator = msg.sender;
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
     * Anyone can call as a relayer; the agent (delegate) is expected to be the caller or to have authorized this relayer.
     *
     * The function attached ETH value (`msg.value`) must equal the `value` argument.
     *
     * Requirements:
     * - Delegation exists, not revoked, not expired.
     * - `value` <= `maxValue`
     * - If `allowedTargets` is non-empty, `target` must be in the list.
     * - If `allowedSelectors` is non-empty, `data` must be at least 4 bytes and its selector must be in the list.
     *
     * @param delegationId The delegation to use.
     * @param target The contract address to call.
     * @param data Calldata to forward.
     * @param value Amount of ETH to send with the call.
     * @return result Return data from the call.
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

        // Determine selector (if any restriction)
        bytes4 selector;
        bool hasSelectorRestriction = d.allowedSelectors.length > 0;
        if (hasSelectorRestriction) {
            require(data.length >= 4, "Selector required but missing");
            assembly {
                selector := mload(add(data.offset, 0x20))
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

        // Execute call
        (bool success, bytes memory returndata) = target.call{value: msg.value}(data);

        // Emit event after execution with actual outcome
        emit CallExecuted(delegationId, target, selector, value, success);

        if (!success) {
            // Revert with return data if call failed
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
     * @notice Get delegation details (all fields except allowedTargets/Selectors).
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
     * @notice Get the list of child delegation IDs for a given delegation (for tree traversal).
     */
    function getChildren(uint256 delegationId) external view returns (uint256[] memory) {
        return children[delegationId];
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

        if (d.allowedSelectors.length > 0) {
            if (data.length < 4) return false;
            bytes4 selector;
            assembly {
                selector := mload(add(data.offset, 0x20))
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
    fallback() external payable { revert("Unknown call"); }
}
