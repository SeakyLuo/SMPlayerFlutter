part of 'library_lyrics_service.dart';

extension _LibraryLyricsParser on LibraryLyricsService {
  LyricsSnapshot _createLyricsSnapshot(String rawText, LyricsSource source) {
    final normalizedText = rawText.replaceFirst('\uFEFF', '').trim();
    final lines = _parseLyricsLines(normalizedText);
    if (_isInstrumentalLyrics(lines)) {
      return const LyricsSnapshot(
        source: LyricsSource.none,
        isSynced: false,
        rawText: '',
        lines: [],
      );
    }
    return LyricsSnapshot(
      source: source,
      isSynced: lines.any((line) => line.timestampMs != null),
      rawText: normalizedText,
      lines: lines,
    );
  }

  List<LyricsLine> _parseLyricsLines(String rawText) {
    if (rawText.isEmpty) {
      return [];
    }

    final metadataRegex = RegExp(
      r'^\[(ti|ar|al|au|by|offset|re|ve|length):',
      caseSensitive: false,
    );
    final offsetRegex = RegExp(
      r'^\[offset:([+-]?\d+)\]$',
      caseSensitive: false,
    );
    final timestampRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');
    var offsetMs = 0;
    var lineId = 0;
    final parsedLines = <LyricsLine>[];

    for (final rawLine in rawText.split(RegExp(r'\r\n|[\n\r\u2028\u2029]'))) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      final offsetMatch = offsetRegex.firstMatch(line);
      if (offsetMatch != null) {
        offsetMs = int.parse(offsetMatch.group(1)!);
        continue;
      }
      if (metadataRegex.hasMatch(line)) {
        continue;
      }

      final matches = timestampRegex.allMatches(line).toList();
      final text = line.replaceAll(timestampRegex, '').trim();
      if (matches.isEmpty) {
        parsedLines.add(LyricsLine(id: lineId, timestampMs: null, text: line));
        lineId += 1;
        continue;
      }
      if (text.isEmpty) {
        continue;
      }

      for (final match in matches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final fraction = match.group(3) ?? '0';
        final fractionMs =
            fraction.length == 1
                ? int.parse(fraction) * 100
                : fraction.length == 2
                ? int.parse(fraction) * 10
                : int.parse(fraction.padRight(3, '0').substring(0, 3));
        parsedLines.add(
          LyricsLine(
            id: lineId,
            timestampMs: math.max(
              0,
              minutes * 60000 + seconds * 1000 + fractionMs + offsetMs,
            ),
            text: text,
          ),
        );
        lineId += 1;
      }
    }
    parsedLines.sort((left, right) {
      final leftTimestamp = left.timestampMs;
      final rightTimestamp = right.timestampMs;
      if (leftTimestamp == null && rightTimestamp == null) {
        return left.id.compareTo(right.id);
      }
      if (leftTimestamp == null) {
        return -1;
      }
      if (rightTimestamp == null) {
        return 1;
      }
      final timestampCompare = leftTimestamp.compareTo(rightTimestamp);
      return timestampCompare == 0
          ? left.id.compareTo(right.id)
          : timestampCompare;
    });
    return parsedLines;
  }

  bool _isInstrumentalLyrics(List<LyricsLine> lines) {
    return lines.isNotEmpty &&
        lines.every(
          (line) => line.text.toLowerCase() == '[instrumental]\u0000',
        );
  }
}
