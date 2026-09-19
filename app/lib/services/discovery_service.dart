import 'dart:async';

import '../models/device.dart';
import 'core_cli.dart';

/// Discovers Uncloud peers on the local network.
///
/// Demo mode fabricates sample peers so widget tests and first-run UI work
/// without the Node core. Desktop builds with a detected core poll
/// `uncloud scan --json`.
class DiscoveryService {
  DiscoveryService({this.demo = true, this.cli});

  final bool demo;
  final CoreCli? cli;

  final _peers = <PeerDevice>[];
  Timer? _timer;
  String _payload =
      'uncloud://pair/local-demo-device?name=This%20device&host=127.0.0.1&port=47778';

  /// Current demo peer list (read-only snapshot for controllers).
  List<PeerDevice> get demoPeers => List.unmodifiable(_peers);

  Future<void> refreshIdentity() async {
    if (cli == null) return;
    final info = await cli!.pairInfo();
    final payload = info?['payload'] as String?;
    if (payload != null && payload.isNotEmpty) {
      _payload = payload;
    }
  }

  /// Starts discovery; emits the current peer list on [onPeers].
  /// Demo mode emits once via microtask (no timers, so tests stay pumpable).
  void start(void Function(List<PeerDevice> peers) onPeers) {
    if (demo || cli == null) {
      _seedDemoPeers();
      scheduleMicrotask(() => onPeers(List.unmodifiable(_peers)));
      return;
    }
    Future<void> poll() async {
      final peers = await cli!.scan();
      _peers
        ..clear()
        ..addAll(peers);
      onPeers(List.unmodifiable(_peers));
    }

    poll();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Pairing QR / paste payload for this device.
  String localPairingPayload() => _payload;

  void _seedDemoPeers() {
    final now = DateTime.now();
    _peers
      ..clear()
      ..addAll([
        PeerDevice(
          deviceId: 'desk-pc-8f3a1c92',
          name: 'Desktop PC',
          host: '192.168.1.20',
          port: 47778,
          isPaired: true,
          lastSeen: now.subtract(const Duration(minutes: 1)),
          totalStorageBytes: 512 * 1024 * 1024 * 1024,
          usedStorageBytes: 210 * 1024 * 1024 * 1024,
        ),
        PeerDevice(
          deviceId: 'old-laptop-51be77d0',
          name: 'Living-room Laptop',
          host: '192.168.1.34',
          port: 47778,
          isPaired: false,
          lastSeen: now.subtract(const Duration(minutes: 3)),
          totalStorageBytes: 256 * 1024 * 1024 * 1024,
          usedStorageBytes: 96 * 1024 * 1024 * 1024,
        ),
        PeerDevice(
          deviceId: 'nas-box-c41d09ef',
          name: 'Home NAS',
          host: '192.168.1.50',
          port: 47778,
          isPaired: false,
          lastSeen: now.subtract(const Duration(hours: 26)),
          totalStorageBytes: 4 * 1024 * 1024 * 1024 * 1024,
          usedStorageBytes: 1900 * 1024 * 1024 * 1024,
        ),
      ]);
  }
}
