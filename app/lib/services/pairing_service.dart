import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/device.dart';

/// Parses `uncloud://` pairing payloads and persists the set of paired
/// devices locally (SharedPreferences — everything stays on-device).
class PairingService {
  PairingService();

  static const _prefKey = 'uncloud.pairedDevices';

  /// Parses a scanned `uncloud://pair/<id>?name=..&host=..&port=..` payload.
  /// Returns null when the payload is not a valid Uncloud pairing code.
  PeerDevice? parsePayload(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != 'uncloud' || uri.host != 'pair') {
      return null;
    }
    final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    final name = uri.queryParameters['name'] ?? '';
    final host = uri.queryParameters['host'] ?? '';
    final port = int.tryParse(uri.queryParameters['port'] ?? '');
    if (id.isEmpty || name.isEmpty || host.isEmpty || port == null) {
      return null;
    }
    return PeerDevice(
      deviceId: id,
      name: name,
      host: host,
      port: port,
      isPaired: true,
      lastSeen: DateTime.now(),
    );
  }

  /// Builds a payload for [device] (used for QR display and demo scanning).
  String buildPayload(PeerDevice device) {
    return Uri(
      scheme: 'uncloud',
      host: 'pair',
      path: '/${device.deviceId}',
      queryParameters: {
        'name': device.name,
        'host': device.host,
        'port': '${device.port}',
      },
    ).toString();
  }

  /// Persists [device] as paired. Existing entry with same id is replaced.
  Future<void> storePaired(PeerDevice device) async {
    final all = await loadPaired();
    all.removeWhere((d) => d.deviceId == device.deviceId);
    all.add(device.copyWith(isPaired: true));
    await _save(all);
  }

  Future<void> removePaired(String deviceId) async {
    final all = await loadPaired();
    all.removeWhere((d) => d.deviceId == deviceId);
    await _save(all);
  }

  Future<List<PeerDevice>> loadPaired() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null || raw.isEmpty) return <PeerDevice>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(PeerDevice.fromJson)
          .toList();
    } on FormatException {
      return <PeerDevice>[];
    }
  }

  Future<void> _save(List<PeerDevice> devices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefKey,
      jsonEncode(devices.map((d) => d.toJson()).toList()),
    );
  }
}
