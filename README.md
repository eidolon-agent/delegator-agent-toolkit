# Delegator Agent Toolkit 🎯

**Synthesis Hackathon submission targeting MetaMask Delegation Framework bounty ($5,000).**

A toolkit for AI agents to perform intent-based delegations with sub-delegation chains and ZK proof support.

## Architecture

```
human ──delegates──► agent ──sub-delegates──► sub-agent
   │                        │
   └──intent hash───────────┘
```

- **DelegatorAgent.sol** – Onchain registry that stores delegations and executes calls under constraints.
- **DelegationClient (Node.js)** – Offchain library for agents to preflight checks and safe execution.
- **React Dashboard** – Human UI to create, view, and revoke delegations (in progress).

## Key Features

- ✅ Intent-based: Limit by target contracts, function selectors, max value, expiry.
- ✅ Sub-delegation chains: Agent can create tighter sub-delegations for child agents.
- ✅ ZK-ready: Store `intentHash` (preimage can be proved with zkSNARK without revealing).
- ✅ Transparent: All actions logged onchain; parent-child tree visible.

## Quick Start

### Contracts

```bash
cd contracts
forge install
forge build
forge test
```

Set `BASE_RPC_URL` for fork tests:

```bash
export BASE_RPC_URL=https://mainnet.base.org
forge test --fork-url $BASE_RPC_URL
```

### Deploy to Base Testnet

1. Get testnet ETH from Base faucet.
2. Set env:

```bash
export BASE_RPC_URL=https://sepolia.base.org
export PRIVATE_KEY=0x...
```

3. Deploy:

```bash
forge script script/Deploy.s.sol:DeployDelegatorAgent --rpc-url $BASE_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
```

### Node Middleware

```bash
cd middleware
npm install
npm run build
```

Example usage:

```ts
import { DelegationClient } from '@eidolon/delegation-client';

const client = new DelegationClient({
  contractAddress: '0x...',
  rpcUrl: 'https://mainnet.base.org'
});

const ok = await client.canExecute(delegationId, target, data, value);
if (ok) {
  // send tx via DelegatorAgent.execute()
}
```

## Design Notes (for Judges)

- **Innovation**: Extends the idea of delegation beyond simple approvals to an intent-based, hierarchical permission system suitable for autonomous AI agents.
- **Real-world use**: An agent can be given limited scope to manage a portfolio, pay bills, or coordinate sub-agents without risking unlimited access.
- **ZK Potential**: The `intentHash` field allows integration of zkSNARKs to prove knowledge of the human's intent without storing it onchain (privacy).
- **Open source**: MIT licensed, built with Foundry, TypeScript, and follows ETHSKILLS best practices.

## Status

- [x] Smart contract prototype
- [x] Foundry tests
- [x] Node.js middleware
- [ ] React frontend (dashboard)
- [ ] Base testnet demo deployment
- [ ] Integration with MetaMask Delegation Framework (future work)

## License

MIT

