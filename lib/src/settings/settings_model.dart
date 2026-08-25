import 'package:smplayer_flutter/src/playback/media_control_model.dart';

export 'package:smplayer_flutter/src/playback/media_control_model.dart'
    show PlaybackMode, PlaybackRuntimeSettings, PlaybackSettingsUpdate;

enum NightMode { system, auto, onMode, never }

enum NotificationSendMode { musicChanged, never }

enum NotificationDisplayMode { reminder, normal, quick }

enum SmPlayerDisplayMode { normal, mini, fullScreen, immersive }

enum LyricsRequestMode { internet, local, embedded, auto }

enum LocalViewMode { grid, list }

enum MusicLibrarySortCriterion {
  title,
  artist,
  album,
  duration,
  playCount,
  dateAdded,
}

enum AlbumSortCriterion { defaultCriterion, name, artist, reverse }

enum SearchSortCriterion {
  defaultCriterion,
  name,
  title,
  artist,
  album,
  playCount,
  duration,
  dateAdded,
}

enum PreferredLanguage {
  system,
  enUS,
  zhCN,
  fr,
  ru,
  ja,
  de,
  ptBR,
  es,
  it,
  zhHant,
  nl,
  cs,
  uk,
  sv,
  id,
}

enum PreferenceLevel { veryHigh, higher, high, normal, dislike, doNotAppear }

enum PreferenceEntityType {
  song,
  artist,
  album,
  playlist,
  folder,
  recentAdded,
  myFavorites,
  mostPlayed,
  leastPlayed,
}

enum PreferenceSectionKey { songs, artists, albums, playlists, folders }

class SettingsSnapshot {
  const SettingsSnapshot({
    required this.rootPath,
    required this.useFilenameNotMusicName,
    required this.smartMultiArtistRecognition,
    required this.showCount,
    required this.themeColor,
    required this.nightMode,
    required this.nightModeStartTime,
    required this.nightModeEndTime,
    required this.notificationSend,
    required this.notificationDisplay,
    required this.showNotifications,
    required this.autoLyrics,
    required this.showLyricsInNotification,
    required this.notificationLyricsSource,
    required this.playerLyricsSource,
    required this.saveLyricsImmediately,
    required this.preserveInternetLyricsTimestamps,
    required this.desktopLyricsEnabled,
    required this.desktopLyricsLocked,
    required this.desktopLyricsColor,
    required this.desktopLyricsStrokeColor,
    required this.desktopLyricsFontSize,
    required this.desktopLyricsFontFamily,
    required this.desktopLyricsOpacity,
    required this.desktopLyricsBounds,
    required this.mainWindowBounds,
    required this.mainWindowMaximized,
    required this.lastDisplayMode,
    required this.preferredLanguage,
    required this.musicLibrarySort,
    required this.albumsSort,
    required this.searchArtistsCriterion,
    required this.searchAlbumsCriterion,
    required this.searchSongsCriterion,
    required this.searchPlaylistsCriterion,
    required this.searchFoldersCriterion,
    required this.lastMusicId,
    required this.lastMusicIndex,
    required this.volume,
    required this.isMuted,
    required this.mode,
    required this.musicProgress,
    required this.autoPlay,
    required this.shuffleAfterOneRound,
    required this.previousButtonRestartsTrack,
    required this.saveMusicProgress,
    required this.hideMultiSelectCommandBarAfterOperation,
    required this.localViewMode,
    required this.quitOnClose,
    required this.aiAgentEnabled,
    required this.lastPage,
    required this.lastPlaylistId,
    required this.lastReleaseNotesVersion,
  });

