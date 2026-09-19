import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../controllers/devices_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/device.dart';
import '../widgets/section_header.dart';

/// Pairing screen: shows this device's QR code, offers (stubbed) scanning,
/// and lists auto-discovered peers with Pair buttons.
class PairingPage extends StatelessWidget {
  const PairingPage({super.key, this.onDone});

  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final devices = context.watch<DevicesController>();
    final discovered = devices.discoveredUnpaired;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pairingTitle),
        actions: [
          if (onDone != null)
            TextButton(onPressed: onDone, child: Text(l10n.pairingDone)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SectionHeader(l10n.pairingMyCode),
          _MyQrCard(payload: devices.localPairingPayload),
          SectionHeader(l10n.pairingDiscovered),
          if (discovered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(l10n.pairingNone),
                ],
              ),
            )
          else
            for (final d in discovered) _DiscoveredTile(device: d),
        ],
      ),
    );
  }
}

class _MyQrCard extends StatelessWidget {
  const _MyQrCard({required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 200,
              ),
            ),

            const SizedBox(height: 12),
            Text(
              l10n.pairingScanHint,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _showScanSheet(context),
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(l10n.pairingScan),
            ),
          ],
        ),
      ),
    );
  }

  void _showScanSheet(BuildContext pageContext) {
    final l10n = pageContext.l10n;
    final messenger = ScaffoldMessenger.of(pageContext);
    showModalBottomSheet<void>(
      context: pageContext,
      showDragHandle: true,
      builder: (sheetContext) {
        final candidates =
            sheetContext.watch<DevicesController>().discoveredUnpaired;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.pairingScanSimTitle,
                    style: Theme.of(sheetContext).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(l10n.pairingScanSimBody),
                const SizedBox(height: 16),
                if (candidates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.pairingNone, textAlign: TextAlign.center),
                  )
                else
                  for (final d in candidates)
                    ListTile(
                      leading: const Icon(Icons.qr_code_2),
                      title: Text(d.name),
                      subtitle: Text('${d.host}:${d.port}'),
                      onTap: () async {
                        final devices = pageContext.read<DevicesController>();
                        final payload = Uri(
                          scheme: 'uncloud',
                          host: 'pair',
                          path: '/${d.deviceId}',
                          queryParameters: {
                            'name': d.name,
                            'host': d.host,
                            'port': '${d.port}',
                          },
                        ).toString();
                        final paired = await devices.pairFromPayload(payload);
                        if (!pageContext.mounted) return;
                        Navigator.of(sheetContext).pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(paired != null
                                ? l10n.pairingSuccess(paired.name)
                                : l10n.pairingInvalidCode),
                          ),
                        );
                      },
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DiscoveredTile extends StatelessWidget {
  const _DiscoveredTile({required this.device});

  final PeerDevice device;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(device.host.endsWith('50')
              ? Icons.dns_outlined
              : Icons.computer),
        ),
        title: Text(device.name),
        subtitle: Text('${device.host}:${device.port} · ${device.shortId}'),
        trailing: FilledButton.tonal(
          onPressed: () async {
            await context.read<DevicesController>().pair(device);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.pairingSuccess(device.name))),
            );
          },
          child: Text(l10n.pairingPair),
        ),
      ),
    );
  }
}

