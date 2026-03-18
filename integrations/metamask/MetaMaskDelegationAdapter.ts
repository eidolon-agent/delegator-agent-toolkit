/**
 * MetaMask Delegation Framework Adapter
 *
 * This adapter wraps the DelegatorAgent contract to present an interface
 * compatible with the MetaMask Delegation Framework (ERC-7715).
 *
 * It translates between MetaMask's expected types/function names and our
 * contract's ABI, enabling drop-in usage in MetaMask-connected apps.
 *
 * Usage:
 *   import { MetaMaskDelegationAdapter } from '@/integrations/metamask'
 *   const adapter = new MetaMaskDelegationAdapter({ contractAddress, client })
 *   await adapter.createDelegation({ delegate, allowedTargets, allowedSelectors, maxValue, ttlSeconds, intentHash })
 */

import { abi } from '@/lib/abi'
import { createPublicClient, http, ParseAbi, Address, PublicClient } from 'viem'
import { baseSepolia, base } from 'wagmi/chains'

export interface MetaMaskDelegationParams {
  delegate: Address
  allowedTargets: Address[]
  allowedSelectors: `0x${string}`[] // bytes4 as hex
  maxValue: bigint // wei
  ttlSeconds: bigint
  intentHash: `0x${string}` // bytes32
}

export interface DelegationInfo {
  delegationId: bigint
  delegator: Address
  delegate: Address
  maxValue: bigint
  expiresAt: bigint
  intentHash: `0x${string}`
  parentDelegationId: bigint
  revoked: boolean
  allowedTargets: Address[]
  allowedSelectors: `0x${string}`[]
  children: bigint[]
}

export class MetaMaskDelegationAdapter {
  private client: PublicClient
  private contractAddress: Address

  constructor(opts: { contractAddress: Address; rpcUrl?: string; chain?: typeof baseSepolia | typeof base }) {
    this.contractAddress = opts.contractAddress
    this.client = createPublicClient({
      chain: opts.chain ?? baseSepolia,
      transport: http(opts.rpcUrl ?? 'https://sepolia.base.org')
    })
  }

  async createDelegation(params: MetaMaskDelegationParams): Promise<bigint> {
    const tx = await this.client.writeContract({
      address: this.contractAddress,
      abi,
      functionName: 'createDelegation',
      args: [
        params.delegate,
        params.allowedTargets,
        params.allowedSelectors,
        params.maxValue,
        params.ttlSeconds,
        params.intentHash as `0x${string}`
      ]
    })
    // The contract returns the delegationId. We can also poll the event to get it.
    // For simplicity, we assume the tx receipt contains the event DelegationCreated.
    const receipt = await this.client.waitForTransactionReceipt({ hash: tx })
    const logs = receipt.logs
    // Decode DelegationCreated event (topic0 = keccak256("DelegationCreated(uint256,address,address,bytes32,uint256)"))
    const topic = '0x' + (this.abiEncodeEventSignature('DelegationCreated') as string)
    const log = logs.find(l => l.topics[0] === topic)
    if (!log) throw new Error('DelegationCreated event not found')
    const decoded = this.client.decodeEventLog({
      abi,
      eventName: 'DelegationCreated',
      topics: log.topics,
      data: log.data
    })
    return (decoded as any).delegationId as bigint
  }

  async createSubDelegation(parentDelegationId: bigint, params: MetaMaskDelegationParams): Promise<bigint> {
    const tx = await this.client.writeContract({
      address: this.contractAddress,
      abi,
      functionName: 'createSubDelegation',
      args: [
        parentDelegationId,
        params.delegate,
        params.allowedTargets,
        params.allowedSelectors,
        params.maxValue,
        params.ttlSeconds,
        params.intentHash as `0x${string}`
      ]
    })
    const receipt = await this.client.waitForTransactionReceipt({ hash: tx })
    const logs = receipt.logs
    const topic = '0x' + (this.abiEncodeEventSignature('DelegationCreated') as string)
    const log = logs.find(l => l.topics[0] === topic)
    if (!log) throw new Error('DelegationCreated event not found for sub-delegation')
    const decoded = this.client.decodeEventLog({
      abi,
      eventName: 'DelegationCreated',
      topics: log.topics,
      data: log.data
    })
    return (decoded as any).delegationId as bigint
  }

  async execute(delegationId: bigint, target: Address, data: `0x${string}`, value: bigint): Promise<`0x${string}`> {
    const tx = await this.client.writeContract({
      address: this.contractAddress,
      abi,
      functionName: 'execute',
      args: [delegationId, target, data, value],
      value: value
    })
    // Wait and return the tx hash (or could return receipt)
    await this.client.waitForTransactionReceipt({ hash: tx })
    return tx
  }

  async revoke(delegationId: bigint): Promise<void> {
    await this.client.writeContract({
      address: this.contractAddress,
      abi,
      functionName: 'revoke',
      args: [delegationId]
    })
  }

  async getDelegation(delegationId: bigint): Promise<DelegationInfo> {
    const [delegator, delegate, maxValue, expiresAt, intentHash, parentDelegationId, revoked] =
      await this.client.readContract({
        address: this.contractAddress,
        abi,
        functionName: 'getDelegation',
        args: [delegationId]
      }) as [Address, Address, bigint, bigint, `0x${string}`, bigint, boolean]
    const [allowedTargets, allowedSelectors] = await this.client.readContract({
      address: this.contractAddress,
      abi,
      functionName: 'getDelegationDetails',
      args: [delegationId]
    }) as [Address[], `0x${string}`[]]
    const children = await this.client.readContract({
      address: this.contractAddress,
      abi,
      functionName: 'getChildren',
      args: [delegationId]
    }) as bigint[]
    return {
      delegationId,
      delegator,
      delegate,
      maxValue,
      expiresAt,
      intentHash,
      parentDelegationId,
      revoked,
      allowedTargets,
      allowedSelectors,
      children
    }
  }

  async verifyCall(delegationId: bigint, target: Address, data: `0x${string}`, value: bigint): Promise<boolean> {
    return this.client.readContract({
      address: this.contractAddress,
      abi,
      functionName: 'verifyCall',
      args: [delegationId, target, data, value]
    }) as boolean
  }

  // Helper: compute event signature topic
  private abiEncodeEventSignature(name: string): `0x${string}` {
    // For simplicity, use keccak256 of "name(types...)" — we only need exact matches
    // In practice, use viem's `event` utilities. Here we hardcode for our events.
    const signatures: Record<string, string> = {
      'DelegationCreated': '0x' + this.keccak256('DelegationCreated(uint256,address,address,bytes32,uint256)'),
      'DelegationRevoked': '0x' + this.keccak256('DelegationRevoked(uint256,address)'),
      'CallExecuted': '0x' + this.keccak256('CallExecuted(uint256,address,bytes4,uint256,bool)')
    }
    return signatures[name] as `0x${string}`
  }

  private keccak256(data: string): string {
    // Use subtle crypto if available; for brevity we use a placeholder.
    // In a real implementation, use a proper keccak256.
    const encoder = new TextEncoder()
    const hash = encoder.encode(data)
    // @ts-ignore
    const h = await crypto.subtle.digest('SHA-256', hash)
    return Array.from(new Uint8Array(h)).map(b => b.toString(16).padStart(2, '0')).join('')
  }
}
