import '../models/media_item.dart';

/// Device id of the paired desktop in demo discovery.
const sampleDesktopPeerId = 'desk-pc-8f3a1c92';

/// Deterministic local library used when the on-device index is empty.
///
/// Most items are already acknowledged by [peerId], so a backup sends only the
/// newest gap. One exact copy and one perceptual pair are included so the
/// duplicate assistant has something real to group. Paths are placeholders:
/// they are not files on disk.
List<MediaItem> buildSampleLibrary({
  DateTime? now,
  String peerId = sampleDesktopPeerId,
}) {
  final clock = now ?? DateTime.now();
  final items = <MediaItem>[];
  var id = 0;
  for (var dayOffset = 0; dayOffset < 56; dayOffset++) {
    if (dayOffset % 7 == 4) continue;
    final count = 2 + (dayOffset % 5);
    for (var i = 0; i < count; i++) {
      final n = id++;
      final created = clock.subtract(
        Duration(days: dayOffset, hours: 6 + i, minutes: i * 7),
      );
      final isVideo = n % 9 == 0;
      final size = (isVideo ? 24 : 3) * 1024 * 1024 + n * 1024;
      items.add(
        MediaItem(
          id: 'media-$n',
          path:
              '/DCIM/Camera/${isVideo ? 'VID' : 'IMG'}_$n.${isVideo ? 'mp4' : 'jpg'}',
          type: isVideo ? MediaType.video : MediaType.photo,
          sizeBytes: size,
          createdAt: created,
          contentHash: 'sha256-${n.toString().padLeft(4, '0')}',
          placeholder: true,
        ),
      );
    }
  }

  items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final pendingIds = items.take(3).map((item) => item.id).toSet();
  final library = [
    for (final item in items)
      if (pendingIds.contains(item.id))
        item
      else
        item.copyWith(acknowledgedBytes: {peerId: item.sizeBytes}),
  ];

  final source = library.firstWhere((item) => item.id == 'media-20');
  final copy = source.copyWith(
    id: 'media-20-copy',
    path: '/DCIM/Camera/IMG_20_copy.jpg',
    acknowledgedBytes: {peerId: source.sizeBytes},
  );

  const nearHash = 0x0FF00FF00FF00FF0;
  const nearSize = 3 * 1024 * 1024;
  final nearAt = clock.subtract(const Duration(days: 12, hours: 4));
  MediaItem near(String id, int hash, String name) {
    return MediaItem(
      id: id,
      path: '/DCIM/Camera/$name',
      type: MediaType.photo,
      sizeBytes: nearSize,
      createdAt: nearAt,
      contentHash: 'sha256-$id',
      differenceHash: hash,
      acknowledgedBytes: {peerId: nearSize},
      placeholder: true,
    );
  }

  return [
    ...library,
    copy,
    near('near-a', nearHash, 'IMG_near_a.jpg'),
    near('near-b', nearHash ^ 0x3, 'IMG_near_b.jpg'),
  ];
}
