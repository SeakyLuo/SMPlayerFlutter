import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

const nowPlayingQuickPlayLimit = 100;

String getDefaultNewPlaylistName(
  SmPlayerI18n i18n,
  List<LibraryPlaylist> playlists,
) {
  final now = DateTime.now();
  final year = (now.year % 100).toString().padLeft(2, '0');
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return getNextPlaylistName(
    '${i18n.t('common.nowPlaying')} - $year/$month/$day',
    playlists,
  );
}

String getNextPlaylistName(String name, List<LibraryPlaylist> playlists) {
  final playlistNames = playlists.map((playlist) => playlist.name).toSet();
  final siblingCount =
      playlists.where((playlist) => playlist.name.startsWith(name)).length;
  for (var index = 1; index <= siblingCount; index += 1) {
    final nextName = '$name ($index)';
    if (!playlistNames.contains(nextName)) {
      return nextName;
    }
  }

  return name;
}

int getCurrentClockMinute() {
  final now = DateTime.now();
  return now.hour * 60 + now.minute;
}

int timeToMinute(String value) {
  final parts = value.split(':').map(int.parse).toList();
  return parts[0] * 60 + parts[1];
}

bool isMinuteInNightRange(int current, int start, int end) {
  if (start < end) {
    return current >= start && current < end;
  }

  return current >= start || current < end;
}

bool isNowPlayingFullNightMode(SettingsSnapshot settings) {
  return switch (settings.nightMode) {
    NightMode.onMode => true,
    NightMode.never => false,
    NightMode.auto => isMinuteInNightRange(
      getCurrentClockMinute(),
      timeToMinute(settings.nightModeStartTime),
      timeToMinute(settings.nightModeEndTime),
    ),
  };
}
