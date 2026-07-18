import { NextResponse } from "next/server";
import { ABI, CONTRACT_ADDRESS, EXPLORER, publicClient } from "@/lib/contract";
import { cellBlock, cellToHex, hexToCell } from "@/lib/geocell";
import type { Plot } from "@/lib/types";

export const dynamic = "force-dynamic";

// Check a single location by reading the 9-cell block straight from the
// contract (one eth_call). Independent of the event-log indexing, so it works
// even when the full map hasn't loaded.
export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const lat = parseFloat(searchParams.get("lat") ?? "");
  const lng = parseFloat(searchParams.get("lng") ?? "");
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return NextResponse.json(
      { ok: false, error: "Invalid coordinates" },
      { status: 400 },
    );
  }

  const cellHexes = cellBlock(lat, lng).map(cellToHex);

  try {
    const client = publicClient();
    const res = (await client.readContract({
      address: CONTRACT_ADDRESS,
      abi: ABI,
      functionName: "getClaimsBatch",
      args: [cellHexes],
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

    const plots: Plot[] = claims.map((c, i) => ({
      cell: hexToCell(cellOf[i]),
      cellHex: cellOf[i],
      index: Number(idxOf[i]),
      claimant: c.claimant,
      owner: ownerOf[i],
      lat: Number(c.latE7) / 1e7,
      lng: Number(c.lngE7) / 1e7,
      timestamp: Number(c.timestamp),
      note: c.note,
      transferred: ownerOf[i].toLowerCase() !== c.claimant.toLowerCase(),
      transfers: 0,
      custody: [c.claimant, ...(ownerOf[i] !== c.claimant ? [ownerOf[i]] : [])],
      conflict: false,
    }));

    const claimants = new Set(plots.map((p) => p.claimant.toLowerCase()));
    const conflict = claimants.size > 1;
    for (const p of plots) p.conflict = conflict;

    const status =
      plots.length === 0 ? "none" : conflict ? "conflict" : "single";

    return NextResponse.json({
      ok: true,
      status,
      count: plots.length,
      plots,
      explorer: EXPLORER,
    });
  } catch (e) {
    return NextResponse.json(
      { ok: false, error: e instanceof Error ? e.message : "check failed" },
      { status: 500 },
    );
  }
}
