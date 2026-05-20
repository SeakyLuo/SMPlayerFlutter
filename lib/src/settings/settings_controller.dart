import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

class SettingsController extends ChangeNotifier {
  SettingsController([SettingsSnapshot? initialSnapshot])
    : _snapshot = initialSnapshot ?? const SettingsSnapshot.defaults();

  SettingsSnapshot _snapshot;

  SettingsSnapshot get snapshot => _snapshot;

  Future<void> refresh() async {
    final preferences = await SharedPreferences.getInstance();
    _snapshot = _snapshot.copyWith(
      rootPath:
          preferences.getString(SmPlayerSettingsStorageKeys.rootPath) ??
          _snapshot.rootPath,
      useFilenameNotMusicName:
          preferences.getBool(
            SmPlayerSettingsStorageKeys.useFilenameNotMusicName,
          ) ??
          _snapshot.useFilenameNotMusicName,
      smartMultiArtistRecognition:
          preferences.getBool(
            SmPlayerSettingsStorageKeys.smartMultiArtistRecognition,
          ) ??
          _snapshot.smartMultiArtistRecognition,
      showCount:
          preferences.getBool(SmPlayerSettingsStorageKeys.showCount) ??
          _snapshot.showCount,
      themeColor:
          preferences.getString(SmPlayerSettingsStorageKeys.themeColor) ??
          _snapshot.themeColor,
      nightMode: _readNightMode(preferences) ?? _snapshot.nightMode,
      nightModeStartTime:
          preferences.getString(
            SmPlayerSettingsStorageKeys.nightModeStartTime,
          ) ??
          _snapshot.nightModeStartTime,
      nightModeEndTime:
          preferences.getString(SmPlayerSettingsStorageKeys.nightModeEndTime) ??
          _snapshot.nightModeEndTime,
      notificationSend:
          _readNotificationSend(preferences) ?? _snapshot.notificationSend,
      notificationDisplay:
          _readNotificationDisplay(preferences) ??
          _snapshot.notificationDisplay,
      showNotifications:
          preferences.getBool(SmPlayerSettingsStorageKeys.showNotifications) ??
          _snapshot.showNotifications,
      autoLyrics:
          preferences.getBool(SmPlayerSettingsStorageKeys.autoLyrics) ??
          _snapshot.autoLyrics,
      showLyricsInNotification:
          preferences.getBool(
            SmPlayerSettingsStorageKeys.showLyricsInNotification,
          ) ??
          _snapshot.showLyricsInNotification,
      notificationLyricsSource:
          _readLyricsRequestMode(
            preferences,
            SmPlayerSettingsStorageKeys.notificationLyricsSource,
          ) ??
          _snapshot.notificationLyricsSource,
      playerLyricsSource:
          _readLyricsRequestMode(
            preferences,
            SmPlayerSettingsStorageKeys.playerLyricsSource,
          ) ??
          _snapshot.playerLyricsSource,
      saveLyricsImmediately:
          preferences.getBool(
            SmPlayerSettingsStorageKeys.saveLyricsImmediately,
          ) ??
          _snapshot.saveLyricsImmediately,
      preserveInternetLyricsTimestamps:
          preferences.getBool(
            SmPlayerSettingsStorageKeys.preserveInternetLyricsTimestamps,
          ) ??
          _snapshot.preserveInternetLyricsTimestamps,
      desktopLyricsEnabled:
          preferences.getBool(
            SmPlayerSettingsStorageKeys.desktopLyricsEnabled,
          ) ??
          _snapshot.desktopLyricsEnabled,
      desktopLyricsLocked:
          preferences.getBool(
            SmPlayerSettingsStorageKeys.desktopLyricsLocked,
          ) ??
          _snapshot.desktopLyricsLocked,
      desktopLyricsColor:
          preferences.getString(
            SmPlayerSettingsStorageKeys.desktopLyricsColor,
          ) ??
          _snapshot.desktopLyricsColor,
      desktopLyricsStrokeColor:
          preferences.getString(
            SmPlayerSettingsStorageKeys.desktopLyricsStrokeColor,
          ) ??
          _snapshot.desktopLyricsStrokeColor,
      desktopLyricsFontSize:
          preferences.getInt(
            SmPlayerSettingsStorageKeys.desktopLyricsFontSize,
          ) ??
          _snapshot.desktopLyricsFontSize,
      desktopLyricsFontFamily:
          preferences.getString(
            SmPlayerSettingsStorageKeys.desktopLyricsFontFamily,
          ) ??
          _snapshot.desktopLyricsFontFamily,
      desktopLyricsOpacity:
          preferences.getInt(
            SmPlayerSettingsStorageKeys.desktopLyricsOpacity,
          ) ??
          _snapshot.desktopLyricsOpacity,
      desktopLyricsBounds:
          preferences.getString(
            SmPlayerSettingsStorageKeys.desktopLyricsBounds,
          ) ??
          _snapshot.desktopLyricsBounds,
      mainWindowBounds:
          preferences.getString(SmPlayerSettingsStorageKeys.mainWindowBounds) ??
          _snapshot.mainWindowBounds,
      mainWindowMaximized:
          preferences.getBool(
            SmPlayerSettingsStorageKeys.mainWindowMaximized,
          ) ??
          _snapshot.mainWindowMaximized,
      preferredLanguage:
          _readPreferredLanguage(preferences) ?? _snapshot.preferredLanguage,
      musicLibrarySort:
          _readMusicLibrarySort(preferences) ?? _snapshot.musicLibrarySort,
      albumsSort: _readAlbumSort(preferences) ?? _snapshot.albumsSort,
      searchArtistsCriterion:
          _readSearchSort(
            preferences,
            SmPlayerSettingsStorageKeys.searchArtistsCriterion,
          ) ??
          _snapshot.searchArtistsCriterion,
      searchAlbumsCriterion:
          _readSearchSort(
            preferences,
            SmPlayerSettingsStorageKeys.searchAlbumsCriterion,
          ) ??
          _snapshot.searchAlbumsCriterion,
      searchSongsCriterion:
          _readSearchSort(
            preferences,
            SmPlayerSettingsStorageKeys.searchSongsCriterion,
          ) ??
          _snapshot.searchSongsCriterion,
      searchPlaylistsCriterion:
          _readSearchSort(
            preferences,
            SmPlayerSettingsStorageKeys.searchPlaylistsCriterion,
          ) ??
          _snapshot.searchPlaylistsCriterion,
      searchFoldersCriterion:
          _readSearchSort(
            preferences,
            SmPlayerSettingsStorageKeys.searchFoldersCriterion,
          ) ??
          _snapshot.searchFoldersCriterion,
      lastMusicIndex:
          preferences.getInt(SmPlayerSettingsStorageKeys.lastMusicIndex) ??
          _snapshot.lastMusicIndex,
      volume:
          preferences.getInt(SmPlayerSettingsStorageKeys.volume) ??
          _snapshot.volume,
      isMuted:
          preferences.getBool(SmPlayerSettingsStorageKeys.isMuted) ??
          _snapshot.isMuted,
      mode: _readPlaybackMode(preferences) ?? _snapshot.mode,
      musicProgress:
          preferences.getDouble(SmPlayerSettingsStorageKeys.musicProgress) ??
          _snapshot.musicProgress,
      autoPlay:
          preferences.getBool(SmPlayerSettingsStorageKeys.autoPlay) ??
          _snapshot.autoPlay,
      shuffleAfterOneRound:
          preferences.getBool(
            SmPlayerSettingsStorageKeys.shuffleAfterOneRound,
          ) ??
          _snapshot.shuffleAfterOneRound,
      saveMusicProgress:
          preferences.getBool(SmPlayerSettingsStorageKeys.saveMusicProgress) ??
          _snapshot.saveMusicProgress,
      hideMultiSelectCommandBarAfterOperation:
          preferences.getBool(
            SmPlayerSettingsStorageKeys.hideMultiSelectCommandBarAfterOperation,
          ) ??
          _snapshot.hideMultiSelectCommandBarAfterOperation,
      localViewMode: _readLocalViewMode(preferences) ?? _snapshot.localViewMode,
      quitOnClose:
          preferences.getBool(SmPlayerSettingsStorageKeys.quitOnClose) ??
          _snapshot.quitOnClose,
      lastPage:
          preferences.getString(SmPlayerSettingsStorageKeys.lastPage) ??
          _snapshot.lastPage,
      lastPlaylistId:
          preferences.getInt(SmPlayerSettingsStorageKeys.lastPlaylistId) ??
          _snapshot.lastPlaylistId,
      lastReleaseNotesVersion:
          preferences.getString(
            SmPlayerSettingsStorageKeys.lastReleaseNotesVersion,
          ) ??
          _snapshot.lastReleaseNotesVersion,
    );
    notifyListeners();
  }