  const SettingsSnapshot.defaults()
    : rootPath = '',
      useFilenameNotMusicName = false,
      smartMultiArtistRecognition = true,
      showCount = true,
      themeColor = '#0078D7',
      nightMode = NightMode.system,
      nightModeStartTime = '20:00',
      nightModeEndTime = '06:00',
      notificationSend = NotificationSendMode.never,
      notificationDisplay = NotificationDisplayMode.normal,
      showNotifications = false,
      autoLyrics = true,
      showLyricsInNotification = false,
      notificationLyricsSource = LyricsRequestMode.internet,
      playerLyricsSource = LyricsRequestMode.auto,
      saveLyricsImmediately = true,
      preserveInternetLyricsTimestamps = true,
      desktopLyricsEnabled = false,
      desktopLyricsLocked = false,
      desktopLyricsColor = '#4aa8ff',
      desktopLyricsStrokeColor = '#111111',
      desktopLyricsFontSize = 28,
      desktopLyricsFontFamily = 'system',
      desktopLyricsOpacity = 88,
      desktopLyricsBounds = '',
      mainWindowBounds = '',
      mainWindowMaximized = false,
      lastDisplayMode = SmPlayerDisplayMode.normal,
      preferredLanguage = PreferredLanguage.system,
      musicLibrarySort = MusicLibrarySortCriterion.title,
      albumsSort = AlbumSortCriterion.defaultCriterion,
      searchArtistsCriterion = SearchSortCriterion.defaultCriterion,
      searchAlbumsCriterion = SearchSortCriterion.defaultCriterion,
      searchSongsCriterion = SearchSortCriterion.defaultCriterion,
      searchPlaylistsCriterion = SearchSortCriterion.defaultCriterion,
      searchFoldersCriterion = SearchSortCriterion.defaultCriterion,
      lastMusicId = 0,
      lastMusicIndex = -1,
      volume = 50,
      isMuted = false,
      mode = PlaybackMode.once,
      musicProgress = 0,
      autoPlay = false,
      shuffleAfterOneRound = true,
      previousButtonRestartsTrack = true,
      saveMusicProgress = true,
      hideMultiSelectCommandBarAfterOperation = true,
      localViewMode = LocalViewMode.grid,
      quitOnClose = true,
      aiAgentEnabled = false,
      lastPage = '/songs',
      lastPlaylistId = 0,
      lastReleaseNotesVersion = '';

  final String rootPath;
  final bool useFilenameNotMusicName;
  final bool smartMultiArtistRecognition;
  final bool showCount;
  final String themeColor;
  final NightMode nightMode;
  final String nightModeStartTime;
  final String nightModeEndTime;
  final NotificationSendMode notificationSend;
  final NotificationDisplayMode notificationDisplay;
  final bool showNotifications;
  final bool autoLyrics;
  final bool showLyricsInNotification;
  final LyricsRequestMode notificationLyricsSource;
  final LyricsRequestMode playerLyricsSource;
  final bool saveLyricsImmediately;
  final bool preserveInternetLyricsTimestamps;
  final bool desktopLyricsEnabled;
  final bool desktopLyricsLocked;
  final String desktopLyricsColor;
  final String desktopLyricsStrokeColor;
  final int desktopLyricsFontSize;
  final String desktopLyricsFontFamily;
  final int desktopLyricsOpacity;
  final String desktopLyricsBounds;
  final String mainWindowBounds;
  final bool mainWindowMaximized;
  final SmPlayerDisplayMode lastDisplayMode;
  final PreferredLanguage preferredLanguage;
  final MusicLibrarySortCriterion musicLibrarySort;
  final AlbumSortCriterion albumsSort;
  final SearchSortCriterion searchArtistsCriterion;
  final SearchSortCriterion searchAlbumsCriterion;
  final SearchSortCriterion searchSongsCriterion;
  final SearchSortCriterion searchPlaylistsCriterion;
  final SearchSortCriterion searchFoldersCriterion;
  final int lastMusicId;
  final int lastMusicIndex;
  final int volume;
  final bool isMuted;
  final PlaybackMode mode;
  final double musicProgress;
  final bool autoPlay;
  final bool shuffleAfterOneRound;
  final bool previousButtonRestartsTrack;
  final bool saveMusicProgress;
  final bool hideMultiSelectCommandBarAfterOperation;
  final LocalViewMode localViewMode;
  final bool quitOnClose;
  final bool aiAgentEnabled;
  final String lastPage;
  final int lastPlaylistId;
  final String lastReleaseNotesVersion;

  PlaybackRuntimeSettings get playbackRuntimeSettings {
    return PlaybackRuntimeSettings(
      volume: volume,
      isMuted: isMuted,
      mode: mode,
    );
  }

