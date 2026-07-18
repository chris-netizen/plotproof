# PlotProof

**A tamper-proof, geo-anchored "first claim" ledger for land. Check before you pay.**

PlotProof lets anyone stand on a plot of land, capture a photo + GPS + timestamp, and
anchor a proof of that inspection to the [Monad](https://monad.xyz) blockchain — permanently
and publicly. Before buying, a second buyer, agent, or lawyer can query the exact location and
instantly see whether the plot has already been claimed by someone else.

> Built solo for the **BuildAnything "Spark" hackathon** on Monad.

---

## The problem

Land fraud in Nigeria is estimated to cost the economy around **$4 billion a year**. The root
cause is documentation: **less than 10% of land is formally registered**, so the same plot can be
sold to several buyers who have no shared, trustworthy way to discover each other. By the time a
"double sale" surfaces, the money is gone.

There is no cheap, public, tamper-proof place to record *"someone already inspected and claimed
this exact spot, on this date, with this evidence."* PlotProof is that place.

## How it works

1. **Stake a claim** — standing on the plot, the app captures a photo and reads GPS + time. It
   computes `keccak256(photo ‖ lat ‖ lng ‖ timestamp ‖ your address)` and writes that hash, the
   coordinates, and a geocell id to the contract in a single Monad transaction. The photo itself
   never leaves the device — only its hash goes on-chain, so the evidence is provable without
   being exposed.
2. **Check a plot** — before paying, tap the plot on a map. The app snaps the point to a geohash
   cell, queries that cell **and its 8 neighbours** (so a plot straddling a boundary still
   surfaces), and lists every prior claim. **Claims from more than one address on the same spot
   raise a conflict warning — a possible double sale.**
3. **Sell / transfer** — when the plot changes hands, the current owner transfers the claim to the
   buyer's wallet on-chain. This records a verifiable **chain of custody** (`A → B`), so a genuine
   sale becomes a *linked* trail instead of looking like a double sale. Only the current owner can
   transfer, and the buyer becomes the recognised owner.
4. **Verify evidence** — because the hashing scheme is canonical and public, a claimant can later
   re-hash their original photo + metadata and prove on-chain that *that* evidence existed at
   claim time.

Because a legitimate sale is *one* claim transferred along a chain, while a fraudulent double sale
is *two unlinked* claimants on the same plot, the conflict warning becomes a precise fraud signal
rather than a false alarm.

## Live deployment

| | |
|---|---|
| **Network** | Monad testnet (chain id `10143`) |
| **Contract** | [`0xD53EBd6F4AF19D43F468c9c4434310f190e4e0D4`](https://testnet.monadexplorer.com/address/0xD53EBd6F4AF19D43F468c9c4434310f190e4e0D4) |
| **Source** | [`contracts/PlotProof.sol`](contracts/PlotProof.sol) |

## Architecture

```
Flutter app (Dart)                         Monad testnet
──────────────────                         ─────────────
Claim screen  ─ photo+GPS ─► keccak256 ──► stakeClaim(cell, hash, latE7, lngE7, note)
Check screen  ─ map tap    ─► geocell  ──► getClaimsBatch(cells[9]) ──► conflict view
                                           claimCounts / hasEvidence
```

**Contract** ([`PlotProof.sol`](contracts/PlotProof.sol)) — a Solidity claim ledger indexed by
`bytes32` geohash cell. `stakeClaim` appends a `Claim{claimant, evidenceHash, latE7, lngE7,
timestamp, note}`; `transferClaim` hands a claim to a new owner (owner-only) and emits
`ClaimTransferred`, forming an on-chain chain of custody; `getClaimsBatch` / `claimCounts` read a
whole 9-cell block — with each claim's current owner — in one RPC round trip; `hasEvidence`
supports later verification. Ownership is tracked in a side mapping so the original `Claim` (and
thus the evidence hash, which commits to the original claimant) stays immutable. Coordinates are
validated on-chain and notes are length-bounded to keep costs down.

**App** (`app/lib/`)
- `geocell.dart` — pure-Dart geohash encode/decode + neighbour math; encodes a cell as ASCII
  bytes right-padded into `bytes32` (trivially reproducible in any language, cheap to compare
  on-chain). Default precision 8 ≈ a plot-sized ~38×19 m cell.
- `evidence.dart` — the canonical evidence-hash byte layout, fixed forever so claims stay
  verifiable.
- `services/chain_service.dart` — `web3dart` binding to the contract (read + write).
- `services/wallet_service.dart` — in-app burner wallet, private key generated on first launch
  and held in the platform secure storage/keystore.
- `screens/` — `check_screen.dart` (map-based conflict check, the hero flow) and
  `claim_screen.dart` (capture → hash → stake).

## Tech stack

Flutter · Dart · web3dart · Solidity 0.8.24 · Foundry · Monad · OpenStreetMap (flutter_map) ·
geolocator · image_picker

## Run it

### Mobile app (Android)

```bash
cd app
flutter pub get
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

Install the APK on an Android device, then fund the wallet address it shows (top-right of the app)
from a [Monad testnet faucet](https://docs.monad.xyz) before staking a claim.

> On a machine where the project and the Flutter/pub cache live on **different drives**, the Kotlin
> incremental compiler can fail on a cross-root path. This repo already sets
> `kotlin.incremental=false` in `app/android/gradle.properties` to avoid it.

### Web (optional)

```bash
cd app
flutter build web        # serve build/web with any static server
```

### Contract

```bash
forge build
forge script contracts/Deploy.s.sol --rpc-url https://testnet-rpc.monad.xyz --private-key <key> --broadcast
```

## Repository layout

```
contracts/        PlotProof.sol + Deploy.s.sol (Foundry)
app/              Flutter app (staking, selling, checking)
  lib/            geocell, evidence, chain/wallet services, screens
web/              Next.js public dashboard (deploys to Vercel)
foundry.toml      Foundry config
```

## Public dashboard

A separate, wallet-free web app in [`web/`](web/) reads the same contract and
shows **every claim on a live map**, with sales tracked, conflicts flagged, an
activity feed, and a "check this plot" search — the shareable, verifiable face
of the registry. It reads the chain server-side (via Next.js on Vercel) so
there are no browser-RPC/CORS issues. See [web/README.md](web/README.md) to run
or deploy it.

## License

MIT