  Future<void> updateSettings(AppSettingsUpdate update) async {
    _snapshot = _snapshot.apply(update);
    notifyListeners();
    await _saveSnapshot(_snapshot);
  }

  Future<void> savePlaybackSettings(PlaybackSettingsUpdate update) async {
    _snapshot = _snapshot.applyPlaybackSettings(update);
    notifyListeners();
    await _saveSnapshot(_snapshot);
  }

  PlaybackRuntimeSettings getPlaybackSettingsImmediate() {
    return _snapshot.playbackRuntimeSettings;
  }

  void savePlaybackSettingsImmediate(PlaybackSettingsUpdate update) {
    _snapshot = _snapshot.applyPlaybackSettings(update);
    notifyListeners();
    unawaited(_saveSnapshot(_snapshot));
  }
}

class SmPlayerSettingsStorageKeys {
  const SmPlayerSettingsStorageKeys._();

  static const rootPath = 'smplayer:settings:rootPath';
  static const useFilenameNotMusicName =
      'smplayer:settings:useFilenameNotMusicName';
  static const smartMultiArtistRecognition =
      'smplayer:settings:smartMultiArtistRecognition';
  static const showCount = 'smplayer:settings:showCount';
  static const themeColor = 'smplayer:settings:themeColor';
  static const nightMode = 'smplayer:settings:nightMode';
  static const nightModeStartTime = 'smplayer:settings:nightModeStartTime';
  static const nightModeEndTime = 'smplayer:settings:nightModeEndTime';
  static const notificationSend = 'smplayer:settings:notificationSend';
  static const notificationDisplay = 'smplayer:settings:notificationDisplay';
  static const showNotifications = 'smplayer:settings:showNotifications';
  static const autoLyrics = 'smplayer:settings:autoLyrics';
  static const showLyricsInNotification =
      'smplayer:settings:showLyricsInNotification';
  static const notificationLyricsSource =
      'smplayer:settings:notificationLyricsSource';
  static const playerLyricsSource = 'smplayer:settings:playerLyricsSource';
  static const saveLyricsImmediately =
      'smplayer:settings:saveLyricsImmediately';
  static const preserveInternetLyricsTimestamps =
      'smplayer:settings:preserveInternetLyricsTimestamps';
  static const desktopLyricsEnabled = 'smplayer:settings:desktopLyricsEnabled';
  static const desktopLyricsLocked = 'smplayer:settings:desktopLyricsLocked';
  static const desktopLyricsColor = 'smplayer:settings:desktopLyricsColor';
  static const desktopLyricsStrokeColor =
      'smplayer:settings:desktopLyricsStrokeColor';
  static const desktopLyricsFontSize =
      'smplayer:settings:desktopLyricsFontSize';
  static const desktopLyricsFontFamily =
      'smplayer:settings:desktopLyricsFontFamily';
  static const desktopLyricsOpacity = 'smplayer:settings:desktopLyricsOpacity';
  static const desktopLyricsBounds = 'smplayer:settings:desktopLyricsBounds';
  static const mainWindowBounds = 'smplayer:settings:mainWindowBounds';
  static const mainWindowMaximized = 'smplayer:settings:mainWindowMaximized';
  static const preferredLanguage = 'smplayer:settings:preferredLanguage';
  static const musicLibrarySort = 'smplayer:settings:musicLibrarySort';
  static const albumsSort = 'smplayer:settings:albumsSort';
  static const searchArtistsCriterion =
      'smplayer:settings:searchArtistsCriterion';
  static const searchAlbumsCriterion =
      'smplayer:settings:searchAlbumsCriterion';
  static const searchSongsCriterion = 'smplayer:settings:searchSongsCriterion';
  static const searchPlaylistsCriterion =
      'smplayer:settings:searchPlaylistsCriterion';
  static const searchFoldersCriterion =
      'smplayer:settings:searchFoldersCriterion';
  static const lastMusicIndex = 'smplayer:settings:lastMusicIndex';
  static const volume = 'smplayer:settings:volume';
  static const isMuted = 'smplayer:settings:isMuted';
  static const mode = 'smplayer:settings:mode';
  static const musicProgress = 'smplayer:settings:musicProgress';
  static const autoPlay = 'smplayer:settings:autoPlay';
  static const shuffleAfterOneRound = 'smplayer:settings:shuffleAfterOneRound';
  static const saveMusicProgress = 'smplayer:settings:saveMusicProgress';
  static const hideMultiSelectCommandBarAfterOperation =
      'smplayer:settings:hideMultiSelectCommandBarAfterOperation';
  static const localViewMode = 'smplayer:settings:localViewMode';
  static const quitOnClose = 'smplayer:settings:quitOnClose';
  static const lastPage = 'smplayer:settings:lastPage';
  static const lastPlaylistId = 'smplayer:settings:lastPlaylistId';
  static const lastReleaseNotesVersion =
      'smplayer:settings:lastReleaseNotesVersion';
}

