import 'dart:math';

import 'package:smplayer_flutter/src/library/data/library_models.dart';

String resolveLyricText({
  required LyricsSnapshot lyrics,
  required double progressSeconds,
  required double progressRatio,
}) {
  final timedLines =
      lyrics.lines.where((line) => line.timestampMs != null).toList();
  if (timedLines.isNotEmpty) {
    final progressMs = max(0, (progressSeconds * 1000).floor());
    var currentText = '';
    for (final line in timedLines) {
      if (line.timestampMs! > progressMs) {
        break;
      }
      currentText = line.text;
    }
    return toSingleDisplayLyricLine(currentText);
  }

  final lyricIndex = min(
    lyrics.lines.length - 1,
    (lyrics.lines.length * progressRatio.clamp(0, 1)).floor(),
  );
  return toSingleDisplayLyricLine(lyrics.lines[lyricIndex].text);
}

String toSingleDisplayLyricLine(String text) {
  final normalizedText = text
      .replaceAll(RegExp(r'\\r\\n|\\n|\\r'), '\n')
      .replaceAll(RegExp(r'\r\n|[\n\r\u2028\u2029]'), '\n');
  for (final segment in normalizedText.split('\n')) {
    final candidate = segment.trim();
    if (candidate.isNotEmpty) {
      return candidate;
    }
  }
  return '';
}
