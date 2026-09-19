import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists user preferences locally (theme, auto-backup, backup folder).
class SettingsService {
  SettingsService();

  static const _themeKey = 'uncloud.themeMode';
  static const _autoBackupKey = 'uncloud.autoBackup';
  static const _backupFolderKey = 'uncloud.backupFolder';

  Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_themeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  Future<bool> loadAutoBackup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBackupKey) ?? true;
  }

  Future<void> saveAutoBackup(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupKey, enabled);
  }

  Future<String?> loadBackupFolder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backupFolderKey);
  }

  Future<void> saveBackupFolder(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backupFolderKey, path);
  }
}