Future<void> _saveSnapshot(SettingsSnapshot snapshot) async {
  final preferences = await SharedPreferences.getInstance();
  await Future.wait([
    preferences.setString(
      SmPlayerSettingsStorageKeys.rootPath,
      snapshot.rootPath,
    ),
    preferences.setBool(
      SmPlayerSettingsStorageKeys.useFilenameNotMusicName,
      snapshot.useFilenameNotMusicName,
    ),
    preferences.setBool(
      SmPlayerSettingsStorageKeys.smartMultiArtistRecognition,
      snapshot.smartMultiArtistRecognition,
    ),
    preferences.setBool(
      SmPlayerSettingsStorageKeys.showCount,
      snapshot.showCount,
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.themeColor,
      snapshot.themeColor,
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.nightMode,
      _nightModeValue(snapshot.nightMode),
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.nightModeStartTime,
      snapshot.nightModeStartTime,
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.nightModeEndTime,
      snapshot.nightModeEndTime,
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.notificationSend,
      _notificationSendValue(snapshot.notificationSend),
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.notificationDisplay,
      _notificationDisplayValue(snapshot.notificationDisplay),
    ),
    preferences.setBool(
      SmPlayerSettingsStorageKeys.showNotifications,
      snapshot.showNotifications,
    ),
    preferences.setBool(
      SmPlayerSettingsStorageKeys.autoLyrics,
      snapshot.autoLyrics,
    ),
    preferences.setBool(
      SmPlayerSettingsStorageKeys.showLyricsInNotification,
      snapshot.showLyricsInNotification,
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.notificationLyricsSource,
      _lyricsRequestModeValue(snapshot.notificationLyricsSource),
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.playerLyricsSource,
      _lyricsRequestModeValue(snapshot.playerLyricsSource),
    ),
    preferences.setBool(
      SmPlayerSettingsStorageKeys.saveLyricsImmediately,
      snapshot.saveLyricsImmediately,
    ),
    preferences.setBool(
      SmPlayerSettingsStorageKeys.preserveInternetLyricsTimestamps,
      snapshot.preserveInternetLyricsTimestamps,
    ),
    preferences.setBool(
      SmPlayerSettingsStorageKeys.desktopLyricsEnabled,
      snapshot.desktopLyricsEnabled,
    ),
    preferences.setBool(
      SmPlayerSettingsStorageKeys.desktopLyricsLocked,
      snapshot.desktopLyricsLocked,
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.desktopLyricsColor,
      snapshot.desktopLyricsColor,
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.desktopLyricsStrokeColor,
      snapshot.desktopLyricsStrokeColor,
    ),
    preferences.setInt(
      SmPlayerSettingsStorageKeys.desktopLyricsFontSize,
      snapshot.desktopLyricsFontSize,
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.desktopLyricsFontFamily,
      snapshot.desktopLyricsFontFamily,
    ),
    preferences.setInt(
      SmPlayerSettingsStorageKeys.desktopLyricsOpacity,
      snapshot.desktopLyricsOpacity,
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.desktopLyricsBounds,
      snapshot.desktopLyricsBounds,
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.mainWindowBounds,
      snapshot.mainWindowBounds,
    ),
    preferences.setBool(
      SmPlayerSettingsStorageKeys.mainWindowMaximized,
      snapshot.mainWindowMaximized,
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.preferredLanguage,
      _preferredLanguageValue(snapshot.preferredLanguage),
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.musicLibrarySort,
      _musicLibrarySortValue(snapshot.musicLibrarySort),
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.albumsSort,
      _albumSortValue(snapshot.albumsSort),
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.searchArtistsCriterion,
      _searchSortValue(snapshot.searchArtistsCriterion),
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.searchAlbumsCriterion,
      _searchSortValue(snapshot.searchAlbumsCriterion),
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.searchSongsCriterion,
      _searchSortValue(snapshot.searchSongsCriterion),
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.searchPlaylistsCriterion,
      _searchSortValue(snapshot.searchPlaylistsCriterion),
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.searchFoldersCriterion,
      _searchSortValue(snapshot.searchFoldersCriterion),
    ),
    preferences.setInt(
      SmPlayerSettingsStorageKeys.lastMusicIndex,
      snapshot.lastMusicIndex,
    ),
    preferences.setInt(SmPlayerSettingsStorageKeys.volume, snapshot.volume),
    preferences.setBool(SmPlayerSettingsStorageKeys.isMuted, snapshot.isMuted),
    preferences.setString(
      SmPlayerSettingsStorageKeys.mode,
      _playbackModeValue(snapshot.mode),
    ),
    preferences.setDouble(
      SmPlayerSettingsStorageKeys.musicProgress,
      snapshot.musicProgress,
    ),
    preferences.setBool(
      SmPlayerSettingsStorageKeys.autoPlay,
      snapshot.autoPlay,
    ),
    preferences.setBool(
      SmPlayerSettingsStorageKeys.shuffleAfterOneRound,
      snapshot.shuffleAfterOneRound,
    ),
    preferences.setBool(
      SmPlayerSettingsStorageKeys.saveMusicProgress,
      snapshot.saveMusicProgress,
    ),
    preferences.setBool(
      SmPlayerSettingsStorageKeys.hideMultiSelectCommandBarAfterOperation,
      snapshot.hideMultiSelectCommandBarAfterOperation,
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.localViewMode,
      _localViewModeValue(snapshot.localViewMode),
    ),
    preferences.setBool(
      SmPlayerSettingsStorageKeys.quitOnClose,
      snapshot.quitOnClose,
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.lastPage,
      snapshot.lastPage,
    ),
    preferences.setInt(
      SmPlayerSettingsStorageKeys.lastPlaylistId,
      snapshot.lastPlaylistId,
    ),
    preferences.setString(
      SmPlayerSettingsStorageKeys.lastReleaseNotesVersion,
      snapshot.lastReleaseNotesVersion,
    ),
  ]);
}

