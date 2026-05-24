import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart';

bool isVoiceHelpCommand(String lowerCommand) {
  return voiceMatchesAny(lowerCommand, const ['help', 'get help']) ||
      lowerCommand == '帮助';
}

bool voiceMatchesAny(String value, List<String> candidates) {
  return candidates.any((candidate) => value.trim() == candidate);
}

String? stripVoicePrefix(String command, List<String> prefixes) {
  final trimmedCommand = trimVoiceArgument(command);
  final lower = trimmedCommand.toLowerCase();
  for (final prefix in prefixes) {
    final lowerPrefix = prefix.toLowerCase();
    if (lower == lowerPrefix) {
      return '';
    }
    if (lower.startsWith(lowerPrefix)) {
      return trimVoiceArgument(trimmedCommand.substring(prefix.length));
    }
  }
  return null;
}

String trimVoiceArgument(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'^[\s:：,，。.!！?？"“”‘’《》]+'), '')
      .replaceAll(RegExp(r'[\s"“”‘’《》]+$'), '')
      .trim();
}

bool voiceTextMatches(String value, String query) {
  return value.toLowerCase().contains(query.toLowerCase());
}

bool songTextMatches(LibrarySong song, String query, SmPlayerI18n i18n) {
  return voiceTextMatches(song.title, query) ||
      songArtistMatches(song, query) ||
      songAlbumMatches(song, query, i18n);
}

bool songArtistMatches(LibrarySong song, String query) {
  return songArtists(song).any((artist) => voiceTextMatches(artist, query));
}

bool songAlbumMatches(LibrarySong song, String query, SmPlayerI18n i18n) {
  return voiceTextMatches(displayAlbum(song, i18n), query);
}

String stripVoiceTargetType(String value, String type) {
  return value
      .replaceFirst(RegExp('^$type\\s+', caseSensitive: false), '')
      .trim();
}

String displayFolderNameForVoice(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  return index >= 0 ? normalized.substring(index + 1) : normalized;
}

int? firstVoiceNumber(String value) {
  final match = RegExp(r'\d+').firstMatch(value);
  return match == null ? null : int.parse(match.group(0)!);
}
