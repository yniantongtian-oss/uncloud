import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/transfer_task.dart';
import '../services/transfer_service.dart';

/// UI-facing view over [TransferService]: live task lists + speed estimates.
class TransferController extends ChangeNotifier {
  TransferController({TransferService? service})
      : _service = service ?? TransferService() {
    _sub = _service.tasks.listen((tasks) {
      _noteSpeeds(tasks);
      _tasks = tasks;
      notifyListeners();
    });
    _tasks = _service.snapshot;
  }

  final TransferService _service;
  late final StreamSubscription<List<TransferTask>> _sub;

  List<TransferTask> _tasks = const [];
  final Map<String, int> _lastBytes = {};
  final Map<String, DateTime> _lastTick = {};
  final Map<String, double> _speedBps = {};

  List<TransferTask> get tasks => _tasks;

  List<TransferTask> get active => _tasks
      .where((t) =>
          t.status == TransferStatus.queued ||
          t.status == TransferStatus.active)
      .toList(growable: false);

  List<TransferTask> get history =>
      _tasks.where((t) => t.isFinished).toList(growable: false);

  /// Estimated throughput for a task in bytes/sec (0 when unknown).
  double speedOf(String taskId) => _speedBps[taskId] ?? 0;

  TransferTask enqueue({
    required String fileName,
    required int totalBytes,
    required TransferDirection direction,
    required String peerName,
    String? peerAddress,
    String? filePath,
  }) {
    return _service.enqueue(
      fileName: fileName,
      totalBytes: totalBytes,
      direction: direction,
      peerName: peerName,
      peerAddress: peerAddress,
      filePath: filePath,
    );
  }

  void cancel(String taskId) => _service.cancel(taskId);
  void retry(String taskId) => _service.retry(taskId);
  void clearFinished() => _service.clearFinished();

  void _noteSpeeds(List<TransferTask> tasks) {
    final now = DateTime.now();
    for (final t in tasks) {
      final prevBytes = _lastBytes[t.id];
      final prevTick = _lastTick[t.id];
      if (t.status == TransferStatus.active &&
          prevBytes != null &&
          prevTick != null) {
        final dt = now.difference(prevTick).inMilliseconds / 1000.0;
        if (dt > 0) {
          _speedBps[t.id] = (t.bytes - prevBytes) / dt;
        }
      }
      _lastBytes[t.id] = t.bytes;
      _lastTick[t.id] = now;
      if (t.isFinished) _speedBps.remove(t.id);
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _service.dispose();
    super.dispose();
  }
}
