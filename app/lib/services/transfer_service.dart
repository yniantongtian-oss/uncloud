import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/transfer_task.dart';

/// Abstract transport for moving files to/from a peer.
///
/// Implementations:
///  * [CliTransferTransport] — desktop: spawns the `uncloud` core CLI and
///    parses its JSON progress lines.
///  * [ChannelTransferTransport] — mobile: MethodChannel bridge into the
///    embedded core (`uncloud/transfer`).
///  * [DemoTransferTransport] — simulated progress so the app runs standalone.
abstract class TransferTransport {
  /// Streams updated snapshots of [task] until it reaches a finished status.
  Stream<TransferTask> run(TransferTask task);
}

/// Desktop transport: `uncloud send <file> <peer>` / `uncloud receive ...`.
class CliTransferTransport implements TransferTransport {
  const CliTransferTransport({this.cliPath = 'uncloud'});

  final String cliPath;

  @override
  Stream<TransferTask> run(TransferTask task) async* {
    final args = <String>[
      task.direction == TransferDirection.send ? 'send' : 'receive',
      task.fileName,
      task.peerName,
      '--json',
    ];
    // TODO(core integration): parse streaming JSON progress from stdout and
    // yield updated task snapshots. Kept unexecuted in demo builds.
    final result = await Process.run(cliPath, args);
    if (result.exitCode == 0) {
      yield task.copyWith(bytes: task.totalBytes, status: TransferStatus.done);
    } else {
      yield task.copyWith(status: TransferStatus.failed);
    }
  }
}

/// Mobile transport: MethodChannel into the embedded core library.
class ChannelTransferTransport implements TransferTransport {
  const ChannelTransferTransport();

  static const _channel = MethodChannel('uncloud/transfer');

  @override
  Stream<TransferTask> run(TransferTask task) async* {
    // TODO(core integration): subscribe to the core's EventChannel for live
    // progress events keyed by task id.
    await _channel.invokeMethod<void>('start', task.toJson());
    yield task.copyWith(bytes: task.totalBytes, status: TransferStatus.done);
  }
}

/// Simulated transport used in demo mode: advances progress in chunks.
class DemoTransferTransport implements TransferTransport {
  const DemoTransferTransport();

  @override
  Stream<TransferTask> run(TransferTask task) async* {
    var current = task.copyWith(status: TransferStatus.active);
    yield current;
    const step = Duration(milliseconds: 220);
    while (current.bytes < current.totalBytes) {
      await Future<void>.delayed(step);
      // Roughly 8–24 MB/s of simulated LAN throughput.
      final chunk = 8 * 1024 * 1024 + (current.bytes % (16 * 1024 * 1024));
      final next = (current.bytes + chunk).clamp(0, current.totalBytes);
      current = current.copyWith(bytes: next);
      yield current;
    }
    yield current.copyWith(status: TransferStatus.done);
  }
}

/// Owns the transfer queue and exposes live task state to the UI.
class TransferService {
  TransferService({TransferTransport? transport})
      : transport = transport ?? const DemoTransferTransport();

  final TransferTransport transport;

  final _tasks = <TransferTask>[];
  final _controller = StreamController<List<TransferTask>>.broadcast();
  final _activeRuns = <String, StreamSubscription<TransferTask>>{};
  int _seq = 0;

  /// Live view of the queue (queued + active first, then history).
  Stream<List<TransferTask>> get tasks => _controller.stream;

  List<TransferTask> get snapshot => List.unmodifiable(_tasks);

  /// Enqueues a file transfer to/from [peerName]. Returns the new task.
  TransferTask enqueue({
    required String fileName,
    required int totalBytes,
    required TransferDirection direction,
    required String peerName,
  }) {
    final task = TransferTask(
      id: 'task-${DateTime.now().microsecondsSinceEpoch}-${_seq++}',
      fileName: fileName,
      bytes: 0,
      totalBytes: totalBytes,
      direction: direction,
      status: TransferStatus.queued,
      peerName: peerName,
    );
    _tasks.insert(0, task);
    _emit();
    _pump();
    return task;
  }

  void cancel(String taskId) {
    _activeRuns.remove(taskId)?.cancel();
    _update(taskId, (t) => t.copyWith(status: TransferStatus.failed));
    _pump();
  }

  void retry(String taskId) {
    _update(
      taskId,
      (t) => t.copyWith(bytes: 0, status: TransferStatus.queued),
    );
    _pump();
  }

  void clearFinished() {
    _tasks.removeWhere((t) => t.isFinished);
    _emit();
  }

  /// Starts queued tasks, one at a time (simple FIFO pump).
  void _pump() {
    final hasActive =
        _tasks.any((t) => t.status == TransferStatus.active);
    if (hasActive) return;
    final nextIndex =
        _tasks.indexWhere((t) => t.status == TransferStatus.queued);
    if (nextIndex < 0) return;
    final task = _tasks[nextIndex];
    _activeRuns[task.id] = transport.run(task).listen(
      (updated) => _update(task.id, (_) => updated),
      onError: (_) =>
          _update(task.id, (t) => t.copyWith(status: TransferStatus.failed)),
      onDone: () {
        _activeRuns.remove(task.id);
        _pump();
      },
    );
  }

  void _update(String id, TransferTask Function(TransferTask) update) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    _tasks[i] = update(_tasks[i]);
    _emit();
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_tasks));
    }
  }

  void dispose() {
    for (final sub in _activeRuns.values) {
      sub.cancel();
    }
    _activeRuns.clear();
    _controller.close();
  }
}
