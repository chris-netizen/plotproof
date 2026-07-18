import "server-only";
import type { AbiEvent } from "viem";
import {
  ABI,
  CLAIM_STAKED,
  CLAIM_TRANSFERRED,
  CONTRACT_ADDRESS,
  DEPLOY_BLOCK,
  EXPLORER,
  publicClient,
} from "./contract";
import { hexToCell, neighboursOf } from "./geocell";
import type { Activity, ClaimsData, Plot, RegionStat } from "./types";

const CACHE_TTL_MS = 30_000;
const DEFAULT_LOOKBACK = 1_500_000n; // if deploy block unknown
const REGION_PREC = 5; // geohash prefix length used to group "areas"

let cache: { data: ClaimsData; at: number } | null = null;

type DecodedLog = {
  args: Record<string, unknown>;
  transactionHash: `0x${string}` | null;
  blockNumber: bigint | null;
};

// Monad testnet caps eth_getLogs at 1000 blocks/request and recommends small
// ranges with high concurrency. Stay safely under the cap and parallelise.
const LOG_RANGE = 900n;
const CONCURRENCY = 6;

/** getLogs across a range using valid <=1000-block windows, newest-first,
 *  with bounded concurrency and a time budget. */
async function getLogsChunked(
  client: ReturnType<typeof publicClient>,
  event: AbiEvent,
  fromBlock: bigint,
  toBlock: bigint,
  deadline: number,
): Promise<DecodedLog[]> {
  // Build windows newest-first so recent claims come back first.
  const windows: Array<[bigint, bigint]> = [];
  let end = toBlock;
  while (end >= fromBlock) {
    const start = end - LOG_RANGE + 1n < fromBlock ? fromBlock : end - LOG_RANGE + 1n;
    windows.push([start, end]);
    if (start <= fromBlock) break;
    end = start - 1n;
  }

  const out: DecodedLog[] = [];
  for (let i = 0; i < windows.length; i += CONCURRENCY) {
    if (Date.now() > deadline) break; // don't blow the function timeout
    const batch = windows.slice(i, i + CONCURRENCY);
    const results = await Promise.all(
      batch.map(([s, e]) =>
        client
          .getLogs({ address: CONTRACT_ADDRESS, event, fromBlock: s, toBlock: e })
          .then((l) => l as unknown as DecodedLog[])
          .catch(() => [] as DecodedLog[]),
      ),
    );
    for (const r of results) out.push(...r);
  }
  return out;
}

function short(addr: string) {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
}

