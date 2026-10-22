import '../models/media_item.dart';
import 'difference_hash.dart';

enum DuplicateKind { exact, perceptual }

/// A set of library items that are the same bytes, or that look alike.
class DuplicateGroup {
  const DuplicateGroup({
    required this.kind,
    required this.items,
    this.distance = 0,
  });

  final DuplicateKind kind;

  /// Stable order: ascending item id.
  final List<MediaItem> items;

  /// Maximum pairwise dHash distance. Zero for exact groups.
  final int distance;
}

/// Groups a local library by SHA-256 and, for the rest, by dHash.
///
/// Exact copies win: an item already in an exact group is not also reported
/// as a lookalike. Perceptual groups are connected components under
/// [nearThreshold] (default 8, a typical dHash cutoff).
class DuplicateAssistant {
  const DuplicateAssistant({this.nearThreshold = 8});

  final int nearThreshold;

  List<DuplicateGroup> find(List<MediaItem> items) {
    final threshold = nearThreshold < 0 ? 0 : nearThreshold;
    final exact = <DuplicateGroup>[];
    final byHash = <String, List<MediaItem>>{};
    for (final item in items) {
      final hash = item.contentHash;
      if (hash == null || hash.isEmpty) continue;
      byHash.putIfAbsent(hash, () => <MediaItem>[]).add(item);
    }

    final consumed = <String>{};
    for (final group in byHash.values) {
      if (group.length < 2) continue;
      final sorted = [...group]..sort(_byId);
      exact.add(DuplicateGroup(kind: DuplicateKind.exact, items: sorted));
      for (final item in sorted) {
        consumed.add(item.id);
      }
    }

    final perceptual = [
      for (final item in items)
        if (item.differenceHash != null && !consumed.contains(item.id)) item,
    ];
    final parent = <String, String>{
      for (final item in perceptual) item.id: item.id,
    };

    String findRoot(String id) {
      var current = id;
      while (parent[current] != current) {
        final next = parent[current];
        if (next == null) return current;
        parent[current] = parent[next] ?? next;
        current = next;
      }
      return current;
    }

    void union(String a, String b) {
      final rootA = findRoot(a);
      final rootB = findRoot(b);
      if (rootA != rootB) parent[rootB] = rootA;
    }

    for (var i = 0; i < perceptual.length; i++) {
      for (var j = i + 1; j < perceptual.length; j++) {
        final distance = DifferenceHash.hammingDistance(
          perceptual[i].differenceHash!,
          perceptual[j].differenceHash!,
        );
        if (distance <= threshold) {
          union(perceptual[i].id, perceptual[j].id);
        }
      }
    }

    final clusters = <String, List<MediaItem>>{};
    for (final item in perceptual) {
      clusters.putIfAbsent(findRoot(item.id), () => <MediaItem>[]).add(item);
    }

    final near = <DuplicateGroup>[];
    for (final group in clusters.values) {
      if (group.length < 2) continue;
      var maxDistance = 0;
      for (var i = 0; i < group.length; i++) {
        for (var j = i + 1; j < group.length; j++) {
          final distance = DifferenceHash.hammingDistance(
            group[i].differenceHash!,
            group[j].differenceHash!,
          );
          if (distance > maxDistance) maxDistance = distance;
        }
      }
      final sorted = [...group]..sort(_byId);
      near.add(
        DuplicateGroup(
          kind: DuplicateKind.perceptual,
          items: sorted,
          distance: maxDistance,
        ),
      );
    }

    exact.sort((a, b) => _byId(a.items.first, b.items.first));
    near.sort((a, b) => _byId(a.items.first, b.items.first));
    return [...exact, ...near];
  }

  static int _byId(MediaItem a, MediaItem b) => a.id.compareTo(b.id);
}
