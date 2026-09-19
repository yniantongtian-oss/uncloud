import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls the app locale.
///
/// The stored preference is one of `'system'`, `'en'` or `'zh'`.
/// `'system'` resolves to the platform locale (zh → Chinese, otherwise
/// English) and therefore automatically follows the system on first launch.
class LocaleController extends ChangeNotifier {
  LocaleController();

  static const _prefKey = 'uncloud.localeMode';

  /// One of `'system'`, `'en'`, `'zh'`.
  String _mode = 'system';
  String get mode => _mode;

  /// Locale passed to [WidgetsApp.locale]; null means "follow system".
  Locale? get locale {
    switch (_mode) {
      case 'en':
        return const Locale('en');
      case 'zh':
        return const Locale('zh');
      default:
        return null;
    }
  }

  /// Loads the persisted choice. Call once before `runApp` (or let the app
  /// build and wait for the notify).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);
    if (stored == 'en' || stored == 'zh' || stored == 'system') {
      _mode = stored!;
      notifyListeners();
    }
  }

  Future<void> setMode(String mode) async {
    if (mode != 'system' && mode != 'en' && mode != 'zh') return;
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mode);
  }
}
