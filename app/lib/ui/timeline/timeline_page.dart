import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/devices_controller.dart';
import '../../controllers/library_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/media_item.dart';
import '../widgets/empty_state.dart';

/// Photo timeline grouped by day, with pull-to-refresh and a month scrubber.
///
/// Items come from the on-device library. Demo mode shows the sample index
/// (colored tiles, no real files) until a real library is stored.
class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  final _scrollController = ScrollController();
  final _monthLabel = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateMonthLabel);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _monthLabel.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await context.read<LibraryController>().reload();
  }

  List<MediaItem> get _items {
    if (!mounted) return const [];
    return context.read<LibraryController>().items;
  }

  /// Updates the floating month chip based on scroll offset. Uses a
  /// ValueNotifier (not setState) so fast scrolling doesn't rebuild the page.
  void _updateMonthLabel() {
    if (_items.isEmpty || !_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    // ~64 px per grid row (3 columns) — cheap estimate for the scrubber.
    final row = (offset / 64).floor().clamp(0, _items.length - 1);
    final index = (row * 3).clamp(0, _items.length - 1);
    final month = DateFormat.yMMMM(
      _localeTag(context),
    ).format(_items[index].createdAt);
    if (month != _monthLabel.value) _monthLabel.value = month;
  }

  String _localeTag(BuildContext context) =>
      Localizations.localeOf(context).toLanguageTag();

  /// Groups items newest-first into day sections.
  List<_DaySection> _sectionsOf(List<MediaItem> items) {
    final byDay = <DateTime, List<MediaItem>>{};
    for (final item in items) {
      final day = DateTime(
        item.createdAt.year,
        item.createdAt.month,
        item.createdAt.day,
      );
      byDay.putIfAbsent(day, () => <MediaItem>[]).add(item);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final d in days) _DaySection(d, byDay[d]!)];
  }

  String _dayLabel(BuildContext context, DateTime day) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return l10n.timelineToday;
    if (day == today.subtract(const Duration(days: 1))) {
      return l10n.timelineYesterday;
    }
    return DateFormat.yMMMEd(_localeTag(context)).format(day);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final library = context.watch<LibraryController>();
    final settings = context.watch<SettingsController>();
    final backupTarget = context.watch<DevicesController>().primaryBackupTarget;

    if (!library.isReady) {
      return const Center(child: CircularProgressIndicator());
    }

    final sections = _sectionsOf(library.items);
    if (sections.isEmpty) {
      return EmptyState(
        icon: Icons.photo_library_outlined,
        title: l10n.timelineEmptyTitle,
        body: l10n.timelineEmptyBody,
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: Stack(
        children: [
          ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: sections.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Column(
                  children: [
                    if (library.demo)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n.demoModeBadge,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      ),
                    if (settings.autoBackup && backupTarget != null)
                      _BackupBanner(
                        text: l10n.timelineBackupBanner(backupTarget.name),
                      ),
                  ],
                );
              }
              final section = sections[i - 1];
              return _DaySectionView(
                section: section,
                label: _dayLabel(context, section.day),
                countLabel: l10n.timelineItemCount(section.items.length),
              );
            },
          ),
          Positioned(
            right: 16,
            top: 16,
            child: IgnorePointer(
              child: ValueListenableBuilder<String>(
                valueListenable: _monthLabel,
                builder: (context, month, _) {
                  if (month.isEmpty) return const SizedBox.shrink();
                  return Chip(
                    label: Text(month),
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySection {
  const _DaySection(this.day, this.items);
  final DateTime day;
  final List<MediaItem> items;
}

class _BackupBanner extends StatelessWidget {
  const _BackupBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_done_outlined,
            size: 18,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySectionView extends StatelessWidget {
  const _DaySectionView({
    required this.section,
    required this.label,
    required this.countLabel,
  });

  final _DaySection section;
  final String label;
  final String countLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(label, style: theme.textTheme.titleSmall),
              const SizedBox(width: 8),
              Text(
                countLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: section.items.length,
          itemBuilder: (_, i) => _MediaTile(item: section.items[i]),
        ),
      ],
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    // Deterministic pastel based on the id hash so demo tiles look varied.
    final hue = (item.id.hashCode % 360).abs().toDouble();
    final color = HSVColor.fromAHSV(1, hue, 0.35, 0.85).toColor();
    final icon = switch (item.type) {
      MediaType.photo => Icons.photo_outlined,
      MediaType.video => Icons.play_circle_outline,
      MediaType.file => Icons.insert_drive_file_outlined,
    };
    return Tooltip(
      message: item.fileName,
      child: Container(
        color: color,
        child: Center(child: Icon(icon, color: Colors.black54)),
      ),
    );
  }
}
