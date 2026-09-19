import 'package:flutter/material.dart';

import '../services/settings_service.dart';

/// UI-facing settings state: theme mode, auto-backup toggle, backup folder.
class SettingsController extends ChangeNotifier {
  SettingsController({SettingsService? service})
      : _service = service ?? SettingsService() {
    _load();
  }

  final SettingsService _service;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool _autoBackup = true;
  bool get autoBackup => _autoBackup;

  String? _backupFolder;
  String? get backupFolder => _backupFolder;

  Future<void> _load() async {
    _themeMode = await _service.loadThemeMode();
    _autoBackup = await _service.loadAutoBackup();
    _backupFolder = await _service.loadBackupFolder();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _service.saveThemeMode(mode);
  }

  Future<void> setAutoBackup(bool enabled) async {
    if (_autoBackup == enabled) return;
    _autoBackup = enabled;
    notifyListeners();
    await _service.saveAutoBackup(enabled);
  }

  Future<void> setBackupFolder(String path) async {
    _backupFolder = path;
    notifyListeners();
    await _service.saveBackupFolder(path);
  }
}
