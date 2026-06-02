part of 'desktop_feature_service.dart';

enum DesktopFeatureCommand {
  toggleWindowVisibility,
  showWindow,
  play,
  pause,
  playPause,
  previous,
  next,
  stop,
  quickPlay,
  toggleDesktopLyrics,
  disableDesktopLyrics,
  toggleDesktopLyricsLock,
  desktopLyricsOffsetBackward,
  desktopLyricsOffsetForward,
  resetDesktopLyricsOffset,
  openSettings,
  quit,
  playRecentSong,
  openExternalAudioFiles,
  windowVisibilityChanged,
  windowFullScreenChanged,
  windowMaximizedChanged,
  desktopLyricsBoundsChanged,
  mediaSessionSeekTo,
  voiceCommand,
}

class DesktopFeatureAction {
  const DesktopFeatureAction(
    this.command, {
    this.songId,
    this.filePaths = const [],
    this.isWindowVisible,
    this.isWindowFullScreen,
    this.isWindowMaximized,
    this.desktopLyricsBounds,
    this.seekSeconds,
    this.voiceCommandText,
  });

  final DesktopFeatureCommand command;
  final int? songId;
  final List<String> filePaths;
  final bool? isWindowVisible;
  final bool? isWindowFullScreen;
  final bool? isWindowMaximized;
  final String? desktopLyricsBounds;
  final double? seekSeconds;
  final String? voiceCommandText;
}

class DesktopRecentSong {
  const DesktopRecentSong({
    required this.id,
    required this.title,
    required this.path,
  });

  factory DesktopRecentSong.fromLibrarySong(LibrarySong song) {
    return DesktopRecentSong(id: song.id, title: song.title, path: song.path);
  }

  final int id;
  final String title;
  final String path;
}

class DesktopTrayState {
  const DesktopTrayState({
    required this.appTitle,
    required this.isPlaying,
    required this.isWindowVisible,
    required this.quitOnClose,
    required this.recentSongs,
    required this.labels,
  });

  final String appTitle;
  final bool isPlaying;
  final bool isWindowVisible;
  final bool quitOnClose;
  final List<DesktopRecentSong> recentSongs;
  final DesktopTrayLabels labels;

  String get signature {
    final recentSignature = recentSongs
        .take(desktopRecentSongLimit)
        .map((song) => '${song.id}:${song.title}:${song.path}')
        .join('|');
    return [
      appTitle,
      isPlaying,
      isWindowVisible,
      quitOnClose,
      labels.signature,
      recentSignature,
    ].join('\n');
  }
}

class DesktopTrayLabels {
  const DesktopTrayLabels({
    required this.showWindow,
    required this.hideWindow,
    required this.play,
    required this.pause,
    required this.previous,
    required this.next,
    required this.quickPlay,
    required this.desktopLyrics,
    required this.recent,
    required this.settings,
    required this.quit,
    required this.trayRunningTitle,
    required this.trayRunningBody,
  });

  factory DesktopTrayLabels.fromI18n(SmPlayerI18n i18n) {
    return DesktopTrayLabels(
      showWindow: i18n.t('tray.showWindow'),
      hideWindow: i18n.t('tray.hideWindow'),
      play: i18n.t('player.play'),
      pause: i18n.t('player.pause'),
      previous: i18n.t('player.previous'),
      next: i18n.t('player.next'),
      quickPlay: i18n.t('nowPlaying.quickPlay'),
      desktopLyrics: i18n.t('player.desktopLyrics'),
      recent: i18n.t('common.recent'),
      settings: i18n.t('common.settings'),
      quit: i18n.t('tray.quit'),
      trayRunningTitle: i18n.t('app.trayRunningTitle'),
      trayRunningBody: i18n.t('app.trayRunningBody'),
    );
  }

  final String showWindow;
  final String hideWindow;
  final String play;
  final String pause;
  final String previous;
  final String next;
  final String quickPlay;
  final String desktopLyrics;
  final String recent;
  final String settings;
  final String quit;
  final String trayRunningTitle;
  final String trayRunningBody;

