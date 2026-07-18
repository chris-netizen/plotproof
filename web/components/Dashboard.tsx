"use client";

import dynamic from "next/dynamic";
import { useMemo, useState } from "react";
import { cellBlock } from "@/lib/geocell";
import { coord, fullDate, shortAddr, timeAgo } from "@/lib/format";
import type { Activity, ClaimsData, Plot } from "@/lib/types";

const PlotsMap = dynamic(() => import("./PlotsMap"), {
  ssr: false,
  loading: () => <div className="empty">Loading map…</div>,
});

type CheckResult =
  | { kind: "none" }
  | { kind: "single"; owner: string }
  | { kind: "conflict"; count: number }
  | null;

export default function Dashboard({ data }: { data: ClaimsData }) {
  const { plots, activity, analytics, explorer, contract } = data;
  const [region, setRegion] = useState<string | null>(null);
  const [selected, setSelected] = useState<Plot | null>(null);
  const [checkPoint, setCheckPoint] = useState<{
    lat: number;
    lng: number;
  } | null>(null);
  const [checkResult, setCheckResult] = useState<CheckResult>(null);
  const [checkInput, setCheckInput] = useState("");

  const filtered = useMemo(
    () => (region ? plots.filter((p) => p.cell.startsWith(region)) : plots),
    [plots, region],
  );

  const shownActivity = useMemo(() => {
    const list: Activity[] = region
      ? activity.filter((a) =>
          filtered.some((p) => p.cell === a.cell),
        )
      : activity;
    return list.slice(0, 40);
  }, [activity, filtered, region]);

  function runCheck(lat: number, lng: number) {
    setCheckPoint({ lat, lng });
    const cells = new Set(cellBlock(lat, lng));
    const here = plots.filter((p) => cells.has(p.cell));
    if (here.length === 0) {
      setCheckResult({ kind: "none" });
      return;
    }
    const claimants = new Set(here.map((p) => p.claimant.toLowerCase()));
    if (claimants.size > 1) {
      setCheckResult({ kind: "conflict", count: here.length });
    } else {
      setCheckResult({ kind: "single", owner: here[0].owner });
    }
  }

  function submitCheckInput() {
    const m = checkInput.split(/[,\s]+/).map((x) => parseFloat(x.trim()));
    if (m.length >= 2 && Number.isFinite(m[0]) && Number.isFinite(m[1])) {
      runCheck(m[0], m[1]);
    } else {
      setCheckResult(null);
      setCheckPoint(null);
    }
  }

  const selectedCell = selected
    ? `${selected.cellHex}:${selected.index}`
    : null;

  return (
    <>
      {analytics.regions.length > 1 && (
        <div className="filters">
          <button
            className={`chip ${region === null ? "active" : ""}`}
            onClick={() => setRegion(null)}
          >
            All areas<span className="count">{plots.length}</span>
          </button>
          {analytics.regions.slice(0, 8).map((r) => (
            <button
              key={r.key}
              className={`chip ${region === r.key ? "active" : ""}`}
              onClick={() => setRegion(r.key)}
            >
              {r.label.length > 22 ? r.label.slice(0, 22) + "…" : r.label}
              <span className="count">{r.count}</span>
            </button>
          ))}
        </div>
      )}

      <div className="grid-main">
        <div className="card" style={{ overflow: "hidden" }}>
          <div className="map-wrap">
            <PlotsMap
              plots={filtered}
              selectedCell={selectedCell}
              checkPoint={checkPoint}
              onSelectPlot={setSelected}
              onCheckPoint={runCheck}
            />
            <div className="map-hint">Tap anywhere to check that spot</div>
            <div className="map-legend">
              <div className="legend-row">
                <span
                  className="legend-swatch"
                  style={{ background: "#0f7a3d" }}
                />
                Claimed
              </div>
              <div className="legend-row">
                <span
                  className="legend-swatch"
                  style={{ background: "#4f46e5" }}
                />
                Sold / transferred
              </div>
              <div className="legend-row">
                <span
                  className="legend-swatch"
                  style={{ background: "#d92d20" }}
                />
                Competing claims
              </div>
            </div>
          </div>
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: 20 }}>
          <div className="card">
            <div className="card-head">
              <h3>Check a plot before you pay</h3>
            </div>
            <div className="card-pad">
              <div className="check-box">
                <input
                  placeholder="Paste coordinates, e.g. 6.4402, 7.4943"
                  value={checkInput}
                  onChange={(e) => setCheckInput(e.target.value)}
                  onKeyDown={(e) => e.key === "Enter" && submitCheckInput()}
                />
                <button className="btn btn-primary" onClick={submitCheckInput}>
                  Check
                </button>
              </div>
              {checkResult && (
                <div
                  className={`check-result ${
                    checkResult.kind === "conflict" ? "warn" : "ok"
                  }`}
                >
                  {checkResult.kind === "none" &&
                    "✓ No claim on record for this spot yet."}
                  {checkResult.kind === "single" && (
                    <>
                      This plot is already claimed. Current owner{" "}
                      <span className="mono">
                        {shortAddr(checkResult.owner)}
                      </span>
                      . Its record is on-chain.
                    </>
                  )}
                  {checkResult.kind === "conflict" &&
                    `⚠ Competing claims here (${checkResult.count}) — possible double sale. Do not pay without resolving.`}
                </div>
              )}
            </div>
          </div>

          <div className="card">
            <div className="card-head">
              <h3>Live activity</h3>
              <span className="badge ok">on-chain</span>
            </div>
            <div className="feed">
              {shownActivity.length === 0 && (
                <div className="empty">No activity yet.</div>
              )}
              {shownActivity.map((a, i) => (
                <a
                  key={i}
                  className="feed-item"
                  href={a.txHash ? `${explorer}/tx/${a.txHash}` : undefined}
                  target="_blank"
                  rel="noreferrer"
                  style={{ color: "inherit", textDecoration: "none" }}
                >
                  <div className={`feed-ic ${a.kind}`}>
                    {a.kind === "stake" ? "📍" : "↔"}
                  </div>
                  <div className="feed-main">
                    <div className="feed-title">
                      {a.kind === "stake"
                        ? a.note || "New plot claimed"
                        : "Claim transferred"}
                    </div>
                    <div className="feed-sub">
                      {a.kind === "stake" ? (
                        <>by {shortAddr(a.actor)}</>
                      ) : (
                        <>
                          {shortAddr(a.from)} → {shortAddr(a.to)}
                        </>
                      )}
                    </div>
                  </div>
                  <div className="feed-time">{timeAgo(a.timestamp)}</div>
                </a>
              ))}
            </div>
          </div>
        </div>
      </div>

      {selected && (
        <PlotModal
          plot={selected}
          explorer={explorer}
          contract={contract}
          onClose={() => setSelected(null)}
          onCheck={() => {
            runCheck(selected.lat, selected.lng);
            setSelected(null);
          }}
        />
      )}
    </>
  );
}

