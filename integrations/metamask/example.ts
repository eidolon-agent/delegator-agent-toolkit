/**
 * Example: Using the MetaMask Delegation Adapter with the DelegatorAgent contract
 *
 * This demonstrates typical flows:
 * - Human creates a root delegation to an agent
 * - Agent creates a sub-delegation to a sub-agent
 * - Sub-agent executes a call under constraints
 * - Verification and revocation
 *
 * Run with:
 *   npx tsx integrations/metamask/example.ts
 */

import { MetaMaskDelegationAdapter } from './MetaMaskDelegationAdapter'
import { parseEther } from 'viem'

async function main() {
  // Configuration
  const contractAddress = '0x3ba2e2a5f75b935fe51ec1bde24748a4a3f3bdc9' // Sepolia deployment
  const rpcUrl = 'https://sepolia.base.org'

  const adapter = new MetaMaskDelegationAdapter({
    contractAddress,
    rpcUrl
  })

  // 1. Human creates a root delegation to an agent
  console.log('Creating root delegation...')
  const rootId = await adapter.createDelegation({
    delegate: '0xAgentAddressHere' as any,
    allowedTargets: ['0xSomeToken' as any],
    allowedSelectors: ['0xa9059cbb'], // transfer(address,uint256) selector bytes4
    maxValue: parseEther('0.01'),
    ttlSeconds: BigInt(86400),
    intentHash: '0x' + '1'.repeat(64) // placeholder
  })
  console.log('Root delegation ID:', rootId.toString())

  // 2. Agent creates a sub-delegation with tighter limits
  console.log('Creating sub-delegation...')
  const subId = await adapter.createSubDelegation(rootId, {
    delegate: '0xSubAgentAddress' as any,
    allowedTargets: ['0xSomeToken' as any],
    allowedSelectors: ['0xa9059cbb'],
    maxValue: parseEther('0.005'),
    ttlSeconds: BigInt(3600),
    intentHash: '0x' + '2'.repeat(64)
  })
  console.log('Sub-delegation ID:', subId.toString())

  // 3. Sub-agent wants to execute a transfer call
  console.log('Verifying call parameters...')
  const canExecute = await adapter.verifyCall(
    subId,
    '0xSomeToken' as any,
    '0xa9059cbb' + '0x0000000000000000000000004d2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a000000000000000000000000000000000000000000000000000000000000000d' as any,
    parseEther('0.001')
  )
  console.log('Can execute?', canExecute)

  // 4. Execute (this will send an onchain transaction; needs signing)
  // In a real dApp, you'd use the wallet's signAndSend.
  // console.log('Executing call...')
  // const txHash = await adapter.execute(
  //   subId,
  //   '0xSomeToken' as any,
  //   '0xa9059cbb...' as any,
  //   parseEther('0.001')
  // )
  // console.log('Tx hash:', txHash)

  // 5. Fetch full delegation info (tree)
  const info = await adapter.getDelegation(subId)
  console.log('Delegation info:', {
    parent: info.parentDelegationId.toString(),
    maxValue: info.maxValue.toString(),
    revoked: info.revoked,
    childrenCount: info.children.length
  })

  // 6. Revoke root (human)
  // await adapter.revoke(rootId)
  // console.log('Root revoked')
}

main().catch(console.error)
