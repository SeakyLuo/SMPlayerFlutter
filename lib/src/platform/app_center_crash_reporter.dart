import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../library/data/library_repository_paths.dart';

const _appSecret = '8e3ac143-15c7-472c-b089-74707d7605c7';
const _ingestionUrl = 'https://in.appcenter.ms/logs?Api-Version=1.0.0';
const _uuid = Uuid();

/// App Center managed-error reporting, matching the Electron desktop app.
class AppCenterCrashReporter {
  final _launchTimestamp = DateTime.now().toUtc().toIso8601String();
  final _sessionId = _uuid.v4();
  final _reportedIssues = <String>{};
  Future<String>? _installId;

  bool get enabled => Platform.isWindows || Platform.isMacOS;

  void register() {
    if (!enabled) return;
    final previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      unawaited(
        report(
          details.exception,
          details.stack ?? StackTrace.empty,
          fatal: false,
        ),
      );
      previousFlutterHandler?.call(details);
    };
    final previousPlatformHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(report(error, stack, fatal: true));
      if (previousPlatformHandler != null) {
        return previousPlatformHandler(error, stack);
      }
      developer.log(
        'Unhandled platform error',
        error: error,
        stackTrace: stack,
      );
      return true;
    };
  }

  void handleUncaughtError(Object error, StackTrace stack) {
    if (!enabled) {
      Zone.current.handleUncaughtError(error, stack);
      return;
    }
    developer.log('Unhandled Dart error', error: error, stackTrace: stack);
    unawaited(report(error, stack, fatal: false));
  }

  Future<void> report(
    Object error,
    StackTrace stack, {
    required bool fatal,
  }) async {
    if (!enabled) return;
    final key = '${error.runtimeType}|$error|$stack';
    if (_reportedIssues.contains(key) || _reportedIssues.length >= 200) return;
    _reportedIssues.add(key);
    final client = HttpClient();
    try {
      await _send(
        client,
        error,
        stack,
        fatal,
      ).timeout(const Duration(seconds: 5));
    } on Object catch (reportingError) {
      // Reporting failures must never become another uncaught application error.
      developer.log(
        'App Center report failed',
        name: 'appcenter',
        error: reportingError,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _send(
    HttpClient client,
    Object error,
    StackTrace stack,
    bool fatal,
  ) async {
    final installId = await (_installId ??= _readInstallId());
    final package = await PackageInfo.fromPlatform();
    final timestamp = DateTime.now();
    final request = await client.postUrl(Uri.parse(_ingestionUrl));
    request.headers.contentType = ContentType.json;
    request.headers.set('App-Secret', _appSecret);
    request.headers.set('Install-ID', installId);
    request.write(
      jsonEncode({
        'logs': [
          {
            'type': 'managedError',
            'id': _uuid.v4(),
            'timestamp': timestamp.toUtc().toIso8601String(),
            'appLaunchTimestamp': _launchTimestamp,
            'fatal': fatal,
            'processId': pid,
            'processName': '${package.appName} Flutter',
            'sid': _sessionId,
            'device': {
              'appVersion': package.version,
              'appBuild': package.buildNumber,
              'appNamespace': 'com.seaky.simplemelodyplayer',
              'sdkName': 'appcenter.custom',
              'sdkVersion': '1.0.0',
              'osName':
                  Platform.isWindows ? 'WINDOWS' : Platform.operatingSystem,
              'osVersion': Platform.operatingSystemVersion,
              'locale': PlatformDispatcher.instance.locale.toLanguageTag(),
              'timeZoneOffset': timestamp.timeZoneOffset.inMinutes,
            },
            'exception': {
              'type': error.runtimeType.toString(),
              'message': error.toString(),
              'stackTrace': stack.toString(),
            },
          },
        ],
      }),
    );
    final response = await request.close();
    await response.drain<void>();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('App Center returned HTTP ${response.statusCode}');
    }
  }

  Future<String> _readInstallId() async {
    final file = File(
      p.join(defaultSmPlayerUserDataPath(), 'app-center-install-id'),
    );
    if (await file.exists()) return (await file.readAsString()).trim();
    await file.parent.create(recursive: true);
    final id = _uuid.v4();
    await file.writeAsString(id, flush: true);
    return id;
  }
}
