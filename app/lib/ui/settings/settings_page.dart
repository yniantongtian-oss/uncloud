import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/locale_controller.dart';
import '../duplicates/duplicates_page.dart';
import '../widgets/section_header.dart';

/// Settings: language, theme, auto-backup, local AI stubs, about.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const appVersion = '0.1.0 (demo)';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = context.watch<SettingsController>();
    final locale = context.watch<LocaleController>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SectionHeader(l10n.settingsLanguage),
          RadioGroup<String>(
            groupValue: locale.mode,
            onChanged: (value) => unawaited(_setLocale(context, value)),
            child: Column(
              children: [
                RadioListTile<String>(
                  title: Text(l10n.languageSystem),
                  value: 'system',
                ),
                RadioListTile<String>(
                  title: Text(l10n.languageEn),
                  value: 'en',
                ),
                RadioListTile<String>(
                  title: Text(l10n.languageZh),
                  value: 'zh',
                ),
              ],
            ),
          ),

          SectionHeader(l10n.settingsTheme),
          RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (value) {
              if (value == null) return;
              unawaited(context.read<SettingsController>().setThemeMode(value));
            },
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: Text(l10n.themeSystem),
                  value: ThemeMode.system,
                ),
                RadioListTile<ThemeMode>(
                  title: Text(l10n.themeLight),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text(l10n.themeDark),
                  value: ThemeMode.dark,
                ),
              ],
            ),
          ),

          // Backup
          SectionHeader(l10n.settingsBackup),
          SwitchListTile(
            title: Text(l10n.settingsAutoBackup),
            subtitle: Text(l10n.settingsAutoBackupSubtitle),
            value: settings.autoBackup,
            onChanged: (v) =>
                context.read<SettingsController>().setAutoBackup(v),
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(l10n.settingsBackupFolder),
            subtitle: Text(
              settings.backupFolder ?? l10n.settingsBackupFolderNone,
            ),
            onTap: () => _pickFolder(context),
          ),

          SectionHeader(l10n.aiSection),
          ListTile(
            leading: const Icon(Icons.content_copy),
            title: Text(l10n.aiDedupe),
            subtitle: Text(l10n.aiDuplicatesSubtitle),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DuplicatesPage()),
            ),
          ),
          _ComingSoonTile(icon: Icons.face_outlined, title: l10n.aiFaces),

          // About
          SectionHeader(l10n.settingsAbout),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsVersion),
            subtitle: const Text(appVersion),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: Text(l10n.settingsLicenses),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
              applicationVersion: appVersion,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.settingsTagline,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setLocale(BuildContext context, String? mode) async {
    if (mode == null) return;
    await context.read<LocaleController>().setMode(mode);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.settingsLanguageChanged)),
    );
  }

  Future<void> _pickFolder(BuildContext context) async {
    try {
      final path = await FilePicker.getDirectoryPath(
        dialogTitle: context.l10n.settingsBackupFolder,
      );
      if (path != null && context.mounted) {
        await context.read<SettingsController>().setBackupFolder(path);
      }
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.errorGeneric)));
      }
    }
  }
}

class _ComingSoonTile extends StatelessWidget {
  const _ComingSoonTile({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Chip(
        label: Text(l10n.aiComingSoon),
        visualDensity: VisualDensity.compact,
      ),
      onTap: () => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.aiComingSoonBody))),
    );
  }
}