  SettingsSnapshot copyWith({
    String? rootPath,
    bool? useFilenameNotMusicName,
    bool? smartMultiArtistRecognition,
    bool? showCount,
    String? themeColor,
    NightMode? nightMode,
    String? nightModeStartTime,
    String? nightModeEndTime,
    NotificationSendMode? notificationSend,
    NotificationDisplayMode? notificationDisplay,
    bool? showNotifications,
    bool? autoLyrics,
    bool? showLyricsInNotification,
    LyricsRequestMode? notificationLyricsSource,
    LyricsRequestMode? playerLyricsSource,
    bool? saveLyricsImmediately,
    bool? preserveInternetLyricsTimestamps,
    bool? desktopLyricsEnabled,
    bool? desktopLyricsLocked,
    String? desktopLyricsColor,
    String? desktopLyricsStrokeColor,
    int? desktopLyricsFontSize,
    String? desktopLyricsFontFamily,
    int? desktopLyricsOpacity,
    String? desktopLyricsBounds,
    String? mainWindowBounds,
    bool? mainWindowMaximized,
    SmPlayerDisplayMode? lastDisplayMode,
    PreferredLanguage? preferredLanguage,
    MusicLibrarySortCriterion? musicLibrarySort,
    AlbumSortCriterion? albumsSort,
    SearchSortCriterion? searchArtistsCriterion,
    SearchSortCriterion? searchAlbumsCriterion,
    SearchSortCriterion? searchSongsCriterion,
    SearchSortCriterion? searchPlaylistsCriterion,
    SearchSortCriterion? searchFoldersCriterion,
    int? lastMusicId,
    int? lastMusicIndex,
    int? volume,
    bool? isMuted,
    PlaybackMode? mode,
    double? musicProgress,
    bool? autoPlay,
    bool? shuffleAfterOneRound,
    bool? previousButtonRestartsTrack,
    bool? saveMusicProgress,
    bool? hideMultiSelectCommandBarAfterOperation,
    LocalViewMode? localViewMode,
    bool? quitOnClose,
    bool? aiAgentEnabled,
    String? lastPage,
    int? lastPlaylistId,
    String? lastReleaseNotesVersion,
  }) {
    return SettingsSnapshot(
      rootPath: rootPath ?? this.rootPath,
      useFilenameNotMusicName:
          useFilenameNotMusicName ?? this.useFilenameNotMusicName,
      smartMultiArtistRecognition:
          smartMultiArtistRecognition ?? this.smartMultiArtistRecognition,
      showCount: showCount ?? this.showCount,
      themeColor: themeColor ?? this.themeColor,
      nightMode: nightMode ?? this.nightMode,
      nightModeStartTime: nightModeStartTime ?? this.nightModeStartTime,
      nightModeEndTime: nightModeEndTime ?? this.nightModeEndTime,
      notificationSend: notificationSend ?? this.notificationSend,
      notificationDisplay: notificationDisplay ?? this.notificationDisplay,
      showNotifications: showNotifications ?? this.showNotifications,
      autoLyrics: autoLyrics ?? this.autoLyrics,
      showLyricsInNotification:
          showLyricsInNotification ?? this.showLyricsInNotification,
      notificationLyricsSource:
          notificationLyricsSource ?? this.notificationLyricsSource,
      playerLyricsSource: playerLyricsSource ?? this.playerLyricsSource,
      saveLyricsImmediately:
          saveLyricsImmediately ?? this.saveLyricsImmediately,
      preserveInternetLyricsTimestamps:
          preserveInternetLyricsTimestamps ??
          this.preserveInternetLyricsTimestamps,
      desktopLyricsEnabled: desktopLyricsEnabled ?? this.desktopLyricsEnabled,
      desktopLyricsLocked: desktopLyricsLocked ?? this.desktopLyricsLocked,
      desktopLyricsColor: desktopLyricsColor ?? this.desktopLyricsColor,
      desktopLyricsStrokeColor:
          desktopLyricsStrokeColor ?? this.desktopLyricsStrokeColor,
      desktopLyricsFontSize:
          desktopLyricsFontSize ?? this.desktopLyricsFontSize,
      desktopLyricsFontFamily:
          desktopLyricsFontFamily ?? this.desktopLyricsFontFamily,
      desktopLyricsOpacity: desktopLyricsOpacity ?? this.desktopLyricsOpacity,
      desktopLyricsBounds: desktopLyricsBounds ?? this.desktopLyricsBounds,
      mainWindowBounds: mainWindowBounds ?? this.mainWindowBounds,
      mainWindowMaximized: mainWindowMaximized ?? this.mainWindowMaximized,
      lastDisplayMode: lastDisplayMode ?? this.lastDisplayMode,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      musicLibrarySort: musicLibrarySort ?? this.musicLibrarySort,
      albumsSort: albumsSort ?? this.albumsSort,
      searchArtistsCriterion:
          searchArtistsCriterion ?? this.searchArtistsCriterion,
      searchAlbumsCriterion:
          searchAlbumsCriterion ?? this.searchAlbumsCriterion,
      searchSongsCriterion: searchSongsCriterion ?? this.searchSongsCriterion,
      searchPlaylistsCriterion:
          searchPlaylistsCriterion ?? this.searchPlaylistsCriterion,
      searchFoldersCriterion:
          searchFoldersCriterion ?? this.searchFoldersCriterion,
      lastMusicId: lastMusicId ?? this.lastMusicId,
      lastMusicIndex: lastMusicIndex ?? this.lastMusicIndex,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      mode: mode ?? this.mode,
      musicProgress: musicProgress ?? this.musicProgress,
      autoPlay: autoPlay ?? this.autoPlay,
      shuffleAfterOneRound: shuffleAfterOneRound ?? this.shuffleAfterOneRound,
      previousButtonRestartsTrack:
          previousButtonRestartsTrack ?? this.previousButtonRestartsTrack,
      saveMusicProgress: saveMusicProgress ?? this.saveMusicProgress,
      hideMultiSelectCommandBarAfterOperation:
          hideMultiSelectCommandBarAfterOperation ??
          this.hideMultiSelectCommandBarAfterOperation,
      localViewMode: localViewMode ?? this.localViewMode,
      quitOnClose: quitOnClose ?? this.quitOnClose,
      aiAgentEnabled: aiAgentEnabled ?? this.aiAgentEnabled,
      lastPage: lastPage ?? this.lastPage,
      lastPlaylistId: lastPlaylistId ?? this.lastPlaylistId,
      lastReleaseNotesVersion:
          lastReleaseNotesVersion ?? this.lastReleaseNotesVersion,
    );
  }
}

