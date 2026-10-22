/// 64-bit difference hash (dHash) over a grayscale image.
///
/// The grid is box-downsampled to 9×8. Each of the 8×8 adjacent pairs sets a
/// bit when the left sample is strictly brighter than the right. Bit 63 is the
/// top-left comparison. Nothing here touches the network.
class DifferenceHash {
  const DifferenceHash._();

  static const int sampleWidth = 9;
  static const int sampleHeight = 8;

  static int fromLuma({
    required List<int> luma,
    required int width,
    required int height,
  }) {
    if (width < 2 || height < 1) {
      throw ArgumentError('luma grid must be at least 2×1');
    }
    if (luma.length != width * height) {
      throw ArgumentError('luma length must equal width * height');
    }
    final small = _downsample(luma, width, height, sampleWidth, sampleHeight);
    var hash = 0;
    for (var y = 0; y < sampleHeight; y++) {
      for (var x = 0; x < sampleWidth - 1; x++) {
        final left = small[y * sampleWidth + x];
        final right = small[y * sampleWidth + x + 1];
        hash = (hash << 1) | (left > right ? 1 : 0);
      }
    }
    // Shifts wrap at 64 bits, so this is already the low 64 bits.
    // All-ones is -1, which is the same value as 0xFFFFFFFFFFFFFFFF.
    return hash;
  }

  /// Hamming distance over 64 bits.
  ///
  /// Dart ints are 64-bit two's complement. An arithmetic `>>` of a negative
  /// value sign-extends and never reaches zero, so this counts a fixed width
  /// with an unsigned shift.
  static int hammingDistance(int a, int b) {
    var bits = a ^ b;
    var count = 0;
    for (var i = 0; i < 64; i++) {
      count += bits & 1;
      bits = bits >>> 1;
    }
    return count;
  }

  static List<int> _downsample(
    List<int> source,
    int sourceWidth,
    int sourceHeight,
    int targetWidth,
    int targetHeight,
  ) {
    if (sourceWidth == targetWidth && sourceHeight == targetHeight) {
      return List<int>.from(source);
    }
    final output = List<int>.filled(targetWidth * targetHeight, 0);
    for (var y = 0; y < targetHeight; y++) {
      final y0 = (y * sourceHeight) ~/ targetHeight;
      var y1 = ((y + 1) * sourceHeight) ~/ targetHeight;
      if (y1 <= y0) y1 = y0 + 1;
      if (y1 > sourceHeight) y1 = sourceHeight;
      for (var x = 0; x < targetWidth; x++) {
        final x0 = (x * sourceWidth) ~/ targetWidth;
        var x1 = ((x + 1) * sourceWidth) ~/ targetWidth;
        if (x1 <= x0) x1 = x0 + 1;
        if (x1 > sourceWidth) x1 = sourceWidth;
        var sum = 0;
        var count = 0;
        for (var yy = y0; yy < y1; yy++) {
          for (var xx = x0; xx < x1; xx++) {
            sum += source[yy * sourceWidth + xx];
            count++;
          }
        }
        output[y * targetWidth + x] = count == 0 ? 0 : sum ~/ count;
      }
    }
    return output;
  }
}
