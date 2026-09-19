import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/device.dart';

/// Parses `uncloud://` pairing payloads and persists the set of paired
/// devices locally (SharedPreferences — everything stays on-device).
class PairingService {
  PairingService();

  static const _prefKey = 'uncloud.pairedDevices';

  /// Parses a pairing payload.
  ///
  /// Accepts the core CLI format (`uncloud://` + base64url JSON) and the
  /// older query-string form (`uncloud://pair/<id>?name=&host=&port=`).
  PeerDevice? parsePayload(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.scheme == 'uncloud' && uri.host == 'pair') {
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

    const prefix = 'uncloud://';
    if (!trimmed.startsWith(prefix)) return null;
    final body = trimmed.substring(prefix.length);
    try {
      var b64 = body.replaceAll('-', '+').replaceAll('_', '/');
      while (b64.length % 4 != 0) {
        b64 += '=';
      }
      final obj = jsonDecode(utf8.decode(base64Decode(b64))) as Map<String, dynamic>;
      final id = obj['deviceId'] as String? ?? '';
      final name = obj['name'] as String? ?? '';
      final host = obj['host'] as String? ?? '';
      final port = (obj['port'] as num?)?.toInt();
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
    } catch (_) {
      return null;
    }
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
