import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/devices_controller.dart';
import '../../controllers/transfer_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/transfer_task.dart';
import '../devices/devices_page.dart';
import '../pairing/pairing_page.dart';
import '../settings/settings_page.dart';
import '../timeline/timeline_page.dart';
import '../transfers/transfers_page.dart';

/// Main scaffold: bottom NavigationBar with Timeline / Devices / Transfers.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  Future<void> _sendFile(BuildContext context) async {
    final l10n = context.l10n;
    final peer = context.read<DevicesController>().primaryBackupTarget;
    if (peer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.transfersNeedPeer)),
      );
      return;
    }
    final picked = await FilePicker.platform.pickFiles();
    if (!context.mounted) return;
    final file = picked?.files.single;
    if (file == null || file.path == null) {
      if (picked != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.transfersPickFailed)),
        );
      }
      return;
    }
    context.read<TransferController>().enqueue(
          fileName: file.name,
          totalBytes: file.size,
          direction: TransferDirection.send,
          peerName: peer.name,
          peerAddress: '${peer.host}:${peer.port}',
          filePath: file.path,
        );
    setState(() => _index = 2);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final titles = [l10n.timelineTitle, l10n.devicesTitle, l10n.transfersTitle];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          IconButton(
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          TimelinePage(),
          DevicesPage(),
          TransfersPage(),
        ],
      ),
      floatingActionButton: _index == 2
          ? FloatingActionButton.extended(
              onPressed: () => _sendFile(context),
              icon: const Icon(Icons.upload_file),
              label: Text(l10n.transfersSendFile),
            )
          : _index == 1
              ? FloatingActionButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const PairingPage()),
                  ),
                  tooltip: l10n.devicesPairCta,
                  child: const Icon(Icons.qr_code_2),
                )
              : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.photo_library_outlined),
            selectedIcon: const Icon(Icons.photo_library),
            label: l10n.navTimeline,
          ),
          NavigationDestination(
            icon: const Icon(Icons.devices_outlined),
            selectedIcon: const Icon(Icons.devices),
            label: l10n.navDevices,
          ),
          NavigationDestination(
            icon: const Icon(Icons.swap_vert_outlined),
            selectedIcon: const Icon(Icons.swap_vert),
            label: l10n.navTransfers,
          ),
        ],
      ),
    );
  }
}
