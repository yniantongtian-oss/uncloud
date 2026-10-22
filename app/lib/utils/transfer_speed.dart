/// Bytes/second between two progress samples.
///
/// Returns null when the clock did not move. A rewind (retry, resume) is
/// 0 B/s rather than a negative rate.
double? transferSpeedBps({
  required int previousBytes,
  required int nextBytes,
  required Duration elapsed,
}) {
  final millis = elapsed.inMilliseconds;
  if (millis <= 0) return null;
  final delta = nextBytes - previousBytes;
  if (delta < 0) return 0;
  return delta / (millis / 1000.0);
}
