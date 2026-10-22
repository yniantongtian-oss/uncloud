/// Direction of a [TransferTask] from this device's point of view.
enum TransferDirection { send, receive }

/// Lifecycle of a [TransferTask].
enum TransferStatus { queued, active, done, failed, cancelled }

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
    this.peerAddress,
    this.filePath,
    this.peerId,
    this.libraryItemId,
    this.resumeFrom = 0,
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

  /// LAN endpoint `host:port` for the core CLI (`uncloud send --to`).
  final String? peerAddress;

  /// Absolute path used by the desktop CLI. Null in demo mode.
  final String? filePath;

  /// Paired device id, when this task belongs to a library backup.
  final String? peerId;

  /// [MediaItem.id] to acknowledge when the send finishes.
  final String? libraryItemId;

  /// Byte offset already accepted by the peer. Progress starts here.
  final int resumeFrom;

  /// 0.0–1.0 progress; 0 when total size is unknown.
  double get progress =>
      totalBytes > 0 ? (bytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  bool get isFinished =>
      status == TransferStatus.done ||
      status == TransferStatus.failed ||
      status == TransferStatus.cancelled;

  TransferTask copyWith({
    String? id,
    String? fileName,
    int? bytes,
    int? totalBytes,
    TransferDirection? direction,
    TransferStatus? status,
    String? peerName,
    String? peerAddress,
    String? filePath,
    String? peerId,
    String? libraryItemId,
    int? resumeFrom,
  }) {
    return TransferTask(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      bytes: bytes ?? this.bytes,
      totalBytes: totalBytes ?? this.totalBytes,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      peerName: peerName ?? this.peerName,
      peerAddress: peerAddress ?? this.peerAddress,
      filePath: filePath ?? this.filePath,
      peerId: peerId ?? this.peerId,
      libraryItemId: libraryItemId ?? this.libraryItemId,
      resumeFrom: resumeFrom ?? this.resumeFrom,
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
    if (peerAddress != null) 'peerAddress': peerAddress,
    if (filePath != null) 'filePath': filePath,
    if (peerId != null) 'peerId': peerId,
    if (libraryItemId != null) 'libraryItemId': libraryItemId,
    if (resumeFrom != 0) 'resumeFrom': resumeFrom,
  };

  factory TransferTask.fromJson(Map<String, dynamic> json) => TransferTask(
    id: json['id'] as String,
    fileName: json['fileName'] as String,
    bytes: (json['bytes'] as num).toInt(),
    totalBytes: (json['totalBytes'] as num).toInt(),
    direction: TransferDirection.values.byName(json['direction'] as String),
    status: TransferStatus.values.byName(json['status'] as String),
    peerName: json['peerName'] as String,
    peerAddress: json['peerAddress'] as String?,
    filePath: json['filePath'] as String?,
    peerId: json['peerId'] as String?,
    libraryItemId: json['libraryItemId'] as String?,
    resumeFrom: (json['resumeFrom'] as num?)?.toInt() ?? 0,
  );
}
