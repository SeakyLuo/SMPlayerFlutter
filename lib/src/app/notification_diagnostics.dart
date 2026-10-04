import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Temporary diagnostics for notification timing and UI isolate stalls.
class NotificationDiagnostics {
  static final _clock = Stopwatch()..start();
  static IOSink? _sink;
  static Timer? _sampler;
  static int _users = 0;

  static void record(String event, [Map<String, Object?> data = const {}]) {
    if (kReleaseMode) return;
    _sink ??= File(
      '${Directory.systemTemp.path}/smplayer-toast-$pid.jsonl',
    ).openWrite(mode: FileMode.append);
    _sink!.writeln(
      jsonEncode({
        'time': DateTime.now().toIso8601String(),
        'elapsedMs': _clock.elapsedMilliseconds,
        'event': event,
        ...data,
      }),
    );
  }

  static void attach() {
    if (kReleaseMode) return;
    _users += 1;
    record('host.attach', {'users': _users});
    if (_users != 1) return;
    SchedulerBinding.instance.addTimingsCallback(_frames);
    var previousMs = _clock.elapsedMilliseconds;
    var ticks = 0;
    _sampler = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final nowMs = _clock.elapsedMilliseconds;
      final gap = nowMs - previousMs;
      ticks += 1;
      if (gap > 500 || ticks % 4 == 0) {
        record('runtime.sample', {
          'uiCallbackGapMs': gap,
          'rssMb': ProcessInfo.currentRss / (1024 * 1024),
        });
      }
      previousMs = nowMs;
    });
  }

  static void detach() {
    if (kReleaseMode) return;
    _users -= 1;
    record('host.detach', {'users': _users});
    if (_users != 0) return;
    _sampler?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_frames);
    unawaited(_sink?.flush());
  }

  static void _frames(List<FrameTiming> frames) {
    for (final frame in frames) {
      if (frame.totalSpan.inMilliseconds < 50) continue;
      record('frame.slow', {
        'buildMs': frame.buildDuration.inMicroseconds / 1000,
        'rasterMs': frame.rasterDuration.inMicroseconds / 1000,
        'totalMs': frame.totalSpan.inMicroseconds / 1000,
      });
    }
  }
}
