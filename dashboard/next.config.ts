import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ['wagmi', '@wagmi', 'viem']
};

export default nextConfig;
