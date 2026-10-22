import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/device.dart';
import '../models/device_directory.dart';
import '../services/discovery_service.dart';
import '../services/pairing_service.dart';

/// Holds the known peer devices: discovered on LAN + persisted paired ones.
class DevicesController extends ChangeNotifier {
  DevicesController({
    DiscoveryService? discovery,
    PairingService? pairing,
    DeviceDirectory? directory,
  }) : _discovery = discovery ?? DiscoveryService(),
       _pairing = pairing ?? PairingService(),
       _directory = directory ?? DeviceDirectory() {
    unawaited(_init());
  }

  final DiscoveryService _discovery;
  final PairingService _pairing;
  final DeviceDirectory _directory;
  bool _disposed = false;

  List<PeerDevice> get devices => _directory.devices;

  List<PeerDevice> get paired => _directory.paired;

  List<PeerDevice> get discoveredUnpaired => _directory.discoveredUnpaired;

  PeerDevice? get primaryBackupTarget => _directory.primaryBackupTarget;

  Future<void> _init() async {
    await _discovery.refreshIdentity();
    if (_disposed) return;
    _directory.restore(await _pairing.loadPaired());
    if (_disposed) return;
    _notify();
    _discovery.start((peers) {
      if (_disposed) return;
      _directory.applyDiscovery(peers);
      _notify();
    });
    // One extra read in case the service callback is missed. A single
    // zero-delay future keeps widget tests pumpable (no periodic timer).
    unawaited(
      Future<void>.delayed(Duration.zero, () {
        if (_disposed) return;
        _directory.applyDiscovery(_discovery.demoPeers);
        _notify();
      }),
    );
  }

  /// Pairs with a device (from discovery list or a scanned QR payload).
  Future<void> pair(PeerDevice device) async {
    final paired = device.copyWith(isPaired: true, lastSeen: DateTime.now());
    _directory.pair(paired);
    _notify();
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
    _directory.unpair(deviceId);
    _notify();
    await _pairing.removePaired(deviceId);
  }

  String get localPairingPayload => _discovery.localPairingPayload();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _discovery.stop();
    super.dispose();
  }
}
