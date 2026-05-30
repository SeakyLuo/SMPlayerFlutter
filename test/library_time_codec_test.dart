import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/library/data/library_time_codec.dart';

void main() {
  test('parseStoredDateTime parses .NET ticks', () {
    final date = LibraryTimeCodec.parseStoredDateTime('637270356960000000');

    expect(date.toIso8601String(), '2020-06-06T10:21:36.000Z');
  });

  test('parseStoredDateTime parses Unix milliseconds', () {
    final date = LibraryTimeCodec.parseStoredDateTime('1715385600000');

    expect(date.toIso8601String(), '2024-05-11T00:00:00.000Z');
  });

  test('parseStoredDateTime parses ISO string', () {
    final date = LibraryTimeCodec.parseStoredDateTime('2026-05-22T00:00:00.000Z');

    expect(date.toIso8601String(), '2026-05-22T00:00:00.000Z');
  });

  test('nowUnixMillisecondsString returns numeric timestamp', () {
    final raw = LibraryTimeCodec.nowUnixMillisecondsString();

    expect(int.tryParse(raw), isNotNull);
  });
}


