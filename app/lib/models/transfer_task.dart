/// Direction of a [TransferTask] from this device's point of view.
enum TransferDirection { send, receive }

/// Lifecycle of a [TransferTask].
enum TransferStatus { queued, active, done, failed }

/// A single file moving between this device and a peer.
class TransferTask {
  const TransferTask({
    required this.id,
    required this.fileName,
    required this.bytes,
    required this.totalBytes,
    required this.direction,
    required this.status,
    required this.peerName,
  });

  final String id;
  final String fileName;

  /// Bytes transferred so far.
  final int bytes;

  /// Total size of the file.
  final int totalBytes;

  final TransferDirection direction;
  final TransferStatus status;

  /// Display name of the peer on the other end.
  final String peerName;

  /// 0.0–1.0 progress; 0 when total size is unknown.
  double get progress =>
      totalBytes > 0 ? (bytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  bool get isFinished =>
      status == TransferStatus.done || status == TransferStatus.failed;

  TransferTask copyWith({
    String? id,
    String? fileName,
    int? bytes,
    int? totalBytes,
    TransferDirection? direction,
    TransferStatus? status,
    String? peerName,
  }) {
    return TransferTask(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      bytes: bytes ?? this.bytes,
      totalBytes: totalBytes ?? this.totalBytes,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      peerName: peerName ?? this.peerName,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'fileName': fileName,
        'bytes': bytes,
        'totalBytes': totalBytes,
        'direction': direction.name,
        'status': status.name,
        'peerName': peerName,
      };

  factory TransferTask.fromJson(Map<String, dynamic> json) => TransferTask(
        id: json['id'] as String,
        fileName: json['fileName'] as String,
        bytes: (json['bytes'] as num).toInt(),
        totalBytes: (json['totalBytes'] as num).toInt(),
        direction: TransferDirection.values.byName(json['direction'] as String),
        status: TransferStatus.values.byName(json['status'] as String),
        peerName: json['peerName'] as String,
      );
}
