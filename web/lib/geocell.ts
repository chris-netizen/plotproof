// Port of the app's geocell.dart so the website computes the SAME cells the
// contract uses. Geohash (base32), bytes32 = ASCII of the geohash right-padded.

const BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz";
export const PLOT_PRECISION = 8;

export function encodeGeohash(
  lat: number,
  lng: number,
  precision = PLOT_PRECISION,
): string {
  let latMin = -90,
    latMax = 90,
    lngMin = -180,
    lngMax = 180;
  let out = "";
  let bit = 0;
  let ch = 0;
  let evenBit = true; // longitude bit first

  while (out.length < precision) {
    if (evenBit) {
      const mid = (lngMin + lngMax) / 2;
      if (lng >= mid) {
        ch = (ch << 1) | 1;
        lngMin = mid;
      } else {
        ch = ch << 1;
        lngMax = mid;
      }
    } else {
      const mid = (latMin + latMax) / 2;
      if (lat >= mid) {
        ch = (ch << 1) | 1;
        latMin = mid;
      } else {
        ch = ch << 1;
        latMax = mid;
      }
    }
    evenBit = !evenBit;
    if (++bit === 5) {
      out += BASE32[ch];
      bit = 0;
      ch = 0;
    }
  }
  return out;
}

type Bounds = { latMin: number; latMax: number; lngMin: number; lngMax: number };

function bounds(geohash: string): Bounds {
  let latMin = -90,
    latMax = 90,
    lngMin = -180,
    lngMax = 180;
  let evenBit = true;
  for (const c of geohash.toLowerCase()) {
    const idx = BASE32.indexOf(c);
    if (idx < 0) throw new Error(`Invalid geohash char: ${c}`);
    for (let n = 4; n >= 0; n--) {
      const b = (idx >> n) & 1;
      if (evenBit) {
        const mid = (lngMin + lngMax) / 2;
        if (b === 1) lngMin = mid;
        else lngMax = mid;
      } else {
        const mid = (latMin + latMax) / 2;
        if (b === 1) latMin = mid;
        else latMax = mid;
      }
      evenBit = !evenBit;
    }
  }
  return { latMin, latMax, lngMin, lngMax };
}

export function decodeGeohash(geohash: string): { lat: number; lng: number } {
  const b = bounds(geohash);
  return { lat: (b.latMin + b.latMax) / 2, lng: (b.lngMin + b.lngMax) / 2 };
}

export function neighbor(geohash: string, dir: "n" | "s" | "e" | "w"): string {
  const b = bounds(geohash);
  const latStep = b.latMax - b.latMin;
  const lngStep = b.lngMax - b.lngMin;
  let lat = (b.latMin + b.latMax) / 2;
  let lng = (b.lngMin + b.lngMax) / 2;
  if (dir === "n") lat += latStep;
  else if (dir === "s") lat -= latStep;
  else if (dir === "e") lng += lngStep;
  else lng -= lngStep;
  if (lng > 180) lng -= 360;
  if (lng < -180) lng += 360;
  if (lat > 90 || lat < -90) return geohash;
  return encodeGeohash(lat, lng, geohash.length);
}

/** center + 8 neighbours (the block a conflict check must cover). */
export function cellBlock(
  lat: number,
  lng: number,
  precision = PLOT_PRECISION,
): string[] {
  const c = encodeGeohash(lat, lng, precision);
  const n = neighbor(c, "n");
  const s = neighbor(c, "s");
  return [
    c,
    n,
    neighbor(n, "e"),
    neighbor(c, "e"),
    neighbor(s, "e"),
    s,
    neighbor(s, "w"),
    neighbor(c, "w"),
    neighbor(n, "w"),
  ];
}

/** Neighbours of an existing cell string (for conflict grouping). */
export function neighboursOf(cell: string): string[] {
  const n = neighbor(cell, "n");
  const s = neighbor(cell, "s");
  return [
    cell,
    n,
    neighbor(n, "e"),
    neighbor(cell, "e"),
    neighbor(s, "e"),
    s,
    neighbor(s, "w"),
    neighbor(cell, "w"),
    neighbor(n, "w"),
  ];
}

/** bytes32 hex (0x..) of a geohash: ASCII bytes right-padded to 32. */
export function cellToHex(geohash: string): `0x${string}` {
  const bytes = new Uint8Array(32);
  for (let i = 0; i < geohash.length && i < 32; i++) {
    bytes[i] = geohash.charCodeAt(i);
  }
  let hex = "0x";
  for (const b of bytes) hex += b.toString(16).padStart(2, "0");
  return hex as `0x${string}`;
}

/** Decode a bytes32 hex cell id back to its geohash string. */
export function hexToCell(hex: string): string {
  const h = hex.startsWith("0x") ? hex.slice(2) : hex;
  let s = "";
  for (let i = 0; i < h.length; i += 2) {
    const code = parseInt(h.slice(i, i + 2), 16);
    if (code === 0) break;
    s += String.fromCharCode(code);
  }
  return s;
}
