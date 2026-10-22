import '../models/media_item.dart';

/// One local file that a peer does not yet have in full.
class SyncPlanItem {
  const SyncPlanItem({required this.item, required this.resumeFrom});

  final MediaItem item;

  /// Bytes the peer has already acknowledged. The next send continues here.
  final int resumeFrom;

  int get remainingBytes {
    final remaining = item.sizeBytes - resumeFrom;
    return remaining < 0 ? 0 : remaining;
  }
}

/// What still needs to move to one paired device.
class SyncPlan {
  const SyncPlan({required this.peerId, required this.items});

  final String peerId;
  final List<SyncPlanItem> items;

  int get remainingBytes =>
      items.fold(0, (sum, item) => sum + item.remainingBytes);

  bool get isEmpty => items.isEmpty;
}

/// Decides which local items to send. The peer's index and our own
/// acknowledgements both count: a hash already stored on that device is not
/// sent again, and a partial acknowledgement resumes instead of restarting.
///
/// Order is oldest capture first, then item id, so a backup is chronological
/// and stable.
class SyncPlanner {
  const SyncPlanner();

  SyncPlan plan({
    required String peerId,
    required Iterable<MediaItem> local,
    Set<String> remoteHashes = const {},
  }) {
    final known = <String>{...remoteHashes};
    final library = local.toList(growable: false);
    for (final item in library) {
      final hash = item.contentHash;
      if (hash == null || hash.isEmpty) continue;
      if (_fullySynced(item, peerId)) known.add(hash);
    }

    final pending = <SyncPlanItem>[];
    for (final item in library) {
      if (item.sizeBytes < 0) continue;
      final hash = item.contentHash;
      if (hash != null && hash.isNotEmpty && known.contains(hash)) continue;
      if (_fullySynced(item, peerId)) continue;
      final acknowledged = item.acknowledgedBytes[peerId] ?? 0;
      final resume = acknowledged < 0
          ? 0
          : (acknowledged > item.sizeBytes ? item.sizeBytes : acknowledged);
      if (item.sizeBytes > 0 && resume >= item.sizeBytes) continue;
      pending.add(SyncPlanItem(item: item, resumeFrom: resume));
    }

    pending.sort((a, b) {
      final byTime = a.item.createdAt.compareTo(b.item.createdAt);
      if (byTime != 0) return byTime;
      return a.item.id.compareTo(b.item.id);
    });
    return SyncPlan(peerId: peerId, items: pending);
  }

  bool _fullySynced(MediaItem item, String peerId) {
    if (!item.acknowledgedBytes.containsKey(peerId)) return false;
    final acknowledged = item.acknowledgedBytes[peerId] ?? 0;
    return acknowledged >= item.sizeBytes;
  }
}
