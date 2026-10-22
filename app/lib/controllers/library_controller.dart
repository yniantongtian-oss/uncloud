import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/media_item.dart';
import '../services/library_sample.dart';
import '../services/library_service.dart';
import '../sync/duplicate_assistant.dart';
import '../sync/sync_planner.dart';

/// On-device media index. Demo mode seeds a sample library the first time
/// the store is empty; a desktop build with the core starts empty and grows
/// as files are sent.
class LibraryController extends ChangeNotifier {
  LibraryController({
    LibraryService? service,
    this.demo = true,
    List<MediaItem>? seed,
  }) : _service = service ?? LibraryService() {
    _ready = _load(seed);
  }

  final LibraryService _service;
  final bool demo;

  late final Future<void> _ready;
  Future<void> get ready => _ready;

  bool _isReady = false;
  bool _disposed = false;
  List<MediaItem> _items = const [];

  bool get isReady => _isReady;
  List<MediaItem> get items => _items;

  SyncPlan planFor(String peerId, {Set<String> remoteHashes = const {}}) {
    return const SyncPlanner().plan(
      peerId: peerId,
      local: _items,
      remoteHashes: remoteHashes,
    );
  }

  List<DuplicateGroup> get duplicates =>
      const DuplicateAssistant().find(_items);

  Future<void> reload() => _load(null);

  Future<void> upsert(MediaItem item) async {
    final index = _items.indexWhere((existing) => existing.id == item.id);
    if (index < 0) {
      _items = [item, ..._items];
    } else {
      final existing = _items[index];
      final next = [..._items];
      next[index] = item.copyWith(
        acknowledgedBytes: existing.acknowledgedBytes,
        differenceHash: item.differenceHash ?? existing.differenceHash,
      );
      _items = next;
    }
    _notify();
    await _service.save(_items);
  }

  /// Records how many bytes [peerId] has accepted for [id]. Never moves
  /// the acknowledgement backwards.
  Future<void> acknowledge(String id, String peerId, int bytes) async {
    if (peerId.isEmpty || bytes < 0) return;
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final item = _items[index];
    final capped = bytes > item.sizeBytes ? item.sizeBytes : bytes;
    final current = item.acknowledgedBytes[peerId];
    if (current != null && capped <= current) return;
    final acknowledged = Map<String, int>.of(item.acknowledgedBytes);
    acknowledged[peerId] = capped;
    final next = [..._items];
    next[index] = item.copyWith(acknowledgedBytes: acknowledged);
    _items = next;
    _notify();
    await _service.save(_items);
  }

  Future<void> _load(List<MediaItem>? seed) async {
    var loaded = seed ?? await _service.load();
    if (loaded.isEmpty && demo) {
      loaded = buildSampleLibrary();
      await _service.save(loaded);
    }
    _items = loaded;
    _isReady = true;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
