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
    this.contentHash,
    this.differenceHash,
    this.acknowledgedBytes = const {},
    this.placeholder = false,
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

  /// Lowercase hex SHA-256 of the file bytes, when known.
  final String? contentHash;

  /// 64-bit difference hash. Null until pixels have been sampled.
  final int? differenceHash;

  /// Bytes each paired device has acknowledged, keyed by device id.
  final Map<String, int> acknowledgedBytes;

  /// True for generated demo rows that are not files on disk.
  final bool placeholder;

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
    String? contentHash,
    int? differenceHash,
    Map<String, int>? acknowledgedBytes,
    bool? placeholder,
  }) {
    return MediaItem(
      id: id ?? this.id,
      path: path ?? this.path,
      type: type ?? this.type,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      contentHash: contentHash ?? this.contentHash,
      differenceHash: differenceHash ?? this.differenceHash,
      acknowledgedBytes: acknowledgedBytes ?? this.acknowledgedBytes,
      placeholder: placeholder ?? this.placeholder,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'path': path,
    'type': type.name,
    'sizeBytes': sizeBytes,
    'createdAt': createdAt.toIso8601String(),
    'thumbnailPath': thumbnailPath,
    if (contentHash != null) 'contentHash': contentHash,
    if (differenceHash != null) 'differenceHash': differenceHash,
    if (acknowledgedBytes.isNotEmpty) 'acknowledgedBytes': acknowledgedBytes,
    if (placeholder) 'placeholder': true,
  };

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
    id: json['id'] as String,
    path: json['path'] as String,
    type: MediaType.values.byName(json['type'] as String),
    sizeBytes: (json['sizeBytes'] as num).toInt(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    thumbnailPath: json['thumbnailPath'] as String?,
    contentHash: json['contentHash'] as String?,
    differenceHash: (json['differenceHash'] as num?)?.toInt(),
    acknowledgedBytes: _acks(json['acknowledgedBytes']),
    placeholder: json['placeholder'] as bool? ?? false,
  );

  /// Null when [json] is not a usable library row.
  static MediaItem? tryFromJson(Map<String, dynamic> json) {
    try {
      return MediaItem.fromJson(json);
    } on Object {
      return null;
    }
  }

  static Map<String, int> _acks(Object? raw) {
    if (raw is! Map) return const {};
    final acks = <String, int>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is String && value is num) acks[key] = value.toInt();
    }
    return acks;
  }
}

/// Photo, video, or generic file from a filename. Unknown extensions are files.
MediaType mediaTypeForName(String name) {
  final lower = name.toLowerCase();
  const videos = ['.mp4', '.mov', '.mkv', '.webm'];
  const photos = ['.jpg', '.jpeg', '.png', '.heic', '.webp', '.gif'];
  if (videos.any(lower.endsWith)) return MediaType.video;
  if (photos.any(lower.endsWith)) return MediaType.photo;
  return MediaType.file;
}