async function build(): Promise<ClaimsData> {
  const client = publicClient();
  // Global time budget so we never blow a serverless function timeout.
  const deadline = Date.now() + 9_000;
  const latest = await client.getBlockNumber();
  const fromBlock =
    DEPLOY_BLOCK > 0n
      ? DEPLOY_BLOCK
      : latest > DEFAULT_LOOKBACK
        ? latest - DEFAULT_LOOKBACK
        : 0n;

  // The contract's own claim count — a sanity signal independent of log scans.
  let onChainTotal = 0;
  try {
    const t = (await client.readContract({
      address: CONTRACT_ADDRESS,
      abi: ABI,
      functionName: "totalClaims",
    })) as bigint;
    onChainTotal = Number(t);
  } catch {
    onChainTotal = -1; // read failed
  }

  const [stakedLogs, transferLogs] = await Promise.all([
    getLogsChunked(client, CLAIM_STAKED as AbiEvent, fromBlock, latest, deadline),
    getLogsChunked(
      client,
      CLAIM_TRANSFERRED as AbiEvent,
      fromBlock,
      latest,
      deadline,
    ),
  ]);

  // Unique cells (bytes32 hex) discovered from stake events.
  const cellHexes = Array.from(
    new Set(stakedLogs.map((l) => (l.args as { cell: string }).cell)),
  );

  // Custody: cell+index -> ordered list of owners (from transfer events).
  type Xfer = { from: string; to: string; timestamp: number };
  const xfersByKey = new Map<string, Xfer[]>();
  const transferActivity: Activity[] = [];
  for (const l of transferLogs) {
    const a = l.args as {
      cell: string;
      indexInCell: bigint;
      from: string;
      to: string;
      timestamp: bigint;
    };
    const cell = hexToCell(a.cell);
    const key = `${a.cell}:${a.indexInCell}`;
    const list = xfersByKey.get(key) ?? [];
    list.push({ from: a.from, to: a.to, timestamp: Number(a.timestamp) });
    xfersByKey.set(key, list);
    transferActivity.push({
      kind: "transfer",
      timestamp: Number(a.timestamp),
      cell,
      from: a.from,
      to: a.to,
      txHash: l.transactionHash ?? "",
      block: Number(l.blockNumber ?? 0n),
    });
  }
  for (const list of xfersByKey.values())
    list.sort((x, y) => x.timestamp - y.timestamp);

  // Authoritative plot details (note + current owner) via getClaimsBatch,
  // with a fallback to event-derived data if the read fails.
  const plots: Plot[] = [];
  let usedBatch = false;
  if (cellHexes.length > 0) {
    try {
      const res = (await client.readContract({
        address: CONTRACT_ADDRESS,
        abi: ABI,
        functionName: "getClaimsBatch",
        args: [cellHexes as `0x${string}`[]],
      })) as unknown as [
        readonly string[],
        readonly bigint[],
        readonly string[],
        readonly {
          claimant: string;
          latE7: bigint;
          lngE7: bigint;
          timestamp: bigint;
          note: string;
        }[],
      ];
      const [cellOf, idxOf, ownerOf, claims] = res;
      for (let i = 0; i < claims.length; i++) {
        const cell = hexToCell(cellOf[i]);
        const index = Number(idxOf[i]);
        const key = `${cellOf[i]}:${index}`;
        const owners = xfersByKey.get(key)?.map((x) => x.to) ?? [];
        plots.push({
          cell,
          cellHex: cellOf[i],
          index,
          claimant: claims[i].claimant,
          owner: ownerOf[i],
          lat: Number(claims[i].latE7) / 1e7,
          lng: Number(claims[i].lngE7) / 1e7,
          timestamp: Number(claims[i].timestamp),
          note: claims[i].note,
          transferred:
            ownerOf[i].toLowerCase() !== claims[i].claimant.toLowerCase(),
          transfers: owners.length,
          custody: [claims[i].claimant, ...owners],
          conflict: false,
        });
      }
      usedBatch = true;
    } catch {
      usedBatch = false;
    }
  }

  if (!usedBatch) {
    // Fallback: reconstruct from stake events (no note text available).
    for (const l of stakedLogs) {
      const a = l.args as {
        cell: string;
        claimant: string;
        latE7: bigint;
        lngE7: bigint;
        timestamp: bigint;
        indexInCell: bigint;
      };
      const index = Number(a.indexInCell);
      const key = `${a.cell}:${index}`;
      const owners = xfersByKey.get(key)?.map((x) => x.to) ?? [];
      const owner = owners.length ? owners[owners.length - 1] : a.claimant;
      plots.push({
        cell: hexToCell(a.cell),
        cellHex: a.cell,
        index,
        claimant: a.claimant,
        owner,
        lat: Number(a.latE7) / 1e7,
        lng: Number(a.lngE7) / 1e7,
        timestamp: Number(a.timestamp),
        note: "",
        transferred: owner.toLowerCase() !== a.claimant.toLowerCase(),
        transfers: owners.length,
        custody: [a.claimant, ...owners],
        conflict: false,
      });
    }
  }

  // Conflict: a claim in this cell or an adjacent cell by a DIFFERENT claimant.
  const claimantsByCell = new Map<string, Set<string>>();
  for (const p of plots) {
    const set = claimantsByCell.get(p.cell) ?? new Set<string>();
    set.add(p.claimant.toLowerCase());
    claimantsByCell.set(p.cell, set);
  }
  for (const p of plots) {
    const near = new Set<string>();
    for (const nb of neighboursOf(p.cell)) {
      const set = claimantsByCell.get(nb);
      if (set) for (const c of set) near.add(c);
    }
    near.delete(p.claimant.toLowerCase());
    p.conflict = near.size > 0;
  }

  // Activity feed: stakes + transfers, newest first.
  const stakeActivity: Activity[] = stakedLogs.map((l) => {
    const a = l.args as { cell: string; claimant: string; timestamp: bigint };
    const cell = hexToCell(a.cell);
    const note = plots.find((p) => p.cell === cell)?.note ?? "";
    return {
      kind: "stake",
      timestamp: Number(a.timestamp),
      cell,
      actor: a.claimant,
      note,
      txHash: l.transactionHash ?? "",
      block: Number(l.blockNumber ?? 0n),
    };
  });
  const activity = [...stakeActivity, ...transferActivity].sort(
    (x, y) => y.timestamp - x.timestamp || y.block - x.block,
  );

  // Analytics: per-day stakes.
  const dayMap = new Map<string, number>();
  for (const p of plots) {
    const d = new Date(p.timestamp * 1000).toISOString().slice(0, 10);
    dayMap.set(d, (dayMap.get(d) ?? 0) + 1);
  }
  const byDay = Array.from(dayMap.entries())
    .map(([date, count]) => ({ date, count }))
    .sort((a, b) => a.date.localeCompare(b.date));

  // Analytics: regions (coarse geohash prefix).
  const regionMap = new Map<string, RegionStat>();
  for (const p of plots) {
    const key = p.cell.slice(0, REGION_PREC);
    const r = regionMap.get(key) ?? {
      key,
      label: "",
      count: 0,
      conflicts: 0,
    };
    r.count++;
    if (p.conflict) r.conflicts++;
    if (!r.label && p.note) r.label = p.note;
    regionMap.set(key, r);
  }
  const regions = Array.from(regionMap.values())
    .map((r) => ({ ...r, label: r.label || `Area ${r.key}` }))
    .sort((a, b) => b.count - a.count);

  const owners = new Set(plots.map((p) => p.owner.toLowerCase())).size;
  const conflicts = plots.filter((p) => p.conflict).length;

  return {
    ok: true,
    updatedAt: Date.now(),
    contract: CONTRACT_ADDRESS,
    explorer: EXPLORER,
    plots,
    activity,
    analytics: {
      totalPlots: plots.length,
      totalSales: transferLogs.length,
      conflicts,
      owners,
      byDay,
      regions,
    },
    debug: {
      latestBlock: Number(latest),
      fromBlock: Number(fromBlock),
      onChainTotal,
      foundStaked: stakedLogs.length,
    },
  };
}

export async function getClaimsData(force = false): Promise<ClaimsData> {
  if (!force && cache && Date.now() - cache.at < CACHE_TTL_MS) {
    return cache.data;
  }
  try {
    const data = await build();
    cache = { data, at: Date.now() };
    return data;
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Failed to read the chain.";
    if (cache) return cache.data; // serve stale on error
    return {
      ok: false,
      error: msg,
      updatedAt: Date.now(),
      contract: CONTRACT_ADDRESS,
      explorer: EXPLORER,
      plots: [],
      activity: [],
      analytics: {
        totalPlots: 0,
        totalSales: 0,
        conflicts: 0,
        owners: 0,
        byDay: [],
        regions: [],
      },
    };
  }
}

export { short };
