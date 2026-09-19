/// Small formatting helpers shared across the UI.
library;

/// Human readable byte size, e.g. `4.2 MB`.
String formatBytes(int bytes) {
  if (bytes < 0) return '0 B';
  const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

/// Human readable transfer speed, e.g. `12.5 MB/s`.
String formatSpeed(int bytesPerSecond) => '${formatBytes(bytesPerSecond)}/s';

/// Progress as a percentage string, e.g. `42%`.
String formatPercent(double progress) =>
    '${(progress.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%';
