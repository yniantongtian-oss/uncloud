import 'package:flutter_test/flutter_test.dart';
import 'package:uncloud/models/media_item.dart';
import 'package:uncloud/services/library_sample.dart';
import 'package:uncloud/sync/duplicate_assistant.dart';
import 'package:uncloud/sync/sync_planner.dart';

void main() {
  final older = DateTime.utc(2026);
  final newer = DateTime.utc(2026, 2);

  MediaItem item({
    required String id,
    required DateTime createdAt,
    String? hash,
    int size = 1000,
    Map<String, int> acked = const {},
    int? dHash,
  }) {
    return MediaItem(
      id: id,
      path: '/photos/$id.jpg',
      type: MediaType.photo,
      sizeBytes: size,
      createdAt: createdAt,
      contentHash: hash ?? id,
      differenceHash: dHash,
      acknowledgedBytes: acked,
    );
  }

  test('skips hashes the peer already has and resumes partial sends', () {
    const planner = SyncPlanner();
    final plan = planner.plan(
      peerId: 'pc',
      remoteHashes: {'remote-only'},
      local: [
        item(id: 'new', createdAt: newer, hash: 'new-hash'),
        item(id: 'remote', createdAt: older, hash: 'remote-only'),
        item(
          id: 'partial',
          createdAt: older,
          hash: 'partial-hash',
          acked: {'pc': 250},
        ),
        item(
          id: 'done',
          createdAt: older,
          hash: 'done-hash',
          acked: {'pc': 1000},
        ),
        item(id: 'copy-of-done', createdAt: newer, hash: 'done-hash'),
      ],
    );

    expect(plan.items.map((planned) => planned.item.id), ['partial', 'new']);
    expect(plan.items.first.resumeFrom, 250);
    expect(plan.items.first.remainingBytes, 750);
    expect(plan.remainingBytes, 1750);
  });

  test('sample library backs up three new items and groups duplicates', () {
    final library = buildSampleLibrary(now: DateTime.utc(2026, 3));
    final plan = const SyncPlanner().plan(
      peerId: sampleDesktopPeerId,
      local: library,
    );
    expect(plan.items, hasLength(3));
    expect(
      plan.items.map((planned) => planned.item.createdAt),
      orderedEquals(
        [...plan.items.map((planned) => planned.item.createdAt)]..sort(),
      ),
    );

    final groups = const DuplicateAssistant().find(library);
    final exact = groups.where((group) => group.kind == DuplicateKind.exact);
    final near = groups.where(
      (group) => group.kind == DuplicateKind.perceptual,
    );
    expect(exact, hasLength(1));
    expect(exact.single.items.map((item) => item.id), [
      'media-20',
      'media-20-copy',
    ]);
    expect(near, hasLength(1));
    expect(near.single.distance, 2);
    expect(
      groups.expand((group) => group.items.map((item) => item.id)).toSet(),
      hasLength(4),
    );
  });

  test('exact copies are not also reported as lookalikes', () {
    final groups = const DuplicateAssistant().find([
      item(id: 'a', createdAt: older, hash: 'same', dHash: 0xFF),
      item(id: 'b', createdAt: newer, hash: 'same', dHash: 0xFF),
      item(id: 'c', createdAt: older, hash: 'other', dHash: 0xF0),
    ]);
    expect(groups, hasLength(1));
    expect(groups.single.kind, DuplicateKind.exact);
  });
}
