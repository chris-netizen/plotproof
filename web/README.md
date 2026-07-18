# PlotProof — public dashboard

A public, read-only explorer for the [PlotProof](../README.md) land-claim
registry on Monad. Shows every claimed plot on a live map, tracks sales and
conflicts, and lets anyone check a location before they pay. It reads the
contract's `ClaimStaked` / `ClaimTransferred` events plus `getClaimsBatch` —
**no wallet needed to browse**.

Built with Next.js (App Router) + viem + Leaflet. The chain is read **server-side**
so the browser never talks to the RPC directly (no CORS headaches).

## Run locally

```bash
cd web
npm install
cp .env.example .env.local     # then edit the values (see below)
npm run dev                    # http://localhost:3000
```

## Environment variables

| Variable | Purpose | Default |
|---|---|---|
| `PLOTPROOF_RPC_URL` | Monad testnet RPC (server-side only) | `https://testnet-rpc.monad.xyz` |
| `PLOTPROOF_CONTRACT` | Deployed PlotProof address | `0xD53EBd…e0D4` |
| `PLOTPROOF_DEPLOY_BLOCK` | Block the contract was deployed at — **set this** so event scans stay fast | `0` |

Find the deploy block (WSL, from your deploy clone):

```bash
grep -i blockNumber ~/plotproof-src/broadcast/Deploy.s.sol/10143/run-latest.json
# convert the 0x… hex to decimal, or read the "created" block on the
# contract's page at testnet.monadexplorer.com
```

## Deploy to Vercel

1. Push this repo to GitHub (already done).
2. On [vercel.com](https://vercel.com) → **Add New → Project** → import the repo.
3. **Set the Root Directory to `web`** (this app lives in a subfolder).
4. Add the environment variables above under **Settings → Environment Variables**.
5. Deploy. Vercel auto-detects Next.js.

The dashboard re-reads the chain (cached ~30s) on each load, so new claims and
sales appear within about half a minute.
