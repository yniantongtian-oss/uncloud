import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../crypto/device_id.dart';
import '../models/device.dart';

/// Current pairing payload version. Higher versions are rejected.
const pairingProtocolVersion = 1;

/// Parses `uncloud://` pairing payloads and persists paired devices locally.
class PairingService {
  PairingService({SharedPreferences? preferences}) : _preferences = preferences;

  final SharedPreferences? _preferences;

  static const _prefKey = 'uncloud.pairedDevices';

  /// Parses a pairing payload.
  ///
  /// Accepts the core CLI format (`uncloud://` + base64url JSON) and the
  /// older query-string form (`uncloud://pair/<id>?name=&host=&port=`).
  ///
  /// v1 JSON payloads must include `pub`, and `deviceId` must equal the first
  /// 16 hex chars of `sha256(SPKI DER)`. Ports outside 1–65535 are rejected.
  /// A version other than [pairingProtocolVersion] is rejected.
  PeerDevice? parsePayload(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.scheme == 'uncloud' && uri.host == 'pair') {
      return _fromLegacyQuery(uri);
    }

    const prefix = 'uncloud://';
    if (!trimmed.startsWith(prefix)) return null;
    return _fromCorePayload(trimmed.substring(prefix.length));
  }

  /// Builds a legacy payload for [device] (demo QR display).
  String buildPayload(PeerDevice device) {
    return Uri(
      scheme: 'uncloud',
      host: 'pair',
      path: '/${device.deviceId}',
      queryParameters: {
        'name': device.name,
        'host': device.host,
        'port': '${device.port}',
        if (device.publicKey != null) 'pub': device.publicKey!,
      },
    ).toString();
  }

  /// Persists [device] as paired. An existing entry with the same id is replaced.
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

  /// Loads paired devices. Corrupt storage or a single bad row is skipped.
  Future<List<PeerDevice>> loadPaired() async {
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) return <PeerDevice>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return <PeerDevice>[];
      final devices = <PeerDevice>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        try {
          devices.add(PeerDevice.fromJson(Map<String, dynamic>.from(entry)));
        } on FormatException {
          continue;
        } on TypeError {
          continue;
        }
      }
      return devices;
    } on FormatException {
      return <PeerDevice>[];
    } on TypeError {
      return <PeerDevice>[];
    }
  }

  Future<void> _save(List<PeerDevice> devices) async {
    final prefs = await _prefs();
    await prefs.setString(
      _prefKey,
      jsonEncode(devices.map((d) => d.toJson()).toList()),
    );
  }

  Future<SharedPreferences> _prefs() async =>
      _preferences ?? await SharedPreferences.getInstance();

  PeerDevice? _fromLegacyQuery(Uri uri) {
    final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first.trim() : '';
    final name = (uri.queryParameters['name'] ?? '').trim();
    final host = (uri.queryParameters['host'] ?? '').trim();
    final port = _parsePort(uri.queryParameters['port']);
    if (id.isEmpty || name.isEmpty || host.isEmpty || port == null) {
      return null;
    }
    final pub = uri.queryParameters['pub'];
    if (pub != null && pub.isNotEmpty && !_pubMatches(id, pub)) return null;
    return PeerDevice(
      deviceId: id,
      name: name,
      host: host,
      port: port,
      isPaired: true,
      lastSeen: DateTime.now(),
      publicKey: pub == null || pub.isEmpty ? null : pub,
    );
  }

  PeerDevice? _fromCorePayload(String body) {
    final bytes = decodeBase64Url(body);
    if (bytes == null || bytes.isEmpty) return null;
    try {
      final text = utf8.decode(bytes);
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      final obj = Map<String, dynamic>.from(decoded);
      final version = obj['v'];
      if (version is! int || version != pairingProtocolVersion) return null;
      final id = obj['deviceId'];
      final name = obj['name'];
      final host = obj['host'];
      final pub = obj['pub'];
      final port = _parsePort(obj['port']);
      if (id is! String || id.trim().isEmpty) return null;
      if (name is! String || name.trim().isEmpty) return null;
      if (host is! String || host.trim().isEmpty) return null;
      if (pub is! String || pub.trim().isEmpty) return null;
      if (port == null) return null;
      final deviceId = id.trim();
      if (!_pubMatches(deviceId, pub)) return null;
      return PeerDevice(
        deviceId: deviceId,
        name: name.trim(),
        host: host.trim(),
        port: port,
        isPaired: true,
        lastSeen: DateTime.now(),
        publicKey: pub.trim(),
      );
    } on FormatException {
      return null;
    }
  }

  bool _pubMatches(String deviceId, String pub) {
    final der = decodeBase64Url(pub);
    if (der == null || der.isEmpty) return false;
    return deviceIdFromSpki(der) == deviceId;
  }

  int? _parsePort(Object? value) {
    int? port;
    if (value is int) {
      port = value;
    } else if (value is double) {
      if (value != value.roundToDouble()) return null;
      port = value.toInt();
    } else if (value is String) {
      port = int.tryParse(value.trim());
    } else {
      return null;
    }
    if (port == null || port < 1 || port > 65535) return null;
    return port;
  }
}
