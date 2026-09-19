import 'dart:convert';
import 'dart:io';

import '../models/device.dart';

/// Locates and runs the zero-dep Node core (`core/bin/uncloud.js`).
class CoreCli {
  CoreCli({required this.scriptPath, this.nodeExecutable = 'node'});

  final String scriptPath;
  final String nodeExecutable;

  static Future<CoreCli?> detect() async {
    final env = Platform.environment['UNCLOUD_CORE'];
    final cwd = Directory.current.path;
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = <String>[
      if (env != null && env.isNotEmpty) env,
      _join([cwd, '..', 'core', 'bin', 'uncloud.js']),
      _join([cwd, 'core', 'bin', 'uncloud.js']),
      _join([exeDir, 'uncloud.js']),
      _join([exeDir, '..', 'core', 'bin', 'uncloud.js']),
    ];
    for (final raw in candidates) {
      final file = File(raw);
      if (!file.existsSync()) continue;
      final cli = CoreCli(scriptPath: file.absolute.path);
      if (await cli.isAlive()) return cli;
    }
    return null;
  }

  static String _join(List<String> parts) =>
      parts.join(Platform.pathSeparator);

  Future<bool> isAlive() async {
    try {
      final r = await run(const ['help']);
      return r.exitCode == 0 || (r.stdout as String).contains('uncloud');
    } catch (_) {
      return false;
    }
  }

  Future<ProcessResult> run(List<String> args) {
    return Process.run(
      nodeExecutable,
      [scriptPath, ...args],
      workingDirectory: File(scriptPath).parent.parent.path,
    );
  }

  Future<Process> start(List<String> args) {
    return Process.start(
      nodeExecutable,
      [scriptPath, ...args],
      workingDirectory: File(scriptPath).parent.parent.path,
    );
  }

  Future<List<PeerDevice>> scan({int timeoutMs = 3000}) async {
    final r = await run(['scan', '--json', '--timeout', '$timeoutMs']);
    if (r.exitCode != 0) return const [];
    final decoded = jsonDecode(r.stdout as String);
    if (decoded is! List) return const [];
    final now = DateTime.now();
    return [
      for (final item in decoded)
        if (item is Map)
          PeerDevice(
            deviceId: '${item['deviceId'] ?? ''}',
            name: '${item['name'] ?? 'peer'}',
            host: '${item['host'] ?? ''}',
            port: (item['port'] as num?)?.toInt() ?? 47778,
            isPaired: false,
            lastSeen: now,
          ),
    ].where((d) => d.deviceId.isNotEmpty && d.host.isNotEmpty).toList();
  }

  Future<Map<String, dynamic>?> pairInfo({int port = 47778}) async {
    final r = await run(['pair', '--json', '--port', '$port']);
    if (r.exitCode != 0) return null;
    final decoded = jsonDecode(r.stdout as String);
    return decoded is Map<String, dynamic> ? decoded : null;
  }
}