NightMode? _readNightMode(SharedPreferences preferences) {
  final value = preferences.getString(SmPlayerSettingsStorageKeys.nightMode);
  return switch (value) {
    'auto' => NightMode.auto,
    'on' => NightMode.onMode,
    'never' => NightMode.never,
    null => null,
    _ => NightMode.never,
  };
}

NotificationSendMode? _readNotificationSend(SharedPreferences preferences) {
  final value = preferences.getString(
    SmPlayerSettingsStorageKeys.notificationSend,
  );
  return switch (value) {
    'music-changed' => NotificationSendMode.musicChanged,
    'never' => NotificationSendMode.never,
    null => null,
    _ => NotificationSendMode.never,
  };
}

NotificationDisplayMode? _readNotificationDisplay(
  SharedPreferences preferences,
) {
  final value = preferences.getString(
    SmPlayerSettingsStorageKeys.notificationDisplay,
  );
  return switch (value) {
    'reminder' => NotificationDisplayMode.reminder,
    'normal' => NotificationDisplayMode.normal,
    'quick' => NotificationDisplayMode.quick,
    null => null,
    _ => NotificationDisplayMode.normal,
  };
}

LyricsRequestMode? _readLyricsRequestMode(
  SharedPreferences preferences,
  String key,
) {
  final value = preferences.getString(key);
  return switch (value) {
    'internet' => LyricsRequestMode.internet,
    'local' => LyricsRequestMode.local,
    'embedded' => LyricsRequestMode.embedded,
    'auto' => LyricsRequestMode.auto,
    null => null,
    _ => LyricsRequestMode.auto,
  };
}

