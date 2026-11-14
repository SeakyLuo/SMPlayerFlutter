import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import '../library/data/library_repository_paths.dart';

/// Daily local logs, following the UWP SMPlayerLog naming and retention.
class SystemLog {
  static bool get _enabled =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  static final Future<Directory> directory = _resolveDirectory();
  static Future<void> _pending = Future<void>.value();
  static String? _lastDate;

  static Future<void> initialize() async {
    if (!_enabled) return;
    final package = await PackageInfo.fromPlatform();
    info(
      'Application started: ${package.version}+${package.buildNumber}; '
      '${Platform.operatingSystem} ${Platform.operatingSystemVersion}; '
      'pid=$pid',
    );
    await flush();
  }

  static void info(String message) => _write('Info', message);

  static void warning(String message) => _write('Warn', message);

  static void error(String message, Object error, StackTrace stack) =>
      _write('Error', '$message\n$error\n$stack');

  static Future<void> flush() => _pending;

  static Future<Directory> _resolveDirectory() async {
    final packageDataPath =
        Platform.isWindows ? await windowsPackageApplicationDataPath : null;
    return Directory(
      p.join(packageDataPath ?? await defaultSmPlayerUserDataPath(), 'Logs'),
    );
  }

  static void _write(String level, String message) {
    if (!_enabled) return;
    final now = DateTime.now();
    final date = now.toIso8601String().substring(0, 10);
    final line = '${now.toIso8601String()} [$level] $message\n';
    _pending = _pending
        .then((_) async {
          final logsDirectory = await directory;
          if (_lastDate != date) {
            await logsDirectory.create(recursive: true);
          }
          await File(
            p.join(logsDirectory.path, 'SMPlayerLog_$date.log'),
          ).writeAsString(line, mode: FileMode.append, flush: true);
          if (_lastDate != date) {
            await _clearOldLogs(logsDirectory);
            _lastDate = date;
          }
        })
        .catchError((Object error, StackTrace stack) {
          // Logging failures must not interrupt playback or recursively log errors.
          developer.log(
            'Unable to write system log',
            name: 'SystemLog',
            error: error,
            stackTrace: stack,
          );
        });
  }

  static Future<void> _clearOldLogs(Directory directory) async {
    final files =
        await directory.list().where((entry) {
          return entry is File &&
              RegExp(
                r'^SMPlayerLog_\d{4}-\d{2}-\d{2}\.log$',
              ).hasMatch(p.basename(entry.path));
        }).toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    for (final file in files.skip(5)) {
      await file.delete();
    }
  }
}
