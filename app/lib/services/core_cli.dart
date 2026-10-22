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

  static String _join(List<String> parts) => parts.join(Platform.pathSeparator);

  Future<bool> isAlive() async {
    try {
      final result = await run(const ['help']);
      final stdout = result.stdout;
      final text = stdout is String ? stdout : '';
      return result.exitCode == 0 || text.contains('uncloud');
    } on Object {
      return false;
    }
  }

  Future<ProcessResult> run(List<String> args) {
    return Process.run(nodeExecutable, [
      scriptPath,
      ...args,
    ], workingDirectory: File(scriptPath).parent.parent.path);
  }

  Future<Process> start(List<String> args) {
    return Process.start(nodeExecutable, [
      scriptPath,
      ...args,
    ], workingDirectory: File(scriptPath).parent.parent.path);
  }

  Future<List<PeerDevice>> scan({int timeoutMs = 3000}) async {
    try {
      final result = await run(['scan', '--json', '--timeout', '$timeoutMs']);
      if (result.exitCode != 0) return const [];
      final stdout = result.stdout;
      if (stdout is! String) return const [];
      final decoded = jsonDecode(stdout);
      if (decoded is! List<dynamic>) return const [];
      final now = DateTime.now();
      return [
        for (final item in decoded)
          if (item is Map) _peerFromScan(Map<String, dynamic>.from(item), now),
      ].whereType<PeerDevice>().toList();
    } on Object {
      return const [];
    }
  }

  PeerDevice? _peerFromScan(Map<String, dynamic> item, DateTime now) {
    final deviceId = item['deviceId'];
    final host = item['host'];
    final name = item['name'];
    if (deviceId is! String || deviceId.isEmpty) return null;
    if (host is! String || host.isEmpty) return null;
    final portValue = item['port'];
    final port = portValue is num ? portValue.toInt() : 47778;
    return PeerDevice(
      deviceId: deviceId,
      name: name is String && name.isNotEmpty ? name : 'peer',
      host: host,
      port: port,
      isPaired: false,
      lastSeen: now,
    );
  }

  Future<Map<String, dynamic>?> pairInfo({int port = 47778}) async {
    try {
      final result = await run(['pair', '--json', '--port', '$port']);
      if (result.exitCode != 0) return null;
      final stdout = result.stdout;
      if (stdout is! String) return null;
      final decoded = jsonDecode(stdout);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } on Object {
      return null;
    }
  }
}