class AppSettingsUpdate {
  const AppSettingsUpdate({
    this.rootPath,
    this.useFilenameNotMusicName,
    this.smartMultiArtistRecognition,
    this.showCount,
    this.themeColor,
    this.nightMode,
    this.nightModeStartTime,
    this.nightModeEndTime,
    this.notificationSend,
    this.notificationDisplay,
    this.showNotifications,
    this.autoLyrics,
    this.showLyricsInNotification,
    this.notificationLyricsSource,
    this.playerLyricsSource,
    this.saveLyricsImmediately,
    this.preserveInternetLyricsTimestamps,
    this.desktopLyricsEnabled,
    this.desktopLyricsLocked,
    this.desktopLyricsColor,
    this.desktopLyricsStrokeColor,
    this.desktopLyricsFontSize,
    this.desktopLyricsFontFamily,
    this.desktopLyricsOpacity,
    this.desktopLyricsBounds,
    this.preferredLanguage,
    this.musicLibrarySort,
    this.albumsSort,
    this.searchArtistsCriterion,
    this.searchAlbumsCriterion,
    this.searchSongsCriterion,
    this.searchPlaylistsCriterion,
    this.searchFoldersCriterion,
    this.autoPlay,
    this.shuffleAfterOneRound,
    this.previousButtonRestartsTrack,
    this.saveMusicProgress,
    this.hideMultiSelectCommandBarAfterOperation,
    this.localViewMode,
    this.quitOnClose,
    this.aiAgentEnabled,
    this.lastReleaseNotesVersion,
  });

  final String? rootPath;
  final bool? useFilenameNotMusicName;
  final bool? smartMultiArtistRecognition;
  final bool? showCount;
  final String? themeColor;
  final NightMode? nightMode;
  final String? nightModeStartTime;
  final String? nightModeEndTime;
  final NotificationSendMode? notificationSend;
  final NotificationDisplayMode? notificationDisplay;
  final bool? showNotifications;
  final bool? autoLyrics;
  final bool? showLyricsInNotification;
  final LyricsRequestMode? notificationLyricsSource;
  final LyricsRequestMode? playerLyricsSource;
  final bool? saveLyricsImmediately;
  final bool? preserveInternetLyricsTimestamps;
  final bool? desktopLyricsEnabled;
  final bool? desktopLyricsLocked;
  final String? desktopLyricsColor;
  final String? desktopLyricsStrokeColor;
  final int? desktopLyricsFontSize;
  final String? desktopLyricsFontFamily;
  final int? desktopLyricsOpacity;
  final String? desktopLyricsBounds;
  final PreferredLanguage? preferredLanguage;
  final MusicLibrarySortCriterion? musicLibrarySort;
  final AlbumSortCriterion? albumsSort;
  final SearchSortCriterion? searchArtistsCriterion;
  final SearchSortCriterion? searchAlbumsCriterion;
  final SearchSortCriterion? searchSongsCriterion;
  final SearchSortCriterion? searchPlaylistsCriterion;
  final SearchSortCriterion? searchFoldersCriterion;
  final bool? autoPlay;
  final bool? shuffleAfterOneRound;
  final bool? previousButtonRestartsTrack;
  final bool? saveMusicProgress;
  final bool? hideMultiSelectCommandBarAfterOperation;
  final LocalViewMode? localViewMode;
  final bool? quitOnClose;
  final bool? aiAgentEnabled;
  final String? lastReleaseNotesVersion;
}

