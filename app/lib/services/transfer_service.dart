import 'dart:async';

import 'package:flutter/services.dart';

import '../models/transfer_task.dart';
import 'core_cli.dart';

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

/// Desktop transport: `uncloud send <file> --to host:port`.
class CliTransferTransport implements TransferTransport {
  const CliTransferTransport(this.cli);

  final CoreCli cli;

  @override
  Stream<TransferTask> run(TransferTask task) async* {
    if (task.direction != TransferDirection.send) {
      yield task.copyWith(status: TransferStatus.failed);
      return;
    }
    final to = task.peerAddress;
    final file = task.filePath;
    if (to == null || !to.contains(':') || file == null || file.isEmpty) {
      yield task.copyWith(status: TransferStatus.failed);
      return;
    }
    yield task.copyWith(status: TransferStatus.active);
    final result = await cli.run(['send', file, '--to', to]);
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
    final start = task.bytes < task.resumeFrom ? task.resumeFrom : task.bytes;
    var current = task.copyWith(bytes: start, status: TransferStatus.active);
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
  final _updates = StreamController<TransferTask>.broadcast();
  final _activeRuns = <String, StreamSubscription<TransferTask>>{};
  int _seq = 0;

  /// Live view of the queue (queued + active first, then history).
  Stream<List<TransferTask>> get tasks => _controller.stream;

  /// One event per task mutation, including cancel and completion.
  Stream<TransferTask> get updates => _updates.stream;

  List<TransferTask> get snapshot => List.unmodifiable(_tasks);

  /// Enqueues a file transfer to/from [peerName]. Returns the new task.
  TransferTask enqueue({
    required String fileName,
    required int totalBytes,
    required TransferDirection direction,
    required String peerName,
    String? peerAddress,
    String? filePath,
    String? peerId,
    String? libraryItemId,
    int resumeFrom = 0,
  }) {
    var start = resumeFrom;
    if (start < 0) start = 0;
    if (start > totalBytes && totalBytes >= 0) start = totalBytes;
    final task = TransferTask(
      id: 'task-${DateTime.now().microsecondsSinceEpoch}-${_seq++}',
      fileName: fileName,
      bytes: start,
      totalBytes: totalBytes,
      direction: direction,
      status: TransferStatus.queued,
      peerName: peerName,
      peerAddress: peerAddress,
      filePath: filePath,
      peerId: peerId,
      libraryItemId: libraryItemId,
      resumeFrom: start,
    );
    _tasks.insert(0, task);
    _emit();
    _pump();
    return task;
  }

  void cancel(String taskId) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) return;
    final current = _tasks[index];
    if (current.isFinished) return;
    _activeRuns.remove(taskId)?.cancel();
    _tasks[index] = current.copyWith(status: TransferStatus.cancelled);
    _emitUpdate(_tasks[index]);
    _pump();
  }

  void retry(String taskId) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) return;
    final current = _tasks[index];
    if (current.status != TransferStatus.failed &&
        current.status != TransferStatus.cancelled) {
      return;
    }
    final resume = current.bytes > current.resumeFrom
        ? current.bytes
        : current.resumeFrom;
    _tasks[index] = current.copyWith(
      bytes: resume,
      resumeFrom: resume,
      status: TransferStatus.queued,
    );
    _emitUpdate(_tasks[index]);
    _pump();
  }

  /// Drops completed transfers. Failed and cancelled tasks stay so they can
  /// be retried. The history button is labeled "Clear completed".
  void clearFinished() {
    _tasks.removeWhere((task) => task.status == TransferStatus.done);
    _emit();
  }

  /// Starts queued tasks, one at a time (simple FIFO pump).
  void _pump() {
    final hasActive = _tasks.any((t) => t.status == TransferStatus.active);
    if (hasActive) return;
    // New tasks are inserted at index 0, so the oldest queued task is last.
    final nextIndex = _tasks.lastIndexWhere(
      (t) => t.status == TransferStatus.queued,
    );
    if (nextIndex < 0) return;
    final task = _tasks[nextIndex].copyWith(status: TransferStatus.active);
    // Mark active before the stream runs. A transport may deliver its first
    // event on a later turn; without this, a second enqueue would also start.
    _tasks[nextIndex] = task;
    _emitUpdate(task);
    _activeRuns[task.id] = transport
        .run(task)
        .listen(
          (updated) => _update(task.id, (_) => updated),
          onError: (_) => _update(
            task.id,
            (t) => t.copyWith(status: TransferStatus.failed),
          ),
          onDone: () {
            _activeRuns.remove(task.id);
            _pump();
          },
        );
  }

  void _update(String id, TransferTask Function(TransferTask) update) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final current = _tasks[i];
    // A cancel must stick even if the transport emits a late "done".
    if (current.status == TransferStatus.cancelled) return;
    _tasks[i] = update(current);
    _emitUpdate(_tasks[i]);
  }

  void _emitUpdate(TransferTask task) {
    _emit();
    if (!_updates.isClosed) _updates.add(task);
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
    _updates.close();
  }
}
