import 'package:flutter_test/flutter_test.dart';
import 'package:uncloud/sync/difference_hash.dart';

void main() {
  List<int> fill(int Function(int x) pixel) {
    return [for (var i = 0; i < 8 * 9; i++) pixel(i % 9)];
  }

  test('left-to-right gradient hashes to zero and the reverse to all bits', () {
    final brightening = fill((x) => x * 10);
    final darkening = fill((x) => (8 - x) * 10);

    final up = DifferenceHash.fromLuma(luma: brightening, width: 9, height: 8);
    final down = DifferenceHash.fromLuma(luma: darkening, width: 9, height: 8);
    expect(up, 0);
    expect(down, 0xFFFFFFFFFFFFFFFF);
    expect(DifferenceHash.hammingDistance(up, down), 64);
  });

  test('the first comparison is the high bit', () {
    final luma = fill((x) => x);
    luma[0] = 5;
    luma[1] = 0;
    final hash = DifferenceHash.fromLuma(luma: luma, width: 9, height: 8);
    expect(hash, 1 << 63);
    expect(DifferenceHash.hammingDistance(hash, 0), 1);
    expect(DifferenceHash.hammingDistance(0, 3), 2);
  });

  test('downsamples a larger grid and rejects a mismatched buffer', () {
    final luma = List<int>.filled(18 * 16, 0);
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 9; x++) {
        luma[y * 18 + x] = 255;
      }
    }
    final hash = DifferenceHash.fromLuma(luma: luma, width: 18, height: 16);
    expect(hash, isNonZero);
    expect(
      () => DifferenceHash.fromLuma(luma: [0, 1, 2], width: 2, height: 2),
      throwsArgumentError,
    );
  });

  test('hamming distance stays inside 64 bits for negative inputs', () {
    expect(DifferenceHash.hammingDistance(-1, 0), 64);
  });
}
