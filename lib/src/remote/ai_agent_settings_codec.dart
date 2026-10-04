import '../settings/settings_model.dart';

/// The editable preferences shared with the settings page. Library migration
/// and the API's own lifecycle are operations, not plain preference writes.
class AiAgentSettingsCodec {
  static Map<String, Object?> read(SettingsSnapshot snapshot) => {
    'useFilenameNotMusicName': snapshot.useFilenameNotMusicName,
    'smartMultiArtistRecognition': snapshot.smartMultiArtistRecognition,
    'showCount': snapshot.showCount,
    'showNotifications': snapshot.showNotifications,
    'autoLyrics': snapshot.autoLyrics,
    'showLyricsInNotification': snapshot.showLyricsInNotification,
    'saveLyricsImmediately': snapshot.saveLyricsImmediately,
    'preserveInternetLyricsTimestamps':
        snapshot.preserveInternetLyricsTimestamps,
    'desktopLyricsEnabled': snapshot.desktopLyricsEnabled,
    'desktopLyricsLocked': snapshot.desktopLyricsLocked,
    'autoPlay': snapshot.autoPlay,
    'shuffleAfterOneRound': snapshot.shuffleAfterOneRound,
    'previousButtonRestartsTrack': snapshot.previousButtonRestartsTrack,
    'saveMusicProgress': snapshot.saveMusicProgress,
    'hideMultiSelectCommandBarAfterOperation':
        snapshot.hideMultiSelectCommandBarAfterOperation,
    'quitOnClose': snapshot.quitOnClose,
    'nightMode': snapshot.nightMode.name,
    'notificationSend': snapshot.notificationSend.name,
    'notificationDisplay': snapshot.notificationDisplay.name,
    'notificationLyricsSource': snapshot.notificationLyricsSource.name,
    'playerLyricsSource': snapshot.playerLyricsSource.name,
    'preferredLanguage': snapshot.preferredLanguage.name,
    'musicLibrarySort': snapshot.musicLibrarySort.name,
    'albumsSort': snapshot.albumsSort.name,
    'searchArtistsCriterion': snapshot.searchArtistsCriterion.name,
    'searchAlbumsCriterion': snapshot.searchAlbumsCriterion.name,
    'searchSongsCriterion': snapshot.searchSongsCriterion.name,
    'searchPlaylistsCriterion': snapshot.searchPlaylistsCriterion.name,
    'searchFoldersCriterion': snapshot.searchFoldersCriterion.name,
    'localViewMode': snapshot.localViewMode.name,
    'themeColor': snapshot.themeColor,
    'desktopLyricsColor': snapshot.desktopLyricsColor,
    'desktopLyricsStrokeColor': snapshot.desktopLyricsStrokeColor,
    'nightModeStartTime': snapshot.nightModeStartTime,
    'nightModeEndTime': snapshot.nightModeEndTime,
    'desktopLyricsFontSize': snapshot.desktopLyricsFontSize,
    'desktopLyricsOpacity': snapshot.desktopLyricsOpacity,
    'desktopLyricsFontFamily': snapshot.desktopLyricsFontFamily,
  };