PreferredLanguage? _readPreferredLanguage(SharedPreferences preferences) {
  final value = preferences.getString(
    SmPlayerSettingsStorageKeys.preferredLanguage,
  );
  return switch (value) {
    'system' => PreferredLanguage.system,
    'en-US' => PreferredLanguage.enUS,
    'zh-CN' => PreferredLanguage.zhCN,
    'fr' => PreferredLanguage.fr,
    'ru' => PreferredLanguage.ru,
    'ja' => PreferredLanguage.ja,
    'de' => PreferredLanguage.de,
    'pt-BR' => PreferredLanguage.ptBR,
    'es' => PreferredLanguage.es,
    'it' => PreferredLanguage.it,
    'zh-Hant' => PreferredLanguage.zhHant,
    'nl' => PreferredLanguage.nl,
    'cs' => PreferredLanguage.cs,
    'uk' => PreferredLanguage.uk,
    'sv' => PreferredLanguage.sv,
    'id' => PreferredLanguage.id,
    null => null,
    _ => PreferredLanguage.system,
  };
}

MusicLibrarySortCriterion? _readMusicLibrarySort(
  SharedPreferences preferences,
) {
  final value = preferences.getString(
    SmPlayerSettingsStorageKeys.musicLibrarySort,
  );
  return switch (value) {
    'title' => MusicLibrarySortCriterion.title,
    'artist' => MusicLibrarySortCriterion.artist,
    'album' => MusicLibrarySortCriterion.album,
    'duration' => MusicLibrarySortCriterion.duration,
    'play-count' => MusicLibrarySortCriterion.playCount,
    'date-added' => MusicLibrarySortCriterion.dateAdded,
    null => null,
    _ => MusicLibrarySortCriterion.title,
  };
}

