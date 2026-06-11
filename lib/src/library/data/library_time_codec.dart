class LibraryTimeCodec {
  const LibraryTimeCodec._();

  static const int _dotNetUnixEpochTicks = 621355968000000000;
  static const int _ticksPerMillisecond = 10000;
  static const int _unixSecondsCutoff = 10000000000;
  static const int _unixMillisecondsCutoff = 1000000000000;
  static const int _dotNetTicksCutoff = 100000000000000000;

  static String nowUnixMillisecondsString() {
    return DateTime.now().toUtc().millisecondsSinceEpoch.toString();
  }

  static DateTime parseStoredDateTime(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    final numeric = int.tryParse(trimmed);
    if (numeric == null) {
      return DateTime.parse(trimmed).toUtc();
    }

    if (numeric >= _dotNetTicksCutoff) {
      final millisecondsSinceEpoch =
          (numeric - _dotNetUnixEpochTicks) ~/ _ticksPerMillisecond;
      return DateTime.fromMillisecondsSinceEpoch(
        millisecondsSinceEpoch,
        isUtc: true,
      );
    }

    if (numeric >= _unixMillisecondsCutoff) {
      return DateTime.fromMillisecondsSinceEpoch(numeric, isUtc: true);
    }

    if (numeric >= _unixSecondsCutoff) {
      return DateTime.fromMillisecondsSinceEpoch(numeric * 1000, isUtc: true);
    }

    return DateTime.fromMillisecondsSinceEpoch(numeric, isUtc: true);
  }

  static int toSortMilliseconds(String rawValue) {
    return parseStoredDateTime(rawValue).millisecondsSinceEpoch;
  }
}
