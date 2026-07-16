/// PlotProof evidence hashing.
///
/// The chain never sees the photo — only this hash. The exact byte
/// layout below is the canonical encoding for both *creating* a claim
/// and *verifying* evidence later, so never change it after deploying.
///
/// evidenceHash = keccak256(
///     photoBytes                       // raw file bytes, unmodified
///  || latE7  as int64  big-endian      // 8 bytes, two's complement
///  || lngE7  as int64  big-endian      // 8 bytes, two's complement
///  || tsUnix as uint64 big-endian      // 8 bytes (device time at capture)
///  || claimant address                 // 20 bytes
/// )
///
/// Requires: web3dart (for keccak256 + EthereumAddress).
library evidence;

import 'dart:typed_data';

import 'package:web3dart/crypto.dart' show keccak256;
import 'package:web3dart/web3dart.dart' show EthereumAddress;

/// Convert a double coordinate to its E7 fixed-point int (matches the
/// contract's int64 latE7/lngE7 fields).
int toE7(double coord) => (coord * 1e7).round();

Uint8List _int64BE(int value) {
  final b = ByteData(8);
  b.setInt64(0, value, Endian.big);
  return b.buffer.asUint8List();
}

Uint8List _uint64BE(int value) {
  final b = ByteData(8);
  b.setUint64(0, value, Endian.big);
  return b.buffer.asUint8List();
}

/// Build the canonical evidence hash for a claim.
///
/// [photoBytes]   raw bytes of the captured photo file
/// [latE7/lngE7]  fixed-point coordinates (use [toE7])
/// [tsUnixSecs]   capture time, unix seconds (store this locally with
///                the photo — you need it again to verify later)
/// [claimant]     the wallet address staking the claim
Uint8List evidenceHash({
  required Uint8List photoBytes,
  required int latE7,
  required int lngE7,
  required int tsUnixSecs,
  required EthereumAddress claimant,
}) {
  final builder = BytesBuilder(copy: false)
    ..add(photoBytes)
    ..add(_int64BE(latE7))
    ..add(_int64BE(lngE7))
    ..add(_uint64BE(tsUnixSecs))
    ..add(claimant.addressBytes);
  return keccak256(builder.takeBytes());
}

/// Sidecar metadata to save on-device next to each photo, so the
/// Verify flow can rebuild the exact same hash later. Serialize this
/// as JSON alongside the image file.
class EvidenceMeta {
  final int latE7;
  final int lngE7;
  final int tsUnixSecs;
  final String claimant; // 0x address
  final String cell; // geohash string
  final String note;

  const EvidenceMeta({
    required this.latE7,
    required this.lngE7,
    required this.tsUnixSecs,
    required this.claimant,
    required this.cell,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
        'latE7': latE7,
        'lngE7': lngE7,
        'tsUnixSecs': tsUnixSecs,
        'claimant': claimant,
        'cell': cell,
        'note': note,
        'v': 1,
      };

  factory EvidenceMeta.fromJson(Map<String, dynamic> j) => EvidenceMeta(
        latE7: j['latE7'] as int,
        lngE7: j['lngE7'] as int,
        tsUnixSecs: j['tsUnixSecs'] as int,
        claimant: j['claimant'] as String,
        cell: j['cell'] as String,
        note: j['note'] as String,
      );
}
