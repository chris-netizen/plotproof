import { createPublicClient, defineChain, http } from "viem";

export const CONTRACT_ADDRESS = (process.env.PLOTPROOF_CONTRACT ??
  "0xD53EBd6F4AF19D43F468c9c4434310f190e4e0D4") as `0x${string}`;

export const RPC_URL =
  process.env.PLOTPROOF_RPC_URL ?? "https://testnet-rpc.monad.xyz";

export const DEPLOY_BLOCK = BigInt(process.env.PLOTPROOF_DEPLOY_BLOCK ?? "0");

export const EXPLORER = "https://testnet.monadexplorer.com";

export const monadTestnet = defineChain({
  id: 10143,
  name: "Monad Testnet",
  nativeCurrency: { name: "Monad", symbol: "MON", decimals: 18 },
  rpcUrls: { default: { http: [RPC_URL] } },
  blockExplorers: {
    default: { name: "MonadExplorer", url: EXPLORER },
  },
  testnet: true,
});

export function publicClient() {
  return createPublicClient({
    chain: monadTestnet,
    transport: http(RPC_URL, {
      batch: true,
      timeout: Number(process.env.PLOTPROOF_RPC_TIMEOUT ?? "4000"),
      retryCount: Number(process.env.PLOTPROOF_RPC_RETRIES ?? "1"),
    }),
  });
}

/** Event: emitted on every new claim (carries the coordinates). */
export const CLAIM_STAKED = {
  type: "event",
  name: "ClaimStaked",
  inputs: [
    { name: "cell", type: "bytes32", indexed: true },
    { name: "claimant", type: "address", indexed: true },
    { name: "evidenceHash", type: "bytes32", indexed: false },
    { name: "latE7", type: "int64", indexed: false },
    { name: "lngE7", type: "int64", indexed: false },
    { name: "timestamp", type: "uint64", indexed: false },
    { name: "indexInCell", type: "uint256", indexed: false },
  ],
} as const;

/** Event: emitted when a claim changes owner (a sale). */
export const CLAIM_TRANSFERRED = {
  type: "event",
  name: "ClaimTransferred",
  inputs: [
    { name: "cell", type: "bytes32", indexed: true },
    { name: "indexInCell", type: "uint256", indexed: true },
    { name: "from", type: "address", indexed: true },
    { name: "to", type: "address", indexed: false },
    { name: "timestamp", type: "uint64", indexed: false },
    { name: "transferCount", type: "uint32", indexed: false },
  ],
} as const;

/** getClaimsBatch — reads full claim details (incl. note + current owner). */
export const GET_CLAIMS_BATCH = {
  type: "function",
  name: "getClaimsBatch",
  stateMutability: "view",
  inputs: [{ name: "cells", type: "bytes32[]" }],
  outputs: [
    { name: "cellOf", type: "bytes32[]" },
    { name: "idxOf", type: "uint256[]" },
    { name: "ownerOf", type: "address[]" },
    {
      name: "claims",
      type: "tuple[]",
      components: [
        { name: "claimant", type: "address" },
        { name: "evidenceHash", type: "bytes32" },
        { name: "latE7", type: "int64" },
        { name: "lngE7", type: "int64" },
        { name: "timestamp", type: "uint64" },
        { name: "note", type: "string" },
      ],
    },
  ],
} as const;

export const ABI = [GET_CLAIMS_BATCH] as const;
