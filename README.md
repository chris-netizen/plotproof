# PlotProof — Complete Restart Kit

**Check before you pay.** A geo-anchored land claim ledger on Monad —
built for the BuildAnything "Spark" hackathon (deadline **Sun Jul 19,
23:59 UTC**).

```
contracts/PlotProof.sol        The claim ledger (deploy tonight)
contracts/Deploy.s.sol         Foundry deploy script
app/pubspec.yaml               Flutter deps (copy into a fresh project)
app/lib/config.dart            ⚠️ THE ONLY FILE YOU EDIT (RPC, chain id, address)
app/lib/geocell.dart           Geohash cells + bytes32 ids (test-vector verified)
app/lib/evidence.dart          Canonical evidence hashing
app/lib/services/wallet_service.dart   In-app burner wallet (secure storage)
app/lib/services/chain_service.dart    web3dart binding incl. tuple[] decoding
app/lib/screens/check_screen.dart      HERO screen: map -> 9-cell conflict check
app/lib/screens/claim_screen.dart      Photo + GPS -> hash -> stakeClaim tx
app/lib/main.dart              App shell (Check tab first, wallet in appbar)
```

---

## TONIGHT (Day 1) — contract live + repo public. ~2 hours.

```bash
# 1. Public GitHub repo FIRST — the judge audits commit history.
#    Commit the contract as your first commit.

# 2. Foundry
curl -L https://foundry.paradigm.xyz | bash && foundryup
forge init plotproof && cd plotproof
# copy PlotProof.sol + Deploy.s.sol into contracts/ (set src="contracts" in foundry.toml)

# 3. Get CURRENT testnet RPC URL + chain id + explorer from docs.monad.xyz
#    and testnet MON from the faucet (BuildAnything links one).
export MONAD_RPC="<rpc url>"
export PK="<burner private key>"

# 4. Deploy + verify (verification guide: docs.monad.xyz)
forge script contracts/Deploy.s.sol:DeployPlotProof \
  --rpc-url $MONAD_RPC --private-key $PK --broadcast

# 5. Smoke test — geohash "s1jkds3h" (Enugu) as bytes32:
CELL=0x73316a6b64733368000000000000000000000000000000000000000000000000
cast send <CONTRACT> "stakeClaim(bytes32,bytes32,int64,int64,string)" \
  $CELL 0x1111111111111111111111111111111111111111111111111111111111111111 \
  64402000 74943000 "Test plot, Enugu" \
  --rpc-url $MONAD_RPC --private-key $PK
cast call <CONTRACT> "claimCount(bytes32)(uint256)" $CELL --rpc-url $MONAD_RPC
# -> 1 ✅  Commit. Sleep.
```

## Day 2 (Fri) — the app claims on-chain

```bash
flutter create plotproof_app && cd plotproof_app
# Replace pubspec.yaml with app/pubspec.yaml, drop app/lib/* into lib/
flutter pub get
```

- Fill in `lib/config.dart` (RPC, chain id, deployed address, explorer).
- Android: add to AndroidManifest.xml —
  `ACCESS_FINE_LOCATION`, `INTERNET`, camera permission via image_picker docs.
- Run on your phone. Fund the in-app wallet address (shown in the app bar)
  from the faucet.
- **Goal: a real claim staked from the phone by tonight.** Commit.

## Day 3 (Sat) — Check screen + identity + web

- Check screen already works — test conflict flow: stake two claims on the
  same spot from two wallets (wipe app data to regenerate wallet, or use
  cast for the second), confirm the red "possible double sale" banner.
- Styling pass: pick a palette, app icon, splash. No default blue.
- `flutter build web` → deploy to Vercel/Netlify (map-tap works on web;
  GPS-claim is mobile's job). This is your required Project URL.
- Commit multiple times.

## Day 4 (Sun) — ship

- README polish (problem stats: ~$4B/yr lost to land fraud in Nigeria,
  1,500+ Lagos cases since 2020, <10% of land formally registered).
- Demo video ≤3 min — **open with the Check flow** (the everyday use),
  then show a claim being staked, then the conflict warning.
- Social post (viral prize), then SUBMIT EARLY — by Sunday afternoon,
  not 23:50 UTC.

---

## Submission checklist (from the hackathon rules)
- [ ] Project name + description + problem + solution
- [ ] Project URL (Flutter web deploy) — and APK link in README
- [ ] Public GitHub repo (steady commit history!)
- [ ] Category: **Testnet** + contract address (verified)
- [ ] Demo video ≤3 min, public
- [ ] Social post URL (optional, viral prize)

## Pitch framing (use in the description)
"As a GIS professional in Nigeria I watch buyers lose everything to
double-sold plots. PlotProof is the app you open before any land
payment: tap the plot, and Monad tells you instantly if someone
already staked a claim there — tamper-proof, geo-anchored, public.
Land fraud costs Nigeria ~$4B/year; the fix starts with a 10-second
check anyone can do."
