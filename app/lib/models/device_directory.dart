import 'device.dart';

/// In-memory peer table: persisted pairs merged with the latest discovery scan.
///
/// Unpaired devices that disappear from a scan are dropped. Paired devices
/// stay, and a later announce cannot undo an unpair or wipe storage and key
/// material the scan does not repeat.
class DeviceDirectory {
  final Map<String, PeerDevice> _devices = {};

  List<PeerDevice> get devices =>
      _devices.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  List<PeerDevice> get paired =>
      devices.where((device) => device.isPaired).toList(growable: false);

  List<PeerDevice> get discoveredUnpaired =>
      devices.where((device) => !device.isPaired).toList(growable: false);

  /// The paired peer seen most recently. Ties break by device id.
  PeerDevice? get primaryBackupTarget {
    PeerDevice? best;
    for (final device in _devices.values) {
      if (!device.isPaired) continue;
      if (best == null) {
        best = device;
        continue;
      }
      final seenAfter = device.lastSeen.isAfter(best.lastSeen);
      final sameTime =
          device.lastSeen == best.lastSeen &&
          device.deviceId.compareTo(best.deviceId) < 0;
      if (seenAfter || sameTime) best = device;
    }
    return best;
  }

  void restore(Iterable<PeerDevice> saved) {
    for (final device in saved) {
      if (device.deviceId.isEmpty) continue;
      _devices[device.deviceId] = device;
    }
  }

  void applyDiscovery(List<PeerDevice> seen) {
    final seenIds = <String>{};
    for (final peer in seen) {
      if (peer.deviceId.isEmpty) continue;
      seenIds.add(peer.deviceId);
      _devices[peer.deviceId] = _merge(_devices[peer.deviceId], peer);
    }
    final stale = [
      for (final entry in _devices.entries)
        if (!entry.value.isPaired && !seenIds.contains(entry.key)) entry.key,
    ];
    for (final id in stale) {
      _devices.remove(id);
    }
  }

  void pair(PeerDevice device) {
    final existing = _devices[device.deviceId];
    _devices[device.deviceId] = device.copyWith(
      isPaired: true,
      publicKey: device.publicKey ?? existing?.publicKey,
      totalStorageBytes: device.totalStorageBytes > 0
          ? device.totalStorageBytes
          : existing?.totalStorageBytes ?? 0,
      usedStorageBytes: device.usedStorageBytes > 0
          ? device.usedStorageBytes
          : existing?.usedStorageBytes ?? 0,
    );
  }

  void unpair(String deviceId) {
    final existing = _devices[deviceId];
    if (existing == null) return;
    _devices[deviceId] = existing.copyWith(isPaired: false);
  }

  PeerDevice _merge(PeerDevice? existing, PeerDevice incoming) {
    if (existing == null) return incoming;
    final incomingStorageKnown = incoming.totalStorageBytes > 0;
    return incoming.copyWith(
      isPaired: existing.isPaired,
      publicKey: incoming.publicKey ?? existing.publicKey,
      totalStorageBytes: incomingStorageKnown
          ? incoming.totalStorageBytes
          : existing.totalStorageBytes,
      usedStorageBytes: incomingStorageKnown
          ? incoming.usedStorageBytes
          : existing.usedStorageBytes,
      lastSeen: _later(existing.lastSeen, incoming.lastSeen),
      host: incoming.host.isNotEmpty ? incoming.host : existing.host,
    );
  }

  DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
}
