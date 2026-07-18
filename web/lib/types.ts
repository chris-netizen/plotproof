export type Plot = {
  cell: string; // geohash string
  cellHex: string; // bytes32 hex
  index: number; // position within its cell
  claimant: string; // original staker
  owner: string; // current owner
  lat: number;
  lng: number;
  timestamp: number; // unix seconds (claim time)
  note: string;
  transferred: boolean;
  transfers: number; // how many times sold
  custody: string[]; // [claimant, owner1, owner2, ...]
  conflict: boolean; // competing claim on this or an adjacent cell
};

export type Activity =
  | {
      kind: "stake";
      timestamp: number;
      cell: string;
      actor: string; // claimant
      note: string;
      txHash: string;
      block: number;
    }
  | {
      kind: "transfer";
      timestamp: number;
      cell: string;
      from: string;
      to: string;
      txHash: string;
      block: number;
    };

export type RegionStat = {
  key: string; // coarse geohash prefix
  label: string; // representative label
  count: number;
  conflicts: number;
};

export type DayBucket = { date: string; count: number };

export type Analytics = {
  totalPlots: number;
  totalSales: number;
  conflicts: number;
  owners: number;
  byDay: DayBucket[];
  regions: RegionStat[];
};

export type ClaimsData = {
  ok: boolean;
  error?: string;
  updatedAt: number;
  contract: string;
  explorer: string;
  plots: Plot[];
  activity: Activity[];
  analytics: Analytics;
};
