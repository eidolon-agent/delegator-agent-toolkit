import { createPublicClient, http, parseEther } from 'viem'
import { baseSepolia, base } from 'wagmi/chains'

const contractAddress = process.env.NEXT_PUBLIC_CONTRACT_ADDRESS!

export const getContract = (chain: typeof baseSepolia | typeof base) =>
  createPublicClient({
    chain,
    transport: http()
  }).extend({
    async getDelegation(id: bigint) {
      return this.readContract({
        address: contractAddress,
        abi: abi,
        functionName: 'getDelegation',
        args: [id]
      }) as Promise<any>
    },
    async getDelegationDetails(id: bigint) {
      return this.readContract({
        address: contractAddress,
        abi: abi,
        functionName: 'getDelegationDetails',
        args: [id]
      }) as Promise<any>
    },
    async getChildren(id: bigint) {
      return this.readContract({
        address: contractAddress,
        abi: abi,
        functionName: 'getChildren',
        args: [id]
      }) as Promise<bigint[]>
    }
  })

export const abi = [
  {
    inputs: [
      { name: 'delegate', type: 'address' },
      { name: 'allowedTargets', type: 'address[]' },
      { name: 'allowedSelectors', type: 'bytes4[]' },
      { name: 'maxValue', type: 'uint256' },
      { name: 'ttlSeconds', type: 'uint256' },
      { name: 'intentHash', type: 'bytes32' }
    ],
    name: 'createDelegation',
    outputs: [{ name: 'delegationId', type: 'uint256' }],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [
      { name: 'parentDelegationId', type: 'uint256' },
      { name: 'subDelegate', type: 'address' },
      { name: 'allowedTargets', type: 'address[]' },
      { name: 'allowedSelectors', type: 'bytes4[]' },
      { name: 'maxValue', type: 'uint256' },
      { name: 'ttlSeconds', type: 'uint256' },
      { name: 'intentHash', type: 'bytes32' }
    ],
    name: 'createSubDelegation',
    outputs: [{ name: 'subDelegationId', type: 'uint256' }],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [
      { name: 'delegationId', type: 'uint256' },
      { name: 'target', type: 'address' },
      { name: 'data', type: 'bytes' },
      { name: 'value', type: 'uint256' }
    ],
    name: 'execute',
    outputs: [{ name: 'result', type: 'bytes' }],
    stateMutability: 'payable',
    type: 'function'
  },
  {
    inputs: [{ name: 'delegationId', type: 'uint256' }],
    name: 'revoke',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [{ name: 'delegationId', type: 'uint256' }],
    name: 'getDelegation',
    outputs: [
      { name: 'delegator', type: 'address' },
      { name: 'delegate', type: 'address' },
      { name: 'maxValue', type: 'uint256' },
      { name: 'expiresAt', type: 'uint256' },
      { name: 'intentHash', type: 'bytes32' },
      { name: 'parentDelegationId', type: 'uint256' },
      { name: 'revoked', type: 'bool' }
    ],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [{ name: 'delegationId', type: 'uint256' }],
    name: 'getDelegationDetails',
    outputs: [
      { name: 'allowedTargets', type: 'address[]' },
      { name: 'allowedSelectors', type: 'bytes4[]' }
    ],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [{ name: 'delegationId', type: 'uint256' }],
    name: 'getChildren',
    outputs: [{ name: '', type: 'uint256[]' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [
      { name: 'delegationId', type: 'uint256' },
      { name: 'target', type: 'address' },
      { name: 'data', type: 'bytes' },
      { name: 'value', type: 'uint256' }
    ],
    name: 'verifyCall',
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function'
  }
] as const
