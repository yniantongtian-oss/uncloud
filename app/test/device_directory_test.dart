import 'package:flutter_test/flutter_test.dart';
import 'package:uncloud/models/device.dart';
import 'package:uncloud/models/device_directory.dart';

void main() {
  final earlier = DateTime.utc(2026, 1, 1, 12);
  final later = earlier.add(const Duration(minutes: 10));

  PeerDevice peer(
    String id,
    String name, {
    bool paired = false,
    DateTime? seen,
    int total = 0,
    int used = 0,
    String host = '192.168.1.20',
  }) {
    return PeerDevice(
      deviceId: id,
      name: name,
      host: host,
      port: 47778,
      isPaired: paired,
      lastSeen: seen ?? earlier,
      totalStorageBytes: total,
      usedStorageBytes: used,
    );
  }

  test('drops unpaired peers that leave the scan and keeps paired ones', () {
    final directory = DeviceDirectory()
      ..applyDiscovery([peer('a', 'Alpha'), peer('b', 'Beta')]);
    directory.pair(peer('a', 'Alpha', paired: true, seen: later));
    directory.applyDiscovery([peer('b', 'Beta', seen: later)]);

    expect(directory.paired.map((device) => device.deviceId), ['a']);
    expect(directory.discoveredUnpaired.map((device) => device.deviceId), [
      'b',
    ]);
  });

  test('a later announce cannot undo unpair or wipe known storage', () {
    final directory = DeviceDirectory()
      ..restore([
        peer('a', 'Alpha', paired: true, total: 100, used: 40, seen: later),
      ]);
    directory.unpair('a');
    directory.applyDiscovery([peer('a', 'Alpha', paired: true, seen: earlier)]);

    final device = directory.devices.single;
    expect(device.isPaired, isFalse);
    expect(device.totalStorageBytes, 100);
    expect(device.usedStorageBytes, 40);
    expect(device.lastSeen, later);
  });

  test('primary backup target is the most recently seen paired device', () {
    final directory = DeviceDirectory()
      ..restore([
        peer('z', 'Zed', paired: true, seen: later),
        peer('a', 'Amy', paired: true, seen: earlier),
      ]);
    expect(directory.primaryBackupTarget?.deviceId, 'z');
    expect(directory.devices.map((device) => device.name), ['Amy', 'Zed']);
  });
}
