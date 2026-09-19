/// A peer running Uncloud on the local network (phone, PC, laptop...).
class PeerDevice {
  const PeerDevice({
    required this.deviceId,
    required this.name,
    required this.host,
    required this.port,
    required this.isPaired,
    required this.lastSeen,
    this.totalStorageBytes = 0,
    this.usedStorageBytes = 0,
  });

  /// Stable unique identifier advertised over the pairing payload.
  final String deviceId;

  /// Human-readable device name, e.g. "Alice's PC".
  final String name;

  /// LAN IP address.
  final String host;

  /// TCP port the Uncloud core listens on.
  final int port;

  /// Whether the user has completed pairing with this device.
  final bool isPaired;

  /// Last time this peer answered a discovery probe.
  final DateTime lastSeen;

  /// Total disk space reported by the peer (0 = unknown).
  final int totalStorageBytes;

  /// Used disk space reported by the peer (0 = unknown).
  final int usedStorageBytes;

  /// First 8 chars of the id, handy for compact UI display.
  String get shortId =>
      deviceId.length <= 8 ? deviceId : deviceId.substring(0, 8);

  /// A peer seen in the last 5 minutes is considered online.
  bool get isOnline =>
      DateTime.now().difference(lastSeen).inMinutes.abs() < 5;

  /// 0.0–1.0 disk usage fraction, or null when storage is unknown.
  double? get storageUsedFraction => totalStorageBytes > 0
      ? (usedStorageBytes / totalStorageBytes).clamp(0.0, 1.0)
      : null;

  PeerDevice copyWith({
    String? deviceId,
    String? name,
    String? host,
    int? port,
    bool? isPaired,
    DateTime? lastSeen,
    int? totalStorageBytes,
    int? usedStorageBytes,
  }) {
    return PeerDevice(
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      isPaired: isPaired ?? this.isPaired,
      lastSeen: lastSeen ?? this.lastSeen,
      totalStorageBytes: totalStorageBytes ?? this.totalStorageBytes,
      usedStorageBytes: usedStorageBytes ?? this.usedStorageBytes,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'deviceId': deviceId,
        'name': name,
        'host': host,
        'port': port,
        'isPaired': isPaired,
        'lastSeen': lastSeen.toIso8601String(),
        'totalStorageBytes': totalStorageBytes,
        'usedStorageBytes': usedStorageBytes,
      };

  factory PeerDevice.fromJson(Map<String, dynamic> json) => PeerDevice(
        deviceId: json['deviceId'] as String,
        name: json['name'] as String,
        host: json['host'] as String,
        port: (json['port'] as num).toInt(),
        isPaired: json['isPaired'] as bool? ?? false,
        lastSeen: DateTime.parse(json['lastSeen'] as String),
        totalStorageBytes: (json['totalStorageBytes'] as num?)?.toInt() ?? 0,
        usedStorageBytes: (json['usedStorageBytes'] as num?)?.toInt() ?? 0,
      );

  @override
  String toString() => 'PeerDevice($shortId, $name, $host:$port)';
}