  String get signature {
    return [
      showWindow,
      hideWindow,
      play,
      pause,
      previous,
      next,
      quickPlay,
      desktopLyrics,
      recent,
      settings,
      quit,
      trayRunningTitle,
      trayRunningBody,
    ].join('\n');
  }
}

class DesktopTrayMenuEntry {
  const DesktopTrayMenuEntry({
    required this.label,
    required this.action,
    this.songId,
    this.children = const [],
  }) : separator = false;

  const DesktopTrayMenuEntry.separator()
    : label = '',
      action = null,
      songId = null,
      children = const [],
      separator = true;

  final String label;
  final DesktopFeatureCommand? action;
  final int? songId;
  final List<DesktopTrayMenuEntry> children;
  final bool separator;
}

List<DesktopTrayMenuEntry> buildDesktopTrayMenuEntries(DesktopTrayState state) {
  final labels = state.labels;
  return [
    DesktopTrayMenuEntry(
      label: state.isWindowVisible ? labels.hideWindow : labels.showWindow,
      action: DesktopFeatureCommand.toggleWindowVisibility,
    ),
    const DesktopTrayMenuEntry.separator(),
    DesktopTrayMenuEntry(
      label: state.isPlaying ? labels.pause : labels.play,
      action: DesktopFeatureCommand.playPause,
    ),
    DesktopTrayMenuEntry(
      label: labels.previous,
      action: DesktopFeatureCommand.previous,
    ),
    DesktopTrayMenuEntry(
      label: labels.next,
      action: DesktopFeatureCommand.next,
    ),
    DesktopTrayMenuEntry(
      label: labels.quickPlay,
      action: DesktopFeatureCommand.quickPlay,
    ),
    DesktopTrayMenuEntry(
      label: labels.desktopLyrics,
      action: DesktopFeatureCommand.toggleDesktopLyrics,
    ),
    const DesktopTrayMenuEntry.separator(),
    DesktopTrayMenuEntry(
      label: labels.settings,
      action: DesktopFeatureCommand.openSettings,
    ),
    const DesktopTrayMenuEntry.separator(),
    DesktopTrayMenuEntry(
      label: labels.quit,
      action: DesktopFeatureCommand.quit,
    ),
  ];
}

class TrackNotificationPayload {
  const TrackNotificationPayload({
    required this.songId,
    required this.title,
    required this.artist,
    required this.album,
    this.lyricsPreview = '',
    this.silent = false,
  });

  final int songId;
  final String title;
  final String artist;
  final String album;
  final String lyricsPreview;
  final bool silent;
}

class MediaSessionDisplayState {
  const MediaSessionDisplayState({
    required this.active,
    required this.title,
    required this.artist,
    required this.album,
    required this.artworkPath,
    required this.playing,
    required this.durationSeconds,
    required this.progressSeconds,
  });

  factory MediaSessionDisplayState.fromShell({
    required LibrarySong? currentSong,
    required SmPlayerI18n i18n,
    required bool isPlaying,
    required double durationSeconds,
    required double progressSeconds,
  }) {
    if (currentSong == null) {
      return const MediaSessionDisplayState(
        active: false,
        title: '',
        artist: '',
        album: '',
        artworkPath: '',
        playing: false,
        durationSeconds: 0,
        progressSeconds: 0,
      );
    }
    return MediaSessionDisplayState(
      active: true,
      title: currentSong.title,
      artist: desktopNotificationArtist(currentSong, i18n),
      album: desktopNotificationAlbum(currentSong, i18n),
      artworkPath: currentSong.thumbnailPath,
      playing: isPlaying,
      durationSeconds: durationSeconds,
      progressSeconds: progressSeconds.clamp(0, max(0, durationSeconds)),
    );
  }

  final bool active;
  final String title;
  final String artist;
  final String album;
  final String artworkPath;
  final bool playing;
  final double durationSeconds;
  final double progressSeconds;

  String get signature {
    return [
      active,
      title,
      artist,
      album,
      artworkPath,
      playing,
      durationSeconds.round(),
      progressSeconds.round(),
    ].join('\n');
  }