  static Map<String, Object?> schema(List<String> fonts) => {
    'useFilenameNotMusicName': {'type': 'boolean'},
    'smartMultiArtistRecognition': {'type': 'boolean'},
    'showCount': {'type': 'boolean'},
    'showNotifications': {'type': 'boolean'},
    'autoLyrics': {'type': 'boolean'},
    'showLyricsInNotification': {'type': 'boolean'},
    'saveLyricsImmediately': {'type': 'boolean'},
    'preserveInternetLyricsTimestamps': {'type': 'boolean'},
    'desktopLyricsEnabled': {'type': 'boolean'},
    'desktopLyricsLocked': {'type': 'boolean'},
    'autoPlay': {'type': 'boolean'},
    'shuffleAfterOneRound': {'type': 'boolean'},
    'previousButtonRestartsTrack': {'type': 'boolean'},
    'saveMusicProgress': {'type': 'boolean'},
    'hideMultiSelectCommandBarAfterOperation': {'type': 'boolean'},
    'quitOnClose': {'type': 'boolean'},
    'nightMode': {
      'type': 'string',
      'values': NightMode.values.map((value) => value.name).toList(),
    },
    'notificationSend': {
      'type': 'string',
      'values': NotificationSendMode.values.map((value) => value.name).toList(),
    },
    'notificationDisplay': {
      'type': 'string',
      'values':
          NotificationDisplayMode.values.map((value) => value.name).toList(),
    },
    'notificationLyricsSource': {
      'type': 'string',
      'values': LyricsRequestMode.values.map((value) => value.name).toList(),
    },
    'playerLyricsSource': {
      'type': 'string',
      'values': LyricsRequestMode.values.map((value) => value.name).toList(),
    },
    'preferredLanguage': {
      'type': 'string',
      'values': PreferredLanguage.values.map((value) => value.name).toList(),
    },
    'musicLibrarySort': {
      'type': 'string',
      'values':
          MusicLibrarySortCriterion.values.map((value) => value.name).toList(),
    },
    'albumsSort': {
      'type': 'string',
      'values': AlbumSortCriterion.values.map((value) => value.name).toList(),
    },
    'searchArtistsCriterion': {
      'type': 'string',
      'values': SearchSortCriterion.values.map((value) => value.name).toList(),
    },
    'searchAlbumsCriterion': {
      'type': 'string',
      'values': SearchSortCriterion.values.map((value) => value.name).toList(),
    },
    'searchSongsCriterion': {
      'type': 'string',
      'values': SearchSortCriterion.values.map((value) => value.name).toList(),
    },
    'searchPlaylistsCriterion': {
      'type': 'string',
      'values': SearchSortCriterion.values.map((value) => value.name).toList(),
    },
    'searchFoldersCriterion': {
      'type': 'string',
      'values': SearchSortCriterion.values.map((value) => value.name).toList(),
    },
    'localViewMode': {
      'type': 'string',
      'values': LocalViewMode.values.map((value) => value.name).toList(),
    },
    'themeColor': {'type': 'string', 'format': '#RRGGBB'},
    'desktopLyricsColor': {'type': 'string', 'format': '#RRGGBB'},
    'desktopLyricsStrokeColor': {'type': 'string', 'format': '#RRGGBB'},
    'nightModeStartTime': {'type': 'string', 'format': 'HH:mm'},
    'nightModeEndTime': {'type': 'string', 'format': 'HH:mm'},
    'desktopLyricsFontSize': {'type': 'integer', 'min': 20, 'max': 48},
    'desktopLyricsOpacity': {'type': 'integer', 'min': 45, 'max': 100},
    'desktopLyricsFontFamily': {'type': 'string', 'values': fonts},
  };

