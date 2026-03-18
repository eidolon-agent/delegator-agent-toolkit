# Delegator Agent Dashboard

Next.js + wagmi frontend for interacting with the DelegatorAgent contract.

## Quick Start

```bash
cp .env.example .env.local
# .env.local already contains the Sepolia contract address
npm install
npm run dev
```

Open http://localhost:3000

## Deploy to Vercel

1. Push this `dashboard/` folder to its own GitHub repo, or keep it as a subdirectory in the monorepo.
2. In Vercel, import the project (point to `dashboard/` if monorepo).
3. Set Environment Variable:
   - `NEXT_PUBLIC_CONTRACT_ADDRESS` = `0x3ba2e2a5f75b935fe51ec1bde24748a4a3f3bdc9` (Sepolia)
4. Deploy.

The dashboard connects via the public RPC (no wallet needed to view). Transactions require a connected wallet with ETH on the selected network (Base Sepolia or Mainnet).

## Build

```bash
npm run build
```

## Tech

- Next.js 16 (App Router)
- wagmi + viem
- Tailwind CSS