  Map<String, Object?> toPlatformMap() {
    return {
      'active': active,
      'title': title,
      'artist': artist,
      'album': album,
      'artworkPath': artworkPath,
      'playing': playing,
      'durationSeconds': durationSeconds,
      'progressSeconds': progressSeconds,
    };
  }
}

class DesktopLyricsDisplayState {
  const DesktopLyricsDisplayState({
    required this.visible,
    required this.loading,
    required this.playing,
    required this.locked,
    required this.nightMode,
    required this.opacity,
    required this.fontSize,
    required this.fontFamily,
    required this.textColor,
    required this.strokeColor,
    required this.lyricText,
    required this.fallbackText,
    required this.songTitle,
    required this.artist,
    required this.progressSeconds,
    required this.offsetMs,
    required this.bounds,
    this.labels = DesktopLyricsLabels.defaults,
  });

  factory DesktopLyricsDisplayState.fromShell({
    required SettingsSnapshot settings,
    required LibrarySong? currentSong,
    LyricsSnapshot? lyrics,
    required bool lyricsLoading,
    required bool isPlaying,
    required double progressSeconds,
    required double durationSeconds,
    SmPlayerI18n? i18n,
  }) {
    final artists =
        currentSong == null
            ? const <String>[]
            : artists_model.getSongArtists(currentSong);
    final artist = artists.join(i18n?.t('common.artistSeparator') ?? ', ');
    final fallbackText =
        currentSong == null
            ? ''
            : artist.isEmpty
            ? currentSong.title
            : '${currentSong.title} - $artist';
    final offsetMs = currentSong?.lyricsOffsetMs ?? 0;
    final adjustedProgressSeconds = max(0.0, progressSeconds + offsetMs / 1000);
    final effectiveDurationSeconds =
        durationSeconds > 0
            ? durationSeconds
            : (currentSong?.duration.toDouble() ?? 0);
    final progressRatio =
        effectiveDurationSeconds > 0
            ? adjustedProgressSeconds / effectiveDurationSeconds
            : 0.0;
    return DesktopLyricsDisplayState(
      visible: settings.desktopLyricsEnabled && currentSong != null,
      loading: lyricsLoading,
      playing: isPlaying,
      locked: settings.desktopLyricsLocked,
      nightMode: isAppNightMode(settings),
      opacity: settings.desktopLyricsOpacity,
      fontSize: settings.desktopLyricsFontSize,
      fontFamily: settings.desktopLyricsFontFamily,
      textColor: settings.desktopLyricsColor,
      strokeColor: settings.desktopLyricsStrokeColor,
      lyricText: desktopLyricsText(
        lyrics: lyrics,
        progressSeconds: adjustedProgressSeconds,
        progressRatio: progressRatio,
      ),
      fallbackText: fallbackText,
      songTitle: currentSong?.title ?? '',
      artist: artist,
      progressSeconds: adjustedProgressSeconds,
      offsetMs: offsetMs,
      bounds: settings.desktopLyricsBounds,
      labels:
          i18n == null
              ? DesktopLyricsLabels.defaultsForPlayingState(isPlaying)
              : DesktopLyricsLabels.fromI18n(i18n, isPlaying),
    );
  }

  final bool visible;
  final bool loading;
  final bool playing;
  final bool locked;
  final bool nightMode;
  final int opacity;
  final int fontSize;
  final String fontFamily;
  final String textColor;
  final String strokeColor;
  final String lyricText;
  final String fallbackText;
  final String songTitle;
  final String artist;
  final double progressSeconds;
  final int offsetMs;
  final String bounds;
  final DesktopLyricsLabels labels;

  String get signature {
    return [
      visible,
      loading,
      playing,
      locked,
      nightMode,
      opacity,
      fontSize,
      fontFamily,
      textColor,
      strokeColor,
      lyricText,
      fallbackText,
      songTitle,
      artist,
      progressSeconds,
      offsetMs,
      bounds,
      labels.signature,
    ].join('\n');
  }

