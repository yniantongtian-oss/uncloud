import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';

/// JSON library stored in SharedPreferences. Files themselves stay on disk;
/// this record is metadata only and never leaves the device.
class LibraryService {
  LibraryService({SharedPreferences? preferences}) : _preferences = preferences;

  final SharedPreferences? _preferences;

  static const storageKey = 'uncloud.library';

  Future<List<MediaItem>> load() async {
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return const [];
      final items = <MediaItem>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final item = MediaItem.tryFromJson(Map<String, dynamic>.from(entry));
        if (item != null) items.add(item);
      }
      return items;
    } on Object {
      return const [];
    }
  }

  Future<void> save(List<MediaItem> items) async {
    final prefs = await _prefs();
    await prefs.setString(
      storageKey,
      jsonEncode([for (final item in items) item.toJson()]),
    );
  }

  Future<SharedPreferences> _prefs() async =>
      _preferences ?? await SharedPreferences.getInstance();
}
