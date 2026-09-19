import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/devices_controller.dart';
import '../../controllers/transfer_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/device.dart';
import '../../models/transfer_task.dart';
import '../../utils/format.dart';
import '../pairing/pairing_page.dart';
import '../widgets/empty_state.dart';

/// Paired-device cards; tap opens a detail sheet with actions.
class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final paired = context.watch<DevicesController>().paired;

    if (paired.isEmpty) {
      return EmptyState(
        icon: Icons.devices_other,
        title: l10n.devicesEmptyTitle,
        body: l10n.devicesEmptyBody,
        actionLabel: l10n.devicesPairCta,
        onAction: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PairingPage()),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: paired.length,
      itemBuilder: (context, i) => _DeviceCard(device: paired[i]),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device});

  final PeerDevice device;

  String _lastSeenLabel(BuildContext context) {
    final l10n = context.l10n;
    final diff = DateTime.now().difference(device.lastSeen);
    if (diff.inMinutes < 1) return l10n.devicesLastSeenNow;
    if (diff.inHours < 1) return l10n.devicesLastSeenMinutes(diff.inMinutes);
    if (diff.inDays < 1) return l10n.devicesLastSeenHours(diff.inHours);
    return l10n.devicesLastSeenDays(diff.inDays);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final online = device.isOnline;
    final fraction = device.storageUsedFraction;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.computer, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(device.name,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          '${device.shortId} · ${_lastSeenLabel(context)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _StatusDot(online: online),
                  const SizedBox(width: 6),
                  Text(
                    online ? l10n.devicesOnline : l10n.devicesOffline,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
              if (fraction != null) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: fraction),
                const SizedBox(height: 4),
                Text(
                  '${l10n.devicesStorage}: '
                  '${l10n.devicesStorageFree(
                    formatBytes(device.totalStorageBytes - device.usedStorageBytes),
                    formatBytes(device.totalStorageBytes),
                  )}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    // Capture the page-level messenger so the sheet can show snackbars after pop.
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _DeviceDetailSheet(device: device, messenger: messenger),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: online ? Colors.green : Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

class _DeviceDetailSheet extends StatelessWidget {
  const _DeviceDetailSheet({required this.device, required this.messenger});

  final PeerDevice device;

  /// Page-level messenger (the sheet itself has no Scaffold).
  final ScaffoldMessengerState messenger;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(device.name,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            _InfoRow(label: l10n.deviceDetailId, value: device.deviceId),
            _InfoRow(
              label: l10n.deviceDetailAddress,
              value: '${device.host}:${device.port}',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.deviceDetailComingSoon)),
                );
              },
              icon: const Icon(Icons.folder_open),
              label: Text(l10n.devicesBrowseFiles),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () {
                final transfers = context.read<TransferController>();
                // Queue a small demo backup batch.
                for (var i = 0; i < 3; i++) {
                  transfers.enqueue(
                    fileName: 'IMG_backup_$i.jpg',
                    totalBytes: (4 + i) * 1024 * 1024,
                    direction: TransferDirection.send,
                    peerName: device.name,
                  );
                }
                Navigator.of(context).pop();
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.devicesBackupStarted(device.name))),
                );
              },
              icon: const Icon(Icons.backup_outlined),
              label: Text(l10n.devicesBackupNow),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _confirmUnpair(context),
              icon: const Icon(Icons.link_off),
              label: Text(l10n.devicesUnpair),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmUnpair(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.devicesUnpair),
        content: Text(l10n.devicesUnpairConfirm(device.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<DevicesController>().unpair(device.deviceId);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

