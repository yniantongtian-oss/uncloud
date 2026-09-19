import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/device.dart';
import '../services/discovery_service.dart';
import '../services/pairing_service.dart';

/// Holds the known peer devices: discovered on LAN + persisted paired ones.
class DevicesController extends ChangeNotifier {
  DevicesController({
    DiscoveryService? discovery,
    PairingService? pairing,
  })  : _discovery = discovery ?? DiscoveryService(),
        _pairing = pairing ?? PairingService() {
    _init();
  }

  final DiscoveryService _discovery;
  final PairingService _pairing;

  final Map<String, PeerDevice> _devices = {};

  List<PeerDevice> get devices =>
      _devices.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<PeerDevice> get paired =>
      devices.where((d) => d.isPaired).toList(growable: false);

  List<PeerDevice> get discoveredUnpaired =>
      devices.where((d) => !d.isPaired).toList(growable: false);

  PeerDevice? get primaryBackupTarget {
    final p = paired;
    return p.isEmpty ? null : p.first;
  }

  Future<void> _init() async {
    await _discovery.refreshIdentity();
    // Restore persisted paired devices first.
    for (final d in await _pairing.loadPaired()) {
      _devices[d.deviceId] = d;
    }
    notifyListeners();
    // Then merge live discovery results.
    _discovery.start((peers) {
      for (final peer in peers) {
        final existing = _devices[peer.deviceId];
        _devices[peer.deviceId] = peer.copyWith(
          isPaired: existing?.isPaired ?? peer.isPaired,
        );
      }
      notifyListeners();
    });
    // Fallback poll in case the service's callback is missed. Uses a single
    // microtask-triggered re-read, not a periodic timer, so widget tests stay
    // pumpable (pumpAndSettle completes).
    Future<void>.delayed(Duration.zero, () {
      for (final peer in _discovery.demoPeers) {
        final existing = _devices[peer.deviceId];
        _devices[peer.deviceId] = peer.copyWith(
          isPaired: existing?.isPaired ?? peer.isPaired,
        );
      }
      notifyListeners();
    });
  }

  /// Pairs with a device (from discovery list or a scanned QR payload).
  Future<void> pair(PeerDevice device) async {
    final paired = device.copyWith(isPaired: true, lastSeen: DateTime.now());
    _devices[device.deviceId] = paired;
    notifyListeners();
    await _pairing.storePaired(paired);
  }

  /// Handles a raw `uncloud://` QR payload. Returns the paired device, or
  /// null when the payload is invalid.
  Future<PeerDevice?> pairFromPayload(String raw) async {
    final device = _pairing.parsePayload(raw);
    if (device == null) return null;
    await pair(device);
    return device;
  }

  Future<void> unpair(String deviceId) async {
    final existing = _devices[deviceId];
    if (existing != null) {
      _devices[deviceId] = existing.copyWith(isPaired: false);
    }
    notifyListeners();
    await _pairing.removePaired(deviceId);
  }

  String get localPairingPayload => _discovery.localPairingPayload();

  @override
  void dispose() {
    _discovery.stop();
    super.dispose();
  }
}
