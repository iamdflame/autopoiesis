/** 0G network parameters. Mainnet is the target for Wave 3+ submissions. */
export const OG_MAINNET = {
  id: 16661,
  name: "0G",
  nativeCurrency: { name: "0G", symbol: "0G", decimals: 18 },
  rpcUrls: { default: { http: ["https://evmrpc.0g.ai"] } },
  blockExplorers: { default: { name: "ChainScan", url: "https://chainscan.0g.ai" } },
} as const;

export const OG_STORAGE_INDEXER = "https://indexer-storage-turbo.0g.ai";
export const OG_COMPUTE_ROUTER = "https://router-api.0g.ai/v1";

/** Deployed 0G Storage system contracts, for reference and cost estimation. */
export const OG_STORAGE_CONTRACTS = {
  flow: "0x62D4144dB0F0a6fBBaeb6296c785C71B3D57C526",
  mine: "0xCd01c5Cd953971CE4C2c9bFb95610236a7F414fe",
  reward: "0x457aC76B58ffcDc118AABD6DbC63ff9072880870",
} as const;
