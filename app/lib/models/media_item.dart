/// Kind of media a [MediaItem] represents.
enum MediaType { photo, video, file }

/// A photo, video or generic file known to Uncloud (local or on a peer).
class MediaItem {
  const MediaItem({
    required this.id,
    required this.path,
    required this.type,
    required this.sizeBytes,
    required this.createdAt,
    this.thumbnailPath,
  });

  /// Stable id (content hash or database id from the core).
  final String id;

  /// Absolute path on the device that owns the item.
  final String path;

  final MediaType type;

  final int sizeBytes;

  /// Capture/creation time used for timeline grouping.
  final DateTime createdAt;

  /// Optional cached thumbnail; null when not generated yet.
  final String? thumbnailPath;

  String get fileName {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash >= 0 ? normalized.substring(slash + 1) : normalized;
  }

  MediaItem copyWith({
    String? id,
    String? path,
    MediaType? type,
    int? sizeBytes,
    DateTime? createdAt,
    String? thumbnailPath,
  }) {
    return MediaItem(
      id: id ?? this.id,
      path: path ?? this.path,
      type: type ?? this.type,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'path': path,
        'type': type.name,
        'sizeBytes': sizeBytes,
        'createdAt': createdAt.toIso8601String(),
        'thumbnailPath': thumbnailPath,
      };

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        id: json['id'] as String,
        path: json['path'] as String,
        type: MediaType.values.byName(json['type'] as String),
        sizeBytes: (json['sizeBytes'] as num).toInt(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        thumbnailPath: json['thumbnailPath'] as String?,
      );
}