AlbumSortCriterion? _readAlbumSort(SharedPreferences preferences) {
  final value = preferences.getString(SmPlayerSettingsStorageKeys.albumsSort);
  return switch (value) {
    'default' => AlbumSortCriterion.defaultCriterion,
    'name' => AlbumSortCriterion.name,
    'artist' => AlbumSortCriterion.artist,
    'reverse' => AlbumSortCriterion.reverse,
    null => null,
    _ => AlbumSortCriterion.defaultCriterion,
  };
}

SearchSortCriterion? _readSearchSort(
  SharedPreferences preferences,
  String key,
) {
  final value = preferences.getString(key);
  return switch (value) {
    'default' => SearchSortCriterion.defaultCriterion,
    'name' => SearchSortCriterion.name,
    'title' => SearchSortCriterion.title,
    'artist' => SearchSortCriterion.artist,
    'album' => SearchSortCriterion.album,
    'play-count' => SearchSortCriterion.playCount,
    'duration' => SearchSortCriterion.duration,
    'date-added' => SearchSortCriterion.dateAdded,
    null => null,
    _ => SearchSortCriterion.defaultCriterion,
  };
}

PlaybackMode? _readPlaybackMode(SharedPreferences preferences) {
  final value = preferences.getString(SmPlayerSettingsStorageKeys.mode);
  return switch (value) {
    'once' => PlaybackMode.once,
    'repeat' => PlaybackMode.repeat,
    'repeat-one' => PlaybackMode.repeatOne,
    'shuffle' => PlaybackMode.shuffle,
    null => null,
    _ => PlaybackMode.once,
  };
}

