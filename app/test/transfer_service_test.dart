import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uncloud/models/transfer_task.dart';
import 'package:uncloud/services/core_cli.dart';
import 'package:uncloud/services/transfer_service.dart';
import 'package:uncloud/utils/format.dart';
import 'package:uncloud/utils/transfer_speed.dart';

void main() {
  test('format helpers and speed rewind', () {
    expect(formatBytes(-5), '0 B');
    expect(formatBytes(1024), '1.0 KB');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatPercent(0.426), '43%');
    expect(formatPercent(2), '100%');
    expect(formatPercent(-1), '0%');
    expect(
      transferSpeedBps(
        previousBytes: 1000,
        nextBytes: 500,
        elapsed: const Duration(seconds: 1),
      ),
      0,
    );
    expect(
      transferSpeedBps(
        previousBytes: 0,
        nextBytes: 2000,
        elapsed: const Duration(milliseconds: 500),
      ),
      4000,
    );
    expect(
      transferSpeedBps(previousBytes: 0, nextBytes: 10, elapsed: Duration.zero),
      isNull,
    );
  });

  test('runs one transfer at a time, oldest first', () async {
    final transport = _GateTransport();
    final service = TransferService(transport: transport);
    addTearDown(service.dispose);

    final first = service.enqueue(
      fileName: 'a.jpg',
      totalBytes: 10,
      direction: TransferDirection.send,
      peerName: 'PC',
    );
    final second = service.enqueue(
      fileName: 'b.jpg',
      totalBytes: 10,
      direction: TransferDirection.send,
      peerName: 'PC',
    );

    expect(_status(service, first.id), TransferStatus.active);
    expect(_status(service, second.id), TransferStatus.queued);
    await _flush();

    transport.gates[first.id]!.complete();
    await _flush();
    expect(_status(service, first.id), TransferStatus.done);
    expect(_status(service, second.id), TransferStatus.active);
  });

  test('cancel sticks when the transport later reports done', () async {
    final transport = _GateTransport();
    final service = TransferService(transport: transport);
    addTearDown(service.dispose);

    final queued = service.enqueue(
      fileName: 'a.jpg',
      totalBytes: 10,
      direction: TransferDirection.send,
      peerName: 'PC',
      resumeFrom: 4,
    );
    expect(queued.bytes, 4);
    await _flush();
    service.cancel(queued.id);
    transport.gates[queued.id]!.complete();
    await _flush();

    expect(_status(service, queued.id), TransferStatus.cancelled);
    final events = <TransferTask>[];
    final sub = service.updates.listen(events.add);
    service.clearFinished();
    await sub.cancel();
    expect(_status(service, queued.id), TransferStatus.cancelled);
  });

  test('clear completed keeps failed tasks', () async {
    final service = TransferService(
      transport: _ScriptedTransport([
        TransferStatus.done,
        TransferStatus.failed,
      ]),
    );
    addTearDown(service.dispose);

    final done = service.enqueue(
      fileName: 'done.jpg',
      totalBytes: 10,
      direction: TransferDirection.send,
      peerName: 'PC',
    );
    final failed = service.enqueue(
      fileName: 'failed.jpg',
      totalBytes: 10,
      direction: TransferDirection.send,
      peerName: 'PC',
    );
    await _flush();
    expect(_status(service, done.id), TransferStatus.done);
    expect(_status(service, failed.id), TransferStatus.failed);

    service.clearFinished();
    expect(service.snapshot.map((item) => item.id), [failed.id]);
  });

  test('retry continues from bytes already sent', () async {
    final transport = _RecordingTransport();
    final service = TransferService(transport: transport);
    addTearDown(service.dispose);

    final failed = service.enqueue(
      fileName: 'failed.jpg',
      totalBytes: 10,
      direction: TransferDirection.send,
      peerName: 'PC',
    );
    await _flush();
    service.retry(failed.id);
    await _flush();

    expect(transport.seen, hasLength(2));
    expect(transport.seen[1].bytes, 3);
    expect(transport.seen[1].resumeFrom, 3);
  });

  test(
    'cli transport fails closed without a host:port and a file path',
    () async {
      final cli = _FakeCli();
      final service = TransferService(transport: CliTransferTransport(cli));
      addTearDown(service.dispose);
      final missing = service.enqueue(
        fileName: 'ghost.jpg',
        totalBytes: 10,
        direction: TransferDirection.send,
        peerName: 'Desktop PC',
      );
      await _flush();
      expect(_status(service, missing.id), TransferStatus.failed);
      expect(cli.calls, 0);
    },
  );
}

TransferStatus _status(TransferService service, String id) {
  return service.snapshot.firstWhere((task) => task.id == id).status;
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _GateTransport implements TransferTransport {
  final gates = <String, Completer<void>>{};

  @override
  Stream<TransferTask> run(TransferTask task) async* {
    yield task.copyWith(status: TransferStatus.active, bytes: task.bytes);
    final gate = Completer<void>();
    gates[task.id] = gate;
    await gate.future;
    yield task.copyWith(status: TransferStatus.done, bytes: task.totalBytes);
  }
}

class _ScriptedTransport implements TransferTransport {
  _ScriptedTransport(this.statuses);

  final List<TransferStatus> statuses;
  int index = 0;

  @override
  Stream<TransferTask> run(TransferTask task) async* {
    final status = statuses[index++];
    yield task.copyWith(
      status: status,
      bytes: status == TransferStatus.done ? task.totalBytes : 3,
    );
  }
}

class _RecordingTransport implements TransferTransport {
  final seen = <TransferTask>[];

  @override
  Stream<TransferTask> run(TransferTask task) async* {
    seen.add(task);
    yield task.copyWith(status: TransferStatus.failed, bytes: 3);
  }
}

class _FakeCli extends CoreCli {
  _FakeCli() : super(scriptPath: 'missing.js');

  int calls = 0;

  @override
  Future<ProcessResult> run(List<String> args) {
    calls++;
    throw StateError('cli should not start');
  }
}
