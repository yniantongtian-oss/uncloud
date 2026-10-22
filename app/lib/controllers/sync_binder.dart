import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/transfer_task.dart';
import 'library_controller.dart';
import 'transfer_controller.dart';

/// Writes transfer progress back into the local library.
///
/// A finished send marks the item fully acknowledged for that peer. A failure
/// that moved bytes keeps the partial offset so the next plan resumes.
class SyncBinder extends StatefulWidget {
  const SyncBinder({super.key, required this.child});

  final Widget child;

  @override
  State<SyncBinder> createState() => _SyncBinderState();
}

class _SyncBinderState extends State<SyncBinder> {
  StreamSubscription<TransferTask>? _subscription;

  @override
  void initState() {
    super.initState();
    final transfers = context.read<TransferController>();
    final library = context.read<LibraryController>();
    _subscription = transfers.updates.listen((task) {
      final id = task.libraryItemId;
      final peerId = task.peerId;
      if (id == null || peerId == null) return;
      if (task.status == TransferStatus.done) {
        unawaited(library.acknowledge(id, peerId, task.totalBytes));
      } else if (task.status == TransferStatus.failed &&
          task.bytes > task.resumeFrom) {
        unawaited(library.acknowledge(id, peerId, task.bytes));
      }
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
