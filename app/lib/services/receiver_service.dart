import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'core_cli.dart';

/// Keeps `uncloud serve` running on desktop so this PC can receive files.
class ReceiverService {
  ReceiverService(this.cli);

  final CoreCli cli;
  Process? _process;
  String? inboxDir;
  int port = 47778;

  bool get isRunning => _process != null;

  Future<void> start() async {
    if (_process != null) return;
    final docs = await getApplicationDocumentsDirectory();
    inboxDir = '${docs.path}${Platform.pathSeparator}Uncloud';
    await Directory(inboxDir!).create(recursive: true);
    _process = await cli.start(['serve', '--port', '$port', '--dir', inboxDir!]);
    _process!.exitCode.then((_) {
      _process = null;
    });
  }

  Future<void> stop() async {
    _process?.kill();
    _process = null;
  }
}
