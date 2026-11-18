import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class MusicShareBackgroundPlatform {
  static const channel = MethodChannel('smplayer_flutter/background_sharing');
  static Process? _child;
  static bool _childRunning = false;
  static bool get supported =>
      Platform.isWindows ||
      Platform.isMacOS ||
      Platform.isLinux ||
      Platform.isAndroid;

  static Future<bool> available() async {
    if (!supported) return false;
    if (Platform.isLinux) return true;
    return (await channel.invokeMethod<bool>('supported'))!;
  }

  /// Launches the OS host; the client awaits its private socket separately.
  static Future<void> start() async {
    if (!Platform.isLinux) {
      await channel.invokeMethod<void>('start');
    } else {
      _child = await Process.start('/bin/sh', [
        '-c',
        r'exec "$1" --sharing-worker </dev/null >/dev/null 2>&1',
        'smplayer-sharing',
        Platform.resolvedExecutable,
      ]);
      _childRunning = true;
      unawaited(_child!.exitCode.then((_) => _childRunning = false));
    }
  }

  static Future<void> setLoginEnabled(bool enabled) async {
    if (!Platform.isLinux) {
      await channel.invokeMethod<void>('setLoginEnabled', enabled);
      return;
    }
    final config =
        Platform.environment['XDG_CONFIG_HOME'] ??
        p.join(Platform.environment['HOME']!, '.config');
    final file = File(p.join(config, 'autostart', 'smplayer-sharing.desktop'));
    if (!enabled) {
      if (await file.exists()) await file.delete();
      return;
    }
    final executable = Platform.resolvedExecutable
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('%', '%%')
        .replaceAll('`', '\\`')
        .replaceAll('\$', '\\\$');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '[Desktop Entry]\nType=Application\nName=Simple Melody Player Sharing\nExec="$executable" --sharing-worker\nTerminal=false\nX-GNOME-Autostart-enabled=true\n',
      flush: true,
    );
  }

  static Future<void> stop() async {
    if (Platform.isLinux) {
      if (_childRunning) {
        _child!.kill();
        await _child!.exitCode;
      }
    } else {
      await channel.invokeMethod<void>('stop');
    }
  }

  static Future<void> openSettings() =>
      channel.invokeMethod<void>('openSettings');
}