extension AppSettingsUpdateApply on SettingsSnapshot {
  SettingsSnapshot apply(AppSettingsUpdate update) {
    final nextSaveMusicProgress = update.saveMusicProgress ?? saveMusicProgress;
    return copyWith(
      rootPath: update.rootPath,
      useFilenameNotMusicName: update.useFilenameNotMusicName,
      smartMultiArtistRecognition: update.smartMultiArtistRecognition,
      showCount: update.showCount,
      themeColor: update.themeColor,
      nightMode: update.nightMode,
      nightModeStartTime: update.nightModeStartTime,
      nightModeEndTime: update.nightModeEndTime,
      notificationSend: update.notificationSend,
      notificationDisplay: update.notificationDisplay,
      showNotifications: update.showNotifications,
      autoLyrics: update.autoLyrics,
      showLyricsInNotification: update.showLyricsInNotification,
      notificationLyricsSource: update.notificationLyricsSource,
      playerLyricsSource: update.playerLyricsSource,
      saveLyricsImmediately: update.saveLyricsImmediately,
      preserveInternetLyricsTimestamps: update.preserveInternetLyricsTimestamps,
      desktopLyricsEnabled: update.desktopLyricsEnabled,
      desktopLyricsLocked: update.desktopLyricsLocked,
      desktopLyricsColor: update.desktopLyricsColor,
      desktopLyricsStrokeColor: update.desktopLyricsStrokeColor,
      desktopLyricsFontSize: update.desktopLyricsFontSize,
      desktopLyricsFontFamily: update.desktopLyricsFontFamily,
      desktopLyricsOpacity: update.desktopLyricsOpacity,
      desktopLyricsBounds: update.desktopLyricsBounds,
      preferredLanguage: update.preferredLanguage,
      musicLibrarySort: update.musicLibrarySort,
      albumsSort: update.albumsSort,
      searchArtistsCriterion: update.searchArtistsCriterion,
      searchAlbumsCriterion: update.searchAlbumsCriterion,
      searchSongsCriterion: update.searchSongsCriterion,
      searchPlaylistsCriterion: update.searchPlaylistsCriterion,
      searchFoldersCriterion: update.searchFoldersCriterion,
      autoPlay: update.autoPlay,
      shuffleAfterOneRound: update.shuffleAfterOneRound,
      previousButtonRestartsTrack: update.previousButtonRestartsTrack,
      saveMusicProgress: update.saveMusicProgress,
      musicProgress: nextSaveMusicProgress ? musicProgress : 0,
      hideMultiSelectCommandBarAfterOperation:
          update.hideMultiSelectCommandBarAfterOperation,
      localViewMode: update.localViewMode,
      quitOnClose: update.quitOnClose,
      aiAgentEnabled: update.aiAgentEnabled,
      lastReleaseNotesVersion: update.lastReleaseNotesVersion,
    );
  }
}

extension PlaybackSettingsUpdateApply on SettingsSnapshot {
  SettingsSnapshot applyPlaybackSettings(PlaybackSettingsUpdate update) {
    final nextMusicProgress =
        update.musicProgress == null
            ? null
            : saveMusicProgress
            ? update.musicProgress
            : 0.0;
    return copyWith(
      lastMusicId: update.lastMusicId,
      lastMusicIndex: update.lastMusicIndex,
      volume: update.volume,
      isMuted: update.isMuted,
      mode: update.mode,
      musicProgress: nextMusicProgress,
    );
  }
}

class PreferenceItemSnapshot {
  const PreferenceItemSnapshot({
    this.id = 0,
    required this.type,
    this.itemId = '',
    required this.name,
    required this.tooltip,
    required this.isEnabled,
    required this.level,
    required this.isValid,
    required this.canRemove,
  });

  final int id;
  final PreferenceEntityType type;
  final String itemId;
  final String name;
  final String tooltip;
  final bool isEnabled;
  final PreferenceLevel level;
  final bool isValid;
  final bool canRemove;