function PlotModal({
  plot,
  explorer,
  contract,
  onClose,
  onCheck,
}: {
  plot: Plot;
  explorer: string;
  contract: string;
  onClose: () => void;
  onCheck: () => void;
}) {
  return (
    <div className="modal-scrim" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <div>
            <div style={{ fontSize: 17, fontWeight: 800 }}>
              {plot.note || "Unlabelled plot"}
            </div>
            <div style={{ marginTop: 6, display: "flex", gap: 6 }}>
              {plot.conflict ? (
                <span className="badge conflict">⚠ Competing claims</span>
              ) : (
                <span className="badge ok">✓ Single claim</span>
              )}
              {plot.transferred && <span className="badge sold">Sold</span>}
            </div>
          </div>
          <button className="icon-btn" onClick={onClose}>
            ✕
          </button>
        </div>
        <div className="modal-body">
          <div className="kv">
            <span className="k">Location</span>
            <span className="v mono">{coord(plot.lat, plot.lng)}</span>
          </div>
          <div className="kv">
            <span className="k">Geocell</span>
            <span className="v mono">{plot.cell}</span>
          </div>
          <div className="kv">
            <span className="k">Claimed</span>
            <span className="v">{fullDate(plot.timestamp)}</span>
          </div>
          <div className="kv">
            <span className="k">Original claimant</span>
            <a
              className="v mono"
              href={`${explorer}/address/${plot.claimant}`}
              target="_blank"
              rel="noreferrer"
            >
              {shortAddr(plot.claimant)}
            </a>
          </div>
          <div className="kv">
            <span className="k">Current owner</span>
            <a
              className="v mono"
              href={`${explorer}/address/${plot.owner}`}
              target="_blank"
              rel="noreferrer"
            >
              {shortAddr(plot.owner)}
            </a>
          </div>

          <div style={{ marginTop: 14, marginBottom: 6, fontWeight: 700 }}>
            Chain of custody
          </div>
          <div className="custody">
            {plot.custody.map((o, i) => (
              <span key={i} style={{ display: "contents" }}>
                {i > 0 && <span className="arrow">→</span>}
                <span className="node mono">{shortAddr(o)}</span>
              </span>
            ))}
          </div>

          <div style={{ display: "flex", gap: 10, marginTop: 20 }}>
            <button className="btn btn-primary" onClick={onCheck}>
              Check this spot
            </button>
            <a
              className="btn btn-ghost"
              href={`${explorer}/address/${contract}`}
              target="_blank"
              rel="noreferrer"
            >
              View on Monad
            </a>
          </div>
        </div>
      </div>
    </div>
  );
}
