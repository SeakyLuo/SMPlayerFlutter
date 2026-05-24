part of 'shell_page.dart';

bool _isVoiceHelpCommand(String lowerCommand) {
  return _matchesAny(lowerCommand, const ['help', 'get help']) ||
      lowerCommand == '帮助';
}

bool _matchesAny(String value, List<String> candidates) {
  return candidates.any((candidate) => value.trim() == candidate);
}

String? _stripVoicePrefix(String command, List<String> prefixes) {
  final trimmedCommand = _trimVoiceArgument(command);
  final lower = trimmedCommand.toLowerCase();
  for (final prefix in prefixes) {
    final lowerPrefix = prefix.toLowerCase();
    if (lower == lowerPrefix) {
      return '';
    }
    if (lower.startsWith(lowerPrefix)) {
      return _trimVoiceArgument(trimmedCommand.substring(prefix.length));
    }
  }
  return null;
}

String _trimVoiceArgument(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'^[\s:：,，。.!！?？"“”‘’《》]+'), '')
      .replaceAll(RegExp(r'[\s"“”‘’《》]+$'), '')
      .trim();
}

bool _voiceTextMatches(String value, String query) {
  return value.toLowerCase().contains(query.toLowerCase());
}

bool _songTextMatches(LibrarySong song, String query, SmPlayerI18n i18n) {
  return _voiceTextMatches(song.title, query) ||
      _songArtistMatches(song, query) ||
      _songAlbumMatches(song, query, i18n);
}

bool _songArtistMatches(LibrarySong song, String query) {
  return songArtists(song).any((artist) => _voiceTextMatches(artist, query));
}

bool _songAlbumMatches(LibrarySong song, String query, SmPlayerI18n i18n) {
  return _voiceTextMatches(displayAlbum(song, i18n), query);
}

String _stripVoiceTargetType(String value, String type) {
  return value
      .replaceFirst(RegExp('^$type\\s+', caseSensitive: false), '')
      .trim();
}

String _displayFolderName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  return index >= 0 ? normalized.substring(index + 1) : normalized;
}

int? _firstVoiceNumber(String value) {
  final match = RegExp(r'\d+').firstMatch(value);
  return match == null ? null : int.parse(match.group(0)!);
}