  PreferenceItemSnapshot copyWith({
    bool? isEnabled,
    PreferenceLevel? level,
    bool? isValid,
  }) {
    return PreferenceItemSnapshot(
      id: id,
      type: type,
      itemId: itemId,
      name: name,
      tooltip: tooltip,
      isEnabled: isEnabled ?? this.isEnabled,
      level: level ?? this.level,
      isValid: isValid ?? this.isValid,
      canRemove: canRemove,
    );
  }
}

class PreferenceSettingsSnapshot {
  const PreferenceSettingsSnapshot({
    required this.enabled,
    required this.songs,
    required this.artists,
    required this.albums,
    required this.playlists,
    required this.folders,
    required this.others,
  });

  factory PreferenceSettingsSnapshot.defaults() {
    return const PreferenceSettingsSnapshot(
      enabled: {
        PreferenceSectionKey.songs: true,
        PreferenceSectionKey.artists: true,
        PreferenceSectionKey.albums: true,
        PreferenceSectionKey.playlists: true,
        PreferenceSectionKey.folders: true,
      },
      songs: [],
      artists: [],
      albums: [],
      playlists: [],
      folders: [],
      others: [
        PreferenceItemSnapshot(
          type: PreferenceEntityType.recentAdded,
          name: '最近添加',
          tooltip: '最近添加',
          isEnabled: true,
          level: PreferenceLevel.high,
          isValid: true,
          canRemove: false,
        ),
        PreferenceItemSnapshot(
          type: PreferenceEntityType.myFavorites,
          name: '我喜欢',
          tooltip: '我喜欢',
          isEnabled: true,
          level: PreferenceLevel.higher,
          isValid: true,
          canRemove: false,
        ),
      ],
    );
  }

  final Map<PreferenceSectionKey, bool> enabled;
  final List<PreferenceItemSnapshot> songs;
  final List<PreferenceItemSnapshot> artists;
  final List<PreferenceItemSnapshot> albums;
  final List<PreferenceItemSnapshot> playlists;
  final List<PreferenceItemSnapshot> folders;
  final List<PreferenceItemSnapshot> others;

  PreferenceSettingsSnapshot copyWith({
    Map<PreferenceSectionKey, bool>? enabled,
    List<PreferenceItemSnapshot>? songs,
    List<PreferenceItemSnapshot>? artists,
    List<PreferenceItemSnapshot>? albums,
    List<PreferenceItemSnapshot>? playlists,
    List<PreferenceItemSnapshot>? folders,
    List<PreferenceItemSnapshot>? others,
  }) {
    return PreferenceSettingsSnapshot(
      enabled: enabled ?? this.enabled,
      songs: songs ?? this.songs,
      artists: artists ?? this.artists,
      albums: albums ?? this.albums,
      playlists: playlists ?? this.playlists,
      folders: folders ?? this.folders,
      others: others ?? this.others,
    );
  }
}

String nightModeLabel(NightMode mode) {
  return switch (mode) {
    NightMode.system => '跟随系统',
    NightMode.auto => '自定义',
    NightMode.onMode => '开启',
    NightMode.never => '永不',
  };
}

String notificationSendLabel(NotificationSendMode mode) {
  return switch (mode) {
    NotificationSendMode.musicChanged => '音乐变更',
    NotificationSendMode.never => '永不发送',
  };
}

String preferredLanguageLabel(PreferredLanguage language) {
  return switch (language) {
    PreferredLanguage.system => '跟随系统',
    PreferredLanguage.enUS => 'English',
    PreferredLanguage.zhCN => '简体中文',
    PreferredLanguage.fr => 'Français',
    PreferredLanguage.ru => 'Русский',
    PreferredLanguage.ja => '日本語',
    PreferredLanguage.de => 'Deutsch',
    PreferredLanguage.ptBR => 'Português (Brasil)',
    PreferredLanguage.es => 'Español',
    PreferredLanguage.it => 'Italiano',
    PreferredLanguage.zhHant => '繁體中文',
    PreferredLanguage.nl => 'Nederlands',
    PreferredLanguage.cs => 'Čeština',
    PreferredLanguage.uk => 'Українська',
    PreferredLanguage.sv => 'Svenska',
    PreferredLanguage.id => 'Bahasa Indonesia',
  };
}

String preferenceLevelLabel(PreferenceLevel level) {
  return switch (level) {
    PreferenceLevel.veryHigh => '非常高',
    PreferenceLevel.higher => '很高',
    PreferenceLevel.high => '高',
    PreferenceLevel.normal => '正常',
    PreferenceLevel.dislike => '不喜欢',
    PreferenceLevel.doNotAppear => '不出现',
  };
}
