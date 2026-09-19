import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/transfer_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/transfer_task.dart';
import '../../utils/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';

/// Active transfers (with live progress) above the finished history.
class TransfersPage extends StatelessWidget {
  const TransfersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = context.watch<TransferController>();
    final active = controller.active;
    final history = controller.history;

    if (active.isEmpty && history.isEmpty) {
      return EmptyState(
        icon: Icons.swap_vert,
        title: l10n.transfersEmptyTitle,
        body: l10n.transfersEmptyBody,
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (active.isNotEmpty) ...[
          SectionHeader(l10n.transfersActive),
          for (final t in active) _TransferTile(task: t),
        ],
        if (history.isNotEmpty) ...[
          SectionHeader(
            l10n.transfersHistory,
            trailing: TextButton(
              onPressed: controller.clearFinished,
              child: Text(l10n.transferClearDone),
            ),
          ),
          for (final t in history) _TransferTile(task: t),
        ],
      ],
    );
  }
}

class _TransferTile extends StatelessWidget {
  const _TransferTile({required this.task});

  final TransferTask task;

  String _statusLabel(BuildContext context) {
    final l10n = context.l10n;
    return switch (task.status) {
      TransferStatus.queued => l10n.transferQueued,
      TransferStatus.active => l10n.transferActive,
      TransferStatus.done => l10n.transferDone,
      TransferStatus.failed => l10n.transferFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = context.read<TransferController>();
    final isActive = task.status == TransferStatus.active;
    final isQueued = task.status == TransferStatus.queued;
    final sending = task.direction == TransferDirection.send;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  sending ? Icons.north_east : Icons.south_west,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.fileName,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _statusLabel(context),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              sending
                  ? l10n.transferSending(task.peerName)
                  : l10n.transferReceiving(task.peerName),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (isActive || isQueued) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: isQueued ? null : task.progress,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    l10n.transferProgressOf(
                      formatBytes(task.bytes),
                      formatBytes(task.totalBytes),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (isActive)
                    Text(
                      formatSpeed(controller.speedOf(task.id).round()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isActive || isQueued)
                  TextButton(
                    onPressed: () => controller.cancel(task.id),
                    child: Text(l10n.transferCancel),
                  ),
                if (task.status == TransferStatus.failed)
                  TextButton(
                    onPressed: () => controller.retry(task.id),
                    child: Text(l10n.transferRetry),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
