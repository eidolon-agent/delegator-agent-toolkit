# How to Use the Dashboard

## Prerequisites
- Install a Web3 wallet (e.g., MetaMask).
- Switch to the **Base Sepolia** testnet in your wallet.
- Fund your wallet with Sepolia ETH:
  - Use a faucet like https://sepoliafaucet.com or https://www.alchemy.com/faucets/base-sepolia

## Open the Dashboard
Visit the deployed URL (Vercel) once configured, or open `dashboard/index.html` locally in a browser.

## Connect Wallet
- Click “Connect Wallet” or the app will prompt automatically.
- Approve the connection request in MetaMask.

## Create a Root Delegation
1. Fill the form on the left:
   - **Delegate address**: the address you’re delegating to (e.g., your agent).
   - **Allowed targets**: comma-separated contract addresses this delegate can call (leave blank for none).
   - **Allowed selectors**: comma-separated bytes4 function selectors (e.g., `0xa9059cbb` for `transfer`). Optional.
   - **Max value (ETH)**: maximum Ether value the delegate can spend per call.
   - **TTL (seconds)**: time-to-live for the delegation (e.g., `86400` for 1 day).
   - **Intent hash**: optional 32-byte hex tying the delegation to a specific intent (e.g., `0x...`). Can be left empty.
2. Click **Create** and confirm the transaction in MetaMask.
3. On success, the delegation tree refreshes.

## Create a Sub-Delegation
1. Fill the right form:
   - **Parent delegation ID**: the numeric ID of an existing root (or sub) delegation.
   - **Sub-delegate address**: the new sub-address.
   - **Allowed targets / selectors**: as above; usually more restrictive than the parent.
   - **Max value (ETH)** and **TTL (seconds)**: as above.
   - **Intent hash**: optional.
2. Click **Create Sub** and confirm.
3. The tree updates to show the new sub-delegation under its parent.

## Revoke a Delegation
- In the delegation tree, click **Revoke** next to any sub-delegation.
- Confirm in the prompt and then in MetaMask.
- Note: The root delegation (ID 0) cannot be revoked via this UI; use contract directly if needed.

## View the Delegation Tree
- The tree shows root delegations and their children.
- Click ▶ to expand a node; ▼ to collapse.
- “Children” count is shown next to each root.
- Refresh button reloads the entire tree from the contract.

## Troubleshooting
- **No wallet detected**: Ensure MetaMask is installed and enabled in this browser/context.
- **Transaction fails**: Check you have enough ETH for gas and that the delegation parameters are valid (e.g., non-zero delegate, correct selector format).
- **Blank page**: Open browser DevTools (F12) → Console. Errors related to `ethers` indicate an old version; refresh to load the latest code. RPC errors may mean Base Sepolia is down or your RPC endpoint is unreachable.
- **RPC_URL**: The dashboard uses `https://sepolia.base.org`. If that endpoint fails, edit the `index.html` to point to a different Sepolia RPC.

## Technical Notes
- The dashboard uses raw `window.ethereum` calls; no external libraries.
- ABI encoding is custom and limited to the functions used.
- Contract address: `0x3ba2e2a5f75b935fe51ec1bde24748a4a3f3bdc9` on Base Sepolia.
