import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/library_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/media_item.dart';
import '../../sync/duplicate_assistant.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';

/// On-device duplicate report. Exact SHA-256 groups, then dHash lookalikes.
class DuplicatesPage extends StatelessWidget {
  const DuplicatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final library = context.watch<LibraryController>();
    if (!library.isReady) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.aiDuplicatesTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final groups = library.duplicates;
    final itemCount = groups.fold<int>(
      0,
      (sum, group) => sum + group.items.length,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiDuplicatesTitle)),
      body: groups.isEmpty
          ? EmptyState(
              icon: Icons.content_copy,
              title: l10n.aiDuplicatesEmptyTitle,
              body: l10n.aiDuplicatesEmptyBody,
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    l10n.aiDuplicatesSummary(groups.length, itemCount),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                for (final group in groups) ...[
                  SectionHeader(_heading(l10n, group)),
                  for (final item in group.items)
                    ListTile(
                      leading: Icon(
                        item.type == MediaType.video
                            ? Icons.play_circle_outline
                            : Icons.photo_outlined,
                      ),
                      title: Text(item.fileName),
                      subtitle: Text(item.contentHash ?? item.id),
                    ),
                ],
              ],
            ),
    );
  }

  String _heading(AppLocalizations l10n, DuplicateGroup group) {
    return switch (group.kind) {
      DuplicateKind.exact => l10n.aiDuplicateExact,
      DuplicateKind.perceptual =>
        '${l10n.aiDuplicateNear} · ${l10n.aiDuplicateDistance(group.distance)}',
    };
  }
}