LocalViewMode? _readLocalViewMode(SharedPreferences preferences) {
  final value = preferences.getString(
    SmPlayerSettingsStorageKeys.localViewMode,
  );
  return switch (value) {
    'grid' => LocalViewMode.grid,
    'list' => LocalViewMode.list,
    null => null,
    _ => LocalViewMode.grid,
  };
}

String _nightModeValue(NightMode mode) {
  return switch (mode) {
    NightMode.auto => 'auto',
    NightMode.onMode => 'on',
    NightMode.never => 'never',
  };
}

String _notificationSendValue(NotificationSendMode mode) {
  return switch (mode) {
    NotificationSendMode.musicChanged => 'music-changed',
    NotificationSendMode.never => 'never',
  };
}

String _notificationDisplayValue(NotificationDisplayMode mode) {
  return switch (mode) {
    NotificationDisplayMode.reminder => 'reminder',
    NotificationDisplayMode.normal => 'normal',
    NotificationDisplayMode.quick => 'quick',
  };
}

String _lyricsRequestModeValue(LyricsRequestMode mode) {
  return switch (mode) {
    LyricsRequestMode.internet => 'internet',
    LyricsRequestMode.local => 'local',
    LyricsRequestMode.embedded => 'embedded',
    LyricsRequestMode.auto => 'auto',
  };
}

String _preferredLanguageValue(PreferredLanguage language) {
  return switch (language) {
    PreferredLanguage.system => 'system',
    PreferredLanguage.enUS => 'en-US',
    PreferredLanguage.zhCN => 'zh-CN',
    PreferredLanguage.fr => 'fr',
    PreferredLanguage.ru => 'ru',
    PreferredLanguage.ja => 'ja',
    PreferredLanguage.de => 'de',
    PreferredLanguage.ptBR => 'pt-BR',
    PreferredLanguage.es => 'es',
    PreferredLanguage.it => 'it',
    PreferredLanguage.zhHant => 'zh-Hant',
    PreferredLanguage.nl => 'nl',
    PreferredLanguage.cs => 'cs',
    PreferredLanguage.uk => 'uk',
    PreferredLanguage.sv => 'sv',
    PreferredLanguage.id => 'id',
  };
}

String _musicLibrarySortValue(MusicLibrarySortCriterion criterion) {
  return switch (criterion) {
    MusicLibrarySortCriterion.title => 'title',
    MusicLibrarySortCriterion.artist => 'artist',
    MusicLibrarySortCriterion.album => 'album',
    MusicLibrarySortCriterion.duration => 'duration',
    MusicLibrarySortCriterion.playCount => 'play-count',
    MusicLibrarySortCriterion.dateAdded => 'date-added',
  };
}

String _albumSortValue(AlbumSortCriterion criterion) {
  return switch (criterion) {
    AlbumSortCriterion.defaultCriterion => 'default',
    AlbumSortCriterion.name => 'name',
    AlbumSortCriterion.artist => 'artist',
    AlbumSortCriterion.reverse => 'reverse',
  };
}

String _searchSortValue(SearchSortCriterion criterion) {
  return switch (criterion) {
    SearchSortCriterion.defaultCriterion => 'default',
    SearchSortCriterion.name => 'name',
    SearchSortCriterion.title => 'title',
    SearchSortCriterion.artist => 'artist',
    SearchSortCriterion.album => 'album',
    SearchSortCriterion.playCount => 'play-count',
    SearchSortCriterion.duration => 'duration',
    SearchSortCriterion.dateAdded => 'date-added',
  };
}

String _playbackModeValue(PlaybackMode mode) {
  return switch (mode) {
    PlaybackMode.once => 'once',
    PlaybackMode.repeat => 'repeat',
    PlaybackMode.repeatOne => 'repeat-one',
    PlaybackMode.shuffle => 'shuffle',
  };
}

String _localViewModeValue(LocalViewMode mode) {
  return switch (mode) {
    LocalViewMode.grid => 'grid',
    LocalViewMode.list => 'list',
  };
}
