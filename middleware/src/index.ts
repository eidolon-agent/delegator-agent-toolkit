import { createPublicClient, http, parseAbi, PublicClient } from 'viem';
import { base } from 'wagmi/chains';

const DELEGATOR_ABI = parseAbi([
  'function verifyCall(uint256 delegationId, address target, bytes data, uint256 value) view returns (bool)',
  'function getDelegation(uint256 delegationId) view returns (address delegator, address delegate, uint256 maxValue, uint256 expiresAt, bytes32 intentHash, uint256 parentDelegationId, bool revoked)',
  'function getDelegationDetails(uint256 delegationId) view returns (address[] allowedTargets, bytes4[] allowedSelectors)',
]);

export interface Delegation {
  delegator: `0x${string}`;
  delegate: `0x${string}`;
  maxValue: bigint;
  expiresAt: bigint;
  intentHash: `0x${string}`;
  parentDelegationId: number;
  revoked: boolean;
}

export interface DelegationClientOptions {
  contractAddress: `0x${string}`;
  rpcUrl: string;
}

/**
 * DelegationClient for AI agents.
 *
 * Allows preflight checks and retrieval of delegation constraints.
 */
export class DelegationClient {
  public readonly client: PublicClient;
  public readonly contractAddress: `0x${string}`;

  constructor(opts: DelegationClientOptions) {
    this.contractAddress = opts.contractAddress;
    this.client = createPublicClient({
      chain: base,
      transport: http(opts.rpcUrl),
    });
  }

  /**
   * Check if a call would satisfy a given delegation without gas.
   */
  async canExecute(
    delegationId: bigint,
    target: `0x${string}`,
    data: `0x${string}`,
    value: bigint
  ): Promise<boolean> {
    return this.client.readContract({
      address: this.contractAddress,
      abi: DELEGATOR_ABI,
      functionName: 'verifyCall',
      args: [delegationId, target, data, value],
    });
  }

  /**
   * Fetch delegation metadata.
   */
  async getDelegation(delegationId: bigint): Promise<Delegation> {
    return this.client.readContract({
      address: this.contractAddress,
      abi: DELEGATOR_ABI,
      functionName: 'getDelegation',
      args: [delegationId],
    });
  }

  /**
   * Fetch allowed targets/selectors for a delegation.
   */
  async getDelegationDetails(delegationId: bigint): Promise<{
    allowedTargets: `0x${string}`[];
    allowedSelectors: `0x${string}`[];
  }> {
    return this.client.readContract({
      address: this.contractAddress,
      abi: DELEGATOR_ABI,
      functionName: 'getDelegationDetails',
      args: [delegationId],
    });
  }
}
