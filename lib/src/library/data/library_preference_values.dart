part of 'library_preference_service.dart';

int _toPreferenceEntityValue(String type) {
  return switch (type) {
    'song' => 0,
    'artist' => 1,
    'album' => 2,
    'playlist' => 3,
    'folder' => 4,
    'recent-added' => 5,
    'my-favorites' => 6,
    'most-played' => 7,
    'least-played' => 8,
    _ => throw ArgumentError.value(type, 'type'),
  };
}

PreferenceEntityType _preferenceEntityTypeFromValue(int type) {
  return switch (type) {
    0 => PreferenceEntityType.song,
    1 => PreferenceEntityType.artist,
    2 => PreferenceEntityType.album,
    3 => PreferenceEntityType.playlist,
    4 => PreferenceEntityType.folder,
    5 => PreferenceEntityType.recentAdded,
    6 => PreferenceEntityType.myFavorites,
    7 => PreferenceEntityType.mostPlayed,
    8 => PreferenceEntityType.leastPlayed,
    _ => throw ArgumentError.value(type, 'type'),
  };
}

String _preferenceEntityTypeName(PreferenceEntityType type) {
  return switch (type) {
    PreferenceEntityType.song => 'song',
    PreferenceEntityType.artist => 'artist',
    PreferenceEntityType.album => 'album',
    PreferenceEntityType.playlist => 'playlist',
    PreferenceEntityType.folder => 'folder',
    PreferenceEntityType.recentAdded => 'recent-added',
    PreferenceEntityType.myFavorites => 'my-favorites',
    PreferenceEntityType.mostPlayed => 'most-played',
    PreferenceEntityType.leastPlayed => 'least-played',
  };
}

int _toPreferenceLevelValue(String level) {
  return switch (level) {
    'do-not-appear' => 0,
    'dislike' => -1,
    'normal' => 1,
    'high' => 2,
    'higher' => 3,
    'very-high' => 4,
    _ => throw ArgumentError.value(level, 'level'),
  };
}

PreferenceLevel _preferenceLevelFromValue(int level) {
  return switch (level) {
    0 => PreferenceLevel.doNotAppear,
    -1 => PreferenceLevel.dislike,
    2 => PreferenceLevel.high,
    3 => PreferenceLevel.higher,
    4 => PreferenceLevel.veryHigh,
    _ => PreferenceLevel.normal,
  };
}

String _preferenceLevelName(PreferenceLevel level) {
  return switch (level) {
    PreferenceLevel.doNotAppear => 'do-not-appear',
    PreferenceLevel.dislike => 'dislike',
    PreferenceLevel.normal => 'normal',
    PreferenceLevel.high => 'high',
    PreferenceLevel.higher => 'higher',
    PreferenceLevel.veryHigh => 'very-high',
  };
}

String _toPreferenceLevelName(int level) {
  return switch (level) {
    0 => 'do-not-appear',
    -1 => 'dislike',
    1 => 'normal',
    2 => 'high',
    3 => 'higher',
    4 => 'very-high',
    _ => 'normal',
  };
}

String _preferenceSectionColumnName(PreferenceSectionKey key) {
  return switch (key) {
    PreferenceSectionKey.songs => 'Songs',
    PreferenceSectionKey.artists => 'Artists',
    PreferenceSectionKey.albums => 'Albums',
    PreferenceSectionKey.playlists => 'Playlists',
    PreferenceSectionKey.folders => 'Folders',
  };
}

String _preferenceFolderName(String folderPath) {
  final separatorIndex = folderPath.lastIndexOf(RegExp(r'[\\/]'));
  return separatorIndex < 0
      ? folderPath
      : folderPath.substring(separatorIndex + 1);
}