  Map<String, Object?> toPlatformMap() {
    return {
      'visible': visible,
      'loading': loading,
      'playing': playing,
      'locked': locked,
      'nightMode': nightMode,
      'opacity': opacity,
      'fontSize': fontSize,
      'fontFamily': fontFamily,
      'textColor': textColor,
      'strokeColor': strokeColor,
      'lyricText': lyricText,
      'fallbackText': fallbackText,
      'songTitle': songTitle,
      'artist': artist,
      'progressSeconds': progressSeconds,
      'offsetMs': offsetMs,
      'bounds': bounds,
      'labelPrevious': labels.previous,
      'labelNext': labels.next,
      'labelPlayPause': labels.playPause,
      'labelResetOffset': labels.resetOffset,
      'labelLock': labels.lock,
      'labelUnlock': labels.unlock,
      'labelSettings': labels.settings,
      'labelClose': labels.close,
    };
  }
}

class DesktopLyricsLabels {
  const DesktopLyricsLabels({
    required this.previous,
    required this.next,
    required this.playPause,
    required this.resetOffset,
    required this.lock,
    required this.unlock,
    required this.settings,
    required this.close,
  });

  factory DesktopLyricsLabels.fromI18n(SmPlayerI18n i18n, bool isPlaying) {
    return DesktopLyricsLabels(
      previous: i18n.t('player.previous'),
      next: i18n.t('player.next'),
      playPause: isPlaying ? i18n.t('player.pause') : i18n.t('player.play'),
      resetOffset: i18n.t('settings.desktopLyricsResetOffset'),
      lock: i18n.t('settings.desktopLyricsLockAction'),
      unlock: i18n.t('settings.desktopLyricsUnlockAction'),
      settings: i18n.t('common.settings'),
      close: i18n.t('common.close'),
    );
  }

  static const defaults = DesktopLyricsLabels(
    previous: 'Previous',
    next: 'Next',
    playPause: 'Play/Pause',
    resetOffset: 'Reset',
    lock: 'Lock',
    unlock: 'Unlock',
    settings: 'Settings',
    close: 'Close',
  );

  static DesktopLyricsLabels defaultsForPlayingState(bool isPlaying) {
    return DesktopLyricsLabels(
      previous: defaults.previous,
      next: defaults.next,
      playPause: isPlaying ? 'Pause' : 'Play',
      resetOffset: defaults.resetOffset,
      lock: defaults.lock,
      unlock: defaults.unlock,
      settings: defaults.settings,
      close: defaults.close,
    );
  }

  final String previous;
  final String next;
  final String playPause;
  final String resetOffset;
  final String lock;
  final String unlock;
  final String settings;
  final String close;

  String get signature {
    return [
      previous,
      next,
      playPause,
      resetOffset,
      lock,
      unlock,
      settings,
      close,
    ].join('\n');
  }
}

String desktopLyricsText({
  required LyricsSnapshot? lyrics,
  required double progressSeconds,
  required double progressRatio,
}) {
  final snapshot = lyrics;
  if (snapshot == null || snapshot.lines.isEmpty) {
    return '';
  }

  final timedLines =
      snapshot.lines.where((line) => line.timestampMs != null).toList();
  if (timedLines.isNotEmpty) {
    final progressMs = max(0, (progressSeconds * 1000).floor());
    var currentText = '';
    for (final line in timedLines) {
      if (line.timestampMs! > progressMs) {
        break;
      }
      currentText = line.text;
    }
    return _singleDisplayLyricLine(currentText);
  }

  final lyricIndex = min(
    snapshot.lines.length - 1,
    (snapshot.lines.length * progressRatio.clamp(0, 1)).floor(),
  );
  return _singleDisplayLyricLine(snapshot.lines[lyricIndex].text);
}

String _singleDisplayLyricLine(String text) {
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

int currentDesktopLyricIndex(
  LyricsSnapshot lyrics,
  double progressSeconds,
  int offsetMs,
) {
  final targetMs = (progressSeconds * 1000).round() + offsetMs;
  var currentIndex = 0;
  for (var index = 0; index < lyrics.lines.length; index += 1) {
    final timestamp = lyrics.lines[index].timestampMs;
    if (timestamp == null || timestamp > targetMs) {
      break;
    }
    currentIndex = index;
  }
  return currentIndex;
}
