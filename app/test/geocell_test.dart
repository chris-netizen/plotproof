import 'package:flutter_test/flutter_test.dart';
import 'package:plotproof/geocell.dart';

void main() {
  group('geohash encode/decode', () {
    test('decode(encode(p)) returns a point inside the same cell', () {
      const lat = 6.4402, lng = 7.4943;
      final gh = encodeGeohash(lat, lng);
      final b = boundsOf(gh);
      expect(lat, inInclusiveRange(b.latMin, b.latMax));
      expect(lng, inInclusiveRange(b.lngMin, b.lngMax));
    });

    test('default precision is plot scale (8 chars)', () {
      expect(encodeGeohash(6.4402, 7.4943).length, kPlotPrecision);
      expect(kPlotPrecision, 8);
    });

    test('nearby points collapse to the same cell', () {
      final a = encodeGeohash(6.44020, 7.49430);
      final b = encodeGeohash(6.44021, 7.49431); // ~1m away
      expect(a, b);
    });
  });

  group('cellBlock', () {
    test('returns the centre plus 8 neighbours', () {
      final block = cellBlock(6.4402, 7.4943);
      expect(block.length, 9);
      expect(block.toSet().length, 9, reason: 'all cells should be distinct');
      expect(block.first, encodeGeohash(6.4402, 7.4943));
    });
  });

  group('bytes32 cell encoding', () {
    test('round-trips through bytes32', () {
      final gh = encodeGeohash(6.4402, 7.4943);
      final b = cellToBytes32(gh);
      expect(b.length, 32);
      expect(bytes32ToCell(b), gh);
    });

    test('hex encoding is 0x + 64 chars', () {
      final hex = cellToHex(encodeGeohash(6.4402, 7.4943));
      expect(hex.startsWith('0x'), isTrue);
      expect(hex.length, 66);
    });
  });
}
