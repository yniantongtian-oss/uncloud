import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/locale_controller.dart';
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
          // Language
          SectionHeader(l10n.settingsLanguage),
          RadioListTile<String>(
            title: Text(l10n.languageSystem),
            value: 'system',
            groupValue: locale.mode,
            onChanged: (v) => _setLocale(context, v),
          ),
          RadioListTile<String>(
            title: Text(l10n.languageEn),
            value: 'en',
            groupValue: locale.mode,
            onChanged: (v) => _setLocale(context, v),
          ),
          RadioListTile<String>(
            title: Text(l10n.languageZh),
            value: 'zh',
            groupValue: locale.mode,
            onChanged: (v) => _setLocale(context, v),
          ),

          // Theme
          SectionHeader(l10n.settingsTheme),
          RadioListTile<ThemeMode>(
            title: Text(l10n.themeSystem),
            value: ThemeMode.system,
            groupValue: settings.themeMode,
            onChanged: (v) =>
                v == null ? null : context.read<SettingsController>().setThemeMode(v),
          ),
          RadioListTile<ThemeMode>(
            title: Text(l10n.themeLight),
            value: ThemeMode.light,
            groupValue: settings.themeMode,
            onChanged: (v) =>
                v == null ? null : context.read<SettingsController>().setThemeMode(v),
          ),
          RadioListTile<ThemeMode>(
            title: Text(l10n.themeDark),
            value: ThemeMode.dark,
            groupValue: settings.themeMode,
            onChanged: (v) =>
                v == null ? null : context.read<SettingsController>().setThemeMode(v),
          ),

          // Backup
          SectionHeader(l10n.settingsBackup),
          SwitchListTile(
            title: Text(l10n.settingsAutoBackup),
            subtitle: Text(l10n.settingsAutoBackupSubtitle),
            value: settings.autoBackup,
            onChanged: (v) => context.read<SettingsController>().setAutoBackup(v),
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(l10n.settingsBackupFolder),
            subtitle: Text(settings.backupFolder ?? l10n.settingsBackupFolderNone),
            onTap: () => _pickFolder(context),
          ),

          // Local AI (coming soon stubs)
          SectionHeader(l10n.aiSection),
          _ComingSoonTile(icon: Icons.content_copy, title: l10n.aiDedupe),
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
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: context.l10n.settingsBackupFolder,
      );
      if (path != null && context.mounted) {
        await context.read<SettingsController>().setBackupFolder(path);
      }
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorGeneric)),
        );
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
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.aiComingSoonBody)),
      ),
    );
  }
}