  static AppSettingsUpdate decode(
    Map<String, dynamic> properties,
    List<String> fonts,
  ) {
    if (properties.isEmpty) {
      throw const FormatException('No settings supplied');
    }
    final fields = schema(fonts);
    for (final entry in properties.entries) {
      final field = fields[entry.key] as Map<String, Object?>?;
      if (field == null) {
        throw FormatException('Setting is not editable: ${entry.key}');
      }
      final value = entry.value;
      final validType = switch (field['type']) {
        'boolean' => value is bool,
        'integer' => value is int,
        'string' => value is String,
        _ => throw StateError('Unknown settings schema type'),
      };
      if (!validType) {
        throw FormatException('Invalid type for ${entry.key}');
      }
      if (field.containsKey('values') &&
          !(field['values'] as List).contains(value)) {
        throw FormatException('Invalid option for ${entry.key}');
      }
      if (field['type'] == 'integer' &&
          ((value as int) < (field['min'] as int) ||
              value > (field['max'] as int))) {
        throw FormatException('Out of range: ${entry.key}');
      }
      if (field['format'] == '#RRGGBB' &&
          !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value as String)) {
        throw FormatException('Invalid color for ${entry.key}');
      }
      if (field['format'] == 'HH:mm' &&
          !RegExp(
            r'^([01][0-9]|2[0-3]):[0-5][0-9]$',
          ).hasMatch(value as String)) {
        throw FormatException('Invalid time for ${entry.key}');
      }
    }
    return AppSettingsUpdate(
      useFilenameNotMusicName: properties['useFilenameNotMusicName'] as bool?,
      smartMultiArtistRecognition:
          properties['smartMultiArtistRecognition'] as bool?,
      showCount: properties['showCount'] as bool?,
      showNotifications: properties['showNotifications'] as bool?,
      autoLyrics: properties['autoLyrics'] as bool?,
      showLyricsInNotification: properties['showLyricsInNotification'] as bool?,
      saveLyricsImmediately: properties['saveLyricsImmediately'] as bool?,
      preserveInternetLyricsTimestamps:
          properties['preserveInternetLyricsTimestamps'] as bool?,
      desktopLyricsEnabled: properties['desktopLyricsEnabled'] as bool?,
      desktopLyricsLocked: properties['desktopLyricsLocked'] as bool?,
      autoPlay: properties['autoPlay'] as bool?,
      shuffleAfterOneRound: properties['shuffleAfterOneRound'] as bool?,
      previousButtonRestartsTrack:
          properties['previousButtonRestartsTrack'] as bool?,
      saveMusicProgress: properties['saveMusicProgress'] as bool?,
      hideMultiSelectCommandBarAfterOperation:
          properties['hideMultiSelectCommandBarAfterOperation'] as bool?,
      quitOnClose: properties['quitOnClose'] as bool?,
      nightMode:
          properties.containsKey('nightMode')
              ? NightMode.values.byName(properties['nightMode'] as String)
              : null,
      notificationSend:
          properties.containsKey('notificationSend')
              ? NotificationSendMode.values.byName(
                properties['notificationSend'] as String,
              )
              : null,
      notificationDisplay:
          properties.containsKey('notificationDisplay')
              ? NotificationDisplayMode.values.byName(
                properties['notificationDisplay'] as String,
              )
              : null,
      notificationLyricsSource:
          properties.containsKey('notificationLyricsSource')
              ? LyricsRequestMode.values.byName(
                properties['notificationLyricsSource'] as String,
              )
              : null,
      playerLyricsSource:
          properties.containsKey('playerLyricsSource')
              ? LyricsRequestMode.values.byName(
                properties['playerLyricsSource'] as String,
              )
              : null,
      preferredLanguage:
          properties.containsKey('preferredLanguage')
              ? PreferredLanguage.values.byName(
                properties['preferredLanguage'] as String,
              )
              : null,
      musicLibrarySort:
          properties.containsKey('musicLibrarySort')
              ? MusicLibrarySortCriterion.values.byName(
                properties['musicLibrarySort'] as String,
              )
              : null,
      albumsSort:
          properties.containsKey('albumsSort')
              ? AlbumSortCriterion.values.byName(
                properties['albumsSort'] as String,
              )
              : null,
      searchArtistsCriterion:
          properties.containsKey('searchArtistsCriterion')
              ? SearchSortCriterion.values.byName(
                properties['searchArtistsCriterion'] as String,
              )
              : null,
      searchAlbumsCriterion:
          properties.containsKey('searchAlbumsCriterion')
              ? SearchSortCriterion.values.byName(
                properties['searchAlbumsCriterion'] as String,
              )
              : null,
      searchSongsCriterion:
          properties.containsKey('searchSongsCriterion')
              ? SearchSortCriterion.values.byName(
                properties['searchSongsCriterion'] as String,
              )
              : null,
      searchPlaylistsCriterion:
          properties.containsKey('searchPlaylistsCriterion')
              ? SearchSortCriterion.values.byName(
                properties['searchPlaylistsCriterion'] as String,
              )
              : null,
      searchFoldersCriterion:
          properties.containsKey('searchFoldersCriterion')
              ? SearchSortCriterion.values.byName(
                properties['searchFoldersCriterion'] as String,
              )
              : null,
      localViewMode:
          properties.containsKey('localViewMode')
              ? LocalViewMode.values.byName(
                properties['localViewMode'] as String,
              )
              : null,
      themeColor: properties['themeColor'] as String?,
      desktopLyricsColor: properties['desktopLyricsColor'] as String?,
      desktopLyricsStrokeColor:
          properties['desktopLyricsStrokeColor'] as String?,
      nightModeStartTime: properties['nightModeStartTime'] as String?,
      nightModeEndTime: properties['nightModeEndTime'] as String?,
      desktopLyricsFontSize: properties['desktopLyricsFontSize'] as int?,
      desktopLyricsOpacity: properties['desktopLyricsOpacity'] as int?,
      desktopLyricsFontFamily: properties['desktopLyricsFontFamily'] as String?,
    );
  }
}
