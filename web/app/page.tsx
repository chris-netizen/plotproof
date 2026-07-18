import Dashboard from "@/components/Dashboard";
import { getClaimsData } from "@/lib/claims";
import { shortAddr } from "@/lib/format";
import type { DayBucket } from "@/lib/types";

export const dynamic = "force-dynamic";
export const maxDuration = 30;

const REPO = "https://github.com/chris-netizen/plotproof";

export default async function Home() {
  const data = await getClaimsData();
  const a = data.analytics;

  return (
    <>
      <header className="site-header">
        <div className="container inner">
          <div className="brand">
            <span className="brand-mark">◈</span>
            PlotProof
            <span className="header-tag">Monad</span>
          </div>
          <nav className="header-links">
            <a href="#map">Map</a>
            <a href="#how">How it works</a>
            <a
              href={`${data.explorer}/address/${data.contract}`}
              target="_blank"
              rel="noreferrer"
            >
              Contract
            </a>
            <a className="btn btn-primary" href={REPO} target="_blank" rel="noreferrer">
              GitHub
            </a>
          </nav>
        </div>
      </header>

      <section className="hero">
        <div className="container">
          <h1>
            Every land claim on Monad, <span className="accent">on one map.</span>
          </h1>
          <p className="lede">
            Land fraud thrives on secrecy — the same plot sold twice, papers no
            one can verify. PlotProof puts every claim on a public, tamper-proof
            map. See who claimed a plot, when, and whether anyone else is
            claiming it too. <strong>Check before you pay.</strong>
          </p>
          <div className="hero-cta">
            <a className="btn btn-primary" href="#map">
              Explore the map
            </a>
            <a className="btn btn-ghost" href={REPO} target="_blank" rel="noreferrer">
              View the code
            </a>
            <span className="pill-note">
              <span className="dot live" /> {a.totalPlots} plots protected · live
              from chain
            </span>
          </div>
        </div>
      </section>

      <section className="container">
        <div className="stats">
          <Stat label="Plots protected" value={a.totalPlots} sub="on-chain records" accent />
          <Stat label="Sales tracked" value={a.totalSales} sub="ownership transfers" />
          <Stat
            label="Conflicts flagged"
            value={a.conflicts}
            sub="possible double sales"
            danger
          />
          <Stat label="Owners" value={a.owners} sub="unique wallets" />
        </div>
        {!data.ok && (
          <div className="banner">
            Couldn’t read the chain right now{data.error ? `: ${data.error}` : ""}.
            Showing what’s available — check the RPC settings.
          </div>
        )}
        {data.ok && a.totalPlots === 0 && (
          <div className="banner">
            No claims found yet. If you’ve just deployed, stake a claim from the
            app — it will appear here within ~30s. (Tip: set{" "}
            <span className="mono">PLOTPROOF_DEPLOY_BLOCK</span> so scans stay
            fast.)
          </div>
        )}
      </section>

      <section className="section" id="map">
        <div className="container">
          <h2 className="section-title">The registry, live</h2>
          <p className="section-sub">
            Green plots are claimed, indigo have been sold, red have competing
            claims. Tap a plot for its history, or tap anywhere to check a spot.
          </p>
          <Dashboard data={data} />
        </div>
      </section>

      {a.byDay.length > 0 && (
        <section className="section">
          <div className="container">
            <div className="card">
              <div className="card-head">
                <h3>Claims over time</h3>
                <span className="badge ok">{a.totalPlots} total</span>
              </div>
              <div className="card-pad">
                <Timeline byDay={a.byDay} />
              </div>
            </div>
          </div>
        </section>
      )}

      <section className="section" id="how">
        <div className="container">
          <h2 className="section-title">How it works</h2>
          <p className="section-sub">
            Owners and surveyors record claims from the mobile app. Anyone
            verifies them here.
          </p>
          <div className="how">
            <Step
              n={1}
              title="Stake a claim"
              body="Standing on the plot, the owner captures a photo, GPS and time — plus optional title/survey documents. A hash of that evidence is anchored on Monad, tamper-evident and public."
            />
            <Step
              n={2}
              title="Sell with a trail"
              body="When the plot is sold, ownership transfers on-chain — a verifiable A → B chain of custody, gated by the owner’s fingerprint."
            />
            <Step
              n={3}
              title="Check before you pay"
              body="Buyers and lawyers look up any plot here. Two people claiming the same spot? It’s flagged as a possible double sale."
            />
          </div>
        </div>
      </section>

      <footer className="site-footer">
        <div className="container">
          <div style={{ fontWeight: 800, color: "var(--ink)" }}>
            PlotProof · on Monad testnet
          </div>
          <div style={{ marginTop: 6 }}>
            Contract{" "}
            <a
              className="mono"
              href={`${data.explorer}/address/${data.contract}`}
              target="_blank"
              rel="noreferrer"
            >
              {shortAddr(data.contract)}
            </a>{" "}
            · data read live from chain events · not legal title — a public
            evidence layer.
          </div>
        </div>
      </footer>
    </>
  );
}

function Stat({
  label,
  value,
  sub,
  accent,
  danger,
}: {
  label: string;
  value: number;
  sub: string;
  accent?: boolean;
  danger?: boolean;
}) {
  return (
    <div className={`stat ${accent ? "accent" : ""} ${danger ? "danger" : ""}`}>
      <div className="label">{label}</div>
      <div className="value">{value.toLocaleString()}</div>
      <div className="sub">{sub}</div>
    </div>
  );
}

function Step({ n, title, body }: { n: number; title: string; body: string }) {
  return (
    <div className="step">
      <div className="num">{n}</div>
      <h4>{title}</h4>
      <p>{body}</p>
    </div>
  );
}

function Timeline({ byDay }: { byDay: DayBucket[] }) {
  const days = byDay.slice(-30);
  const max = Math.max(1, ...days.map((d) => d.count));
  return (
    <>
      <div className="chart">
        {days.map((d) => (
          <div
            key={d.date}
            className="bar"
            style={{ height: `${(d.count / max) * 100}%` }}
            title={`${d.date}: ${d.count}`}
          />
        ))}
      </div>
      <div className="chart-axis">
        <span>{days[0]?.date}</span>
        <span>{days[days.length - 1]?.date}</span>
      </div>
    </>
  );
}
