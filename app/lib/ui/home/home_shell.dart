import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../devices/devices_page.dart';
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
