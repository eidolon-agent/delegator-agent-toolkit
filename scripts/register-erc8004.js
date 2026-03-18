#!/usr/bin/env node
/**
 * Register ERC-8004 identity for this agent on Base Mainnet.
 *
 * Prerequisites:
 * - Private key for the operator wallet (with ETH for gas)
 * - RPC URL for Base Mainnet
 *
 * This calls the official ERC-8004 registry to create an agent identity.
 * Address: 0x12385360729aE68701E46e77fd07A07A391a3756 (mainnet registry)
 *
 * The transaction will mint an ERC-8004 token (NFT) to your wallet.
 * Save the tx hash and the new agent's address for Synthesis submission.
 */

import { createWalletClient, http, parseEther } from 'viem';
import { base } from 'viem/chains';

// Registry ABI (simplified)
const registryABI = [
  {
    inputs: [{ name: 'operator', type: 'address' }],
    name: 'registerAgent',
    outputs: [{ name: 'agent', type: 'address' }],
    stateMutability: 'nonpayable',
    type: 'function'
  }
];

async function main() {
  const privateKey = process.env.PRIVATE_KEY;
  const rpcUrl = process.env.BASE_RPC_URL || 'https://mainnet.base.org';

  if (!privateKey) {
    console.error('Set PRIVATE_KEY env');
    process.exit(1);
  }

  const client = createWalletClient({
    chain: base,
    transport: http(rpcUrl),
    account: privateKey as `0x${string}`
  });

  const registryAddress = '0x12385360729aE68701E46e77fd07A07A391a3756' as const;

  console.log('Registering ERC-8004 identity...');
  const tx = await client.writeContract({
    address: registryAddress,
    abi: registryABI,
    functionName: 'registerAgent',
    args: [client.account.address]
  });

  console.log('Tx hash:', tx);
  console.log('Wait for receipt, then update Synthesis project with the agent address (returned by eventlog or call).');
}

main().catch(console.error);
