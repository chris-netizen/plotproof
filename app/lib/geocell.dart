/// PlotProof geocell utilities.
///
/// Snaps GPS coordinates to geohash cells and converts them to the
/// bytes32 cell ids the PlotProof contract uses as mapping keys.
///
/// Precision guide (cell size near the equator — Nigeria is close):
///   7 -> ~153m x 153m   (neighbourhood)
///   8 -> ~38m  x 19m    (plot scale)      <- default for PlotProof
///   9 -> ~4.8m x 4.8m   (spot scale)
///
/// A plot can straddle a cell boundary, so conflict checks must always
/// query the center cell AND its 8 neighbours (use [cellBlock]).
///
/// Pure Dart, no dependencies. The bytes32 encoding is the ASCII bytes
/// of the geohash string right-padded with zeros to 32 bytes — trivial
/// to reproduce in any language and cheap to compare on-chain.
library geocell;

import 'dart:typed_data';

const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
const int kPlotPrecision = 8;

/// Encode [lat], [lng] to a geohash string of [precision] characters.
String encodeGeohash(double lat, double lng, {int precision = kPlotPrecision}) {
  assert(lat >= -90 && lat <= 90, 'lat out of range');
  assert(lng >= -180 && lng <= 180, 'lng out of range');
  assert(precision > 0 && precision <= 22, 'precision out of range');

  double latMin = -90, latMax = 90;
  double lngMin = -180, lngMax = 180;

  final buf = StringBuffer();
  int bit = 0;
  int ch = 0;
  bool evenBit = true; // true = longitude bit, false = latitude bit

  while (buf.length < precision) {
    if (evenBit) {
      final mid = (lngMin + lngMax) / 2;
      if (lng >= mid) {
        ch = (ch << 1) | 1;
        lngMin = mid;
      } else {
        ch = ch << 1;
        lngMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (lat >= mid) {
        ch = (ch << 1) | 1;
        latMin = mid;
      } else {
        ch = ch << 1;
        latMax = mid;
      }
    }
    evenBit = !evenBit;

    if (++bit == 5) {
      buf.write(_base32[ch]);
      bit = 0;
      ch = 0;
    }
  }
  return buf.toString();
}

/// Decode a geohash to the (lat, lng) of its cell center.
({double lat, double lng}) decodeGeohash(String geohash) {
  final b = _bounds(geohash);
  return (
    lat: (b.latMin + b.latMax) / 2,
    lng: (b.lngMin + b.lngMax) / 2,
  );
}

/// Bounding box of a geohash cell. Useful for drawing the cell on a map.
({double latMin, double latMax, double lngMin, double lngMax}) boundsOf(
        String geohash) =>
    _bounds(geohash);

({double latMin, double latMax, double lngMin, double lngMax}) _bounds(
    String geohash) {
  double latMin = -90, latMax = 90;
  double lngMin = -180, lngMax = 180;
  bool evenBit = true;

  for (final c in geohash.toLowerCase().split('')) {
    final idx = _base32.indexOf(c);
    if (idx < 0) {
      throw ArgumentError('Invalid geohash character: $c');
    }
    for (int n = 4; n >= 0; n--) {
      final bit = (idx >> n) & 1;
      if (evenBit) {
        final mid = (lngMin + lngMax) / 2;
        if (bit == 1) {
          lngMin = mid;
        } else {
          lngMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (bit == 1) {
          latMin = mid;
        } else {
          latMax = mid;
        }
      }
      evenBit = !evenBit;
    }
  }
  return (latMin: latMin, latMax: latMax, lngMin: lngMin, lngMax: lngMax);
}

/// Adjacent cell in a direction: 'n', 's', 'e', 'w'.
///
/// Implemented by decoding to the cell center, stepping one cell-width
/// in the given direction, and re-encoding. Robust and easy to audit.
String neighbor(String geohash, String direction) {
  final b = _bounds(geohash);
  final latStep = b.latMax - b.latMin;
  final lngStep = b.lngMax - b.lngMin;
  var lat = (b.latMin + b.latMax) / 2;
  var lng = (b.lngMin + b.lngMax) / 2;

  switch (direction) {
    case 'n':
      lat += latStep;
    case 's':
      lat -= latStep;
    case 'e':
      lng += lngStep;
    case 'w':
      lng -= lngStep;
    default:
      throw ArgumentError('direction must be n/s/e/w');
  }

  // Wrap longitude; clamp latitude at the poles.
  if (lng > 180) lng -= 360;
  if (lng < -180) lng += 360;
  if (lat > 90 || lat < -90) return geohash; // no neighbour past a pole

  return encodeGeohash(lat, lng, precision: geohash.length);
}

/// The 3x3 block of cells around (and including) the cell containing
/// [lat], [lng]: [center, N, NE, E, SE, S, SW, W, NW].
///
/// This is what you pass to the contract's `claimCounts` /
/// `getClaimsBatch` so plots straddling a boundary still surface.
List<String> cellBlock(double lat, double lng,
    {int precision = kPlotPrecision}) {
  final c = encodeGeohash(lat, lng, precision: precision);
  final n = neighbor(c, 'n');
  final s = neighbor(c, 's');
  return <String>[
    c,
    n,
    neighbor(n, 'e'),
    neighbor(c, 'e'),
    neighbor(s, 'e'),
    s,
    neighbor(s, 'w'),
    neighbor(c, 'w'),
    neighbor(n, 'w'),
  ];
}

// -------------------------------------------------------------------
// bytes32 encoding (must match how the app writes cells on-chain)
// -------------------------------------------------------------------

/// Encode a geohash string as the bytes32 cell id used on-chain:
/// ASCII bytes, right-padded with zeros to 32 bytes.
Uint8List cellToBytes32(String geohash) {
  final codes = geohash.codeUnits;
  if (codes.length > 32) {
    throw ArgumentError('geohash too long for bytes32');
  }
  final out = Uint8List(32);
  out.setRange(0, codes.length, codes);
  return out;
}

/// Decode a bytes32 cell id back to its geohash string.
String bytes32ToCell(Uint8List b) {
  final end = b.indexOf(0);
  return String.fromCharCodes(b.sublist(0, end < 0 ? b.length : end));
}

/// Hex string (0x-prefixed) of a cell's bytes32 id — handy for
/// explorers and debugging.
String cellToHex(String geohash) {
  final b = cellToBytes32(geohash);
  final sb = StringBuffer('0x');
  for (final byte in b) {
    sb.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
