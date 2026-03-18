import { createConfig, http } from 'wagmi'
import { baseSepolia, base } from 'wagmi/chains'
import { injected, metaMask } from 'wagmi/connectors'

const env = process.env

export const config = createConfig({
  chains: [baseSepolia, base],
  connectors: [injected(), metaMask()],
  transports: {
    [baseSepolia.id]: http(),
    [base.id]: http()
  },
  // Optional: WalletConnect if you have a projectId
  ...(env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID ? {
    walletConnect: { projectId: env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID }
  } : {})
})
