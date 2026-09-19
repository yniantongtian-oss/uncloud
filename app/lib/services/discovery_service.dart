import 'dart:async';

import '../models/device.dart';

/// Discovers Uncloud peers on the local network.
///
/// Production plan: the `uncloud` core (Rust/Node sidecar) does mDNS/UDP
/// broadcast discovery; on desktop this service shells out to the core CLI,
/// on mobile it talks over a MethodChannel (`uncloud/discovery`).
///
/// In demo mode ([demo]) it fabricates a few sample peers so the whole app
/// runs standalone with no core present.
class DiscoveryService {
  DiscoveryService({this.demo = true});

  final bool demo;

  final _peers = <PeerDevice>[];

  /// Current demo peer list (read-only snapshot for controllers).
  List<PeerDevice> get demoPeers => List.unmodifiable(_peers);

  /// Starts discovery; emits the current peer list on [onPeers].
  /// Demo mode emits once via microtask (no timers, so tests stay pumpable).
  void start(void Function(List<PeerDevice> peers) onPeers) {
    if (demo) {
      _seedDemoPeers();
      scheduleMicrotask(() => onPeers(List.unmodifiable(_peers)));
      return;
    }
    // TODO(core integration): invoke platform channel / spawn `uncloud discover`
    // and stream JSON lines into PeerDevice.fromJson. Demo path above keeps the
    // app fully functional until the core is wired in.
  }

  void stop() {
    // No-op in demo mode; kept for symmetry with the future core-backed
    // implementation which will own sockets/timers.
  }

  /// The payload this device broadcasts / encodes in its pairing QR.
  /// Format: `uncloud://pair/<deviceId>?name=..&host=..&port=..`
  String localPairingPayload() {
    final name = Uri.encodeComponent('This device');
    return 'uncloud://pair/local-demo-device?name=$name&host=192.168.1.10&port=47777';
  }

  void _seedDemoPeers() {
    final now = DateTime.now();
    _peers
      ..clear()
      ..addAll([
        PeerDevice(
          deviceId: 'desk-pc-8f3a1c92',
          name: 'Desktop PC',
          host: '192.168.1.20',
          port: 47777,
          isPaired: true,
          lastSeen: now.subtract(const Duration(minutes: 1)),
          totalStorageBytes: 512 * 1024 * 1024 * 1024,
          usedStorageBytes: 210 * 1024 * 1024 * 1024,
        ),
        PeerDevice(
          deviceId: 'old-laptop-51be77d0',
          name: 'Living-room Laptop',
          host: '192.168.1.34',
          port: 47777,
          isPaired: false,
          lastSeen: now.subtract(const Duration(minutes: 3)),
          totalStorageBytes: 256 * 1024 * 1024 * 1024,
          usedStorageBytes: 96 * 1024 * 1024 * 1024,
        ),
        PeerDevice(
          deviceId: 'nas-box-c41d09ef',
          name: 'Home NAS',
          host: '192.168.1.50',
          port: 47777,
          isPaired: false,
          lastSeen: now.subtract(const Duration(hours: 26)),
          totalStorageBytes: 4 * 1024 * 1024 * 1024 * 1024,
          usedStorageBytes: 1900 * 1024 * 1024 * 1024,
        ),
      ]);
  }
}
