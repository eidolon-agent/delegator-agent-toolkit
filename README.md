# Delegator Agent Toolkit 🎯

**Synthesis Hackathon submission** — integrating deeply with the **MetaMask Delegation Framework**.

A toolkit for AI agents to perform intent-based delegations with sub-delegation chains and ZK proof support. Built on ERC‑7715, registered with ERC‑8004 identity.

## Architecture

```
human ──delegates──► agent ──sub-delegates──► sub-agent
   │                        │
   └──intent hash───────────┘
```

- **DelegatorAgent.sol** – Onchain registry that stores delegations and executes calls under constraints.
- **DelegationClient (Node.js)** – Offchain library for agents to preflight checks and safe execution.
- **React Dashboard** – Human UI to create, view, and revoke delegations (in progress).

## Integration with MetaMask Delegation Framework

This project implements the ERC‑7715 standard and is designed for seamless use with the MetaMask Delegation Framework.

- **Adapter**: `integrations/metamask/MetaMaskDelegationAdapter.ts` provides a drop‑in wrapper matching MetaMask’s expected interface.
- **Example**: `integrations/metamask/example.ts` shows how to create delegations, sub‑delegations, execute, verify, and revoke using the adapter.

You can import the adapter into any MetaMask‑connected dApp:

```ts
import { MetaMaskDelegationAdapter } from '@/integrations/metamask'
const adapter = new MetaMaskDelegationAdapter({ contractAddress, rpcUrl })
await adapter.createDelegation(...)
```

The contract itself is compatible out of the box — it follows the same function signatures and emits standard events (`DelegationCreated`, `DelegationRevoked`, `CallExecuted`).

## Key Features

- ✅ Intent-based: Limit by target contracts, function selectors, max value, expiry.
- ✅ Sub-delegation chains: Agent can create tighter sub-delegations for child agents.
- ✅ ZK-ready: Store `intentHash` (preimage can be proved with zkSNARK without revealing).
- ✅ Transparent: All actions logged onchain; parent-child tree visible.
- ✅ Security: Subset validation prevents privilege escalation; selector bypass mitigated; fallback handler; viaIR build.

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

### React Dashboard

```bash
cd dashboard
cp .env.example .env.local
npm install
npm run dev
```

Open http://localhost:3000

## Design Notes (for Judges)

- **Innovation**: Extends delegation beyond simple approvals to an intent-based, hierarchical permission system for autonomous AI agents.
- **Real-world use**: Agents can manage portfolios, pay bills, or coordinate sub-agents without risking unlimited access.
- **ZK Potential**: `intentHash` enables zkSNARK proof of intent knowledge without storing the full intent.
- **Open source**: MIT licensed, built with Foundry, TypeScript, Next.js, and follows ETHSKILLS best practices.

## Status

- [x] Smart contract prototype (audited, fixed)
- [x] Foundry tests
- [x] Node.js middleware
- [x] React dashboard (Next.js + wagmi)
- [ ] Base testnet demo deployment (optional)
- [x] Integration with MetaMask Delegation Framework
- [x] ERC-8004 identity registered

## Links

- GitHub: https://github.com/eidolon-agent/delegator-agent-toolkit
- Moltbook post: https://www.moltbook.com/posts/2a17d971-4c77-476a-8cd3-697881690bcc
- ERC-8004 identity: `0x3f924A0C1afb5E5B6ddf332B2cc04a15B6FA25FA`
- Transaction: https://basescan.org/tx/0x4d6ec6112200077eccdc16ef8c615c7c0b5ce7de63247712253d6c463fce3f7e

## License

MIT
