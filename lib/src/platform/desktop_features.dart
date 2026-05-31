import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import 'package:screen_retriever/screen_retriever.dart' as screen;
import 'package:smplayer_flutter/src/app/app_appearance_model.dart';
import 'package:smplayer_flutter/src/app/app_window_state_model.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/ui/artists_page_model.dart'
    as artists_model;
import 'package:smplayer_flutter/src/library/ui/song_display_helpers.dart';
import 'package:smplayer_flutter/src/platform/external_open_model.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

const desktopRecentSongLimit = 10;
const windowsAppUserModelId = 'com.seaky.simplemelodyplayer';
const windowsToastActivationUri = 'smplayer://show-window';
const desktopLyricsOffsetMinMs = -10000;
const desktopLyricsOffsetMaxMs = 10000;
const _desktopFeatureChannel = MethodChannel(
  'smplayer_flutter/desktop_features',
);

Future<String?> pickDesktopColor(String value) async {
  if (kIsWeb) {
    return null;
  }
  if (Platform.isMacOS) {
    return _pickMacOsColor(value);
  }
  if (Platform.isWindows) {
    return _pickWindowsColor(value);
  }
  if (Platform.isLinux) {
    return _pickLinuxColor(value);
  }
  return null;
}

Future<String?> pickDirectoryFromDesktopShell({
  String? title,
  String? buttonLabel,
  String? defaultPath,
  String? locale,
}) {
  final arguments = <String, String>{};
  if (title != null) {
    arguments['title'] = title;
  }
  if (buttonLabel != null) {
    arguments['buttonLabel'] = buttonLabel;
  }
  if (defaultPath != null) {
    arguments['defaultPath'] = defaultPath;
  }
  if (locale != null) {
    arguments['locale'] = locale;
  }
  return _desktopFeatureChannel.invokeMethod<String>(
    'pickDirectory',
    arguments,
  );
}

Future<void> dismissNativeSplash() async {
  if (!kIsWeb && (Platform.isMacOS || Platform.isWindows)) {
    await _desktopFeatureChannel.invokeMethod<void>('dismissNativeSplash');
  }
}

Future<String?> _pickMacOsColor(String value) async {
  final rgb = _hexColorToAppleScriptRgb(value);
  if (rgb == null) {
    return null;
  }
  final result = await Process.run('osascript', [
    '-e',
    'choose color default color {${rgb.$1}, ${rgb.$2}, ${rgb.$3}}',
  ]);
  if (result.exitCode != 0) {
    return null;
  }
  final components = '${result.stdout}'
      .trim()
      .split(',')
      .map((part) => int.tryParse(part.trim()))
      .toList(growable: false);
  if (components.length < 3 ||
      components[0] == null ||
      components[1] == null ||
      components[2] == null) {
    return null;
  }
  return _appleScriptRgbToHex(components[0]!, components[1]!, components[2]!);
}

Future<String?> _pickWindowsColor(String value) async {
  final rgb = _hexColorToRgb(value);
  if (rgb == null) {
    return null;
  }
  try {
    final result = await Process.run('powershell.exe', [
      '-Sta',
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      '''
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
\$dialog = New-Object System.Windows.Forms.ColorDialog
\$dialog.FullOpen = \$true
\$dialog.Color = [System.Drawing.Color]::FromArgb(${rgb.$1}, ${rgb.$2}, ${rgb.$3})
if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  '#{0:X2}{1:X2}{2:X2}' -f \$dialog.Color.R, \$dialog.Color.G, \$dialog.Color.B
  exit 0
}
exit 1
''',
    ]);
    if (result.exitCode != 0) {
      return null;
    }
    return _desktopColorSelectionToHex('${result.stdout}');
  } on Object {
    return null;
  }
}

Future<String?> _pickLinuxColor(String value) async {
  final hex = _normalizeHexColor(value);
  if (hex == null) {
    return null;
  }
  try {
    final result = await Process.run('sh', [
      '-lc',
      r'''
if command -v zenity >/dev/null 2>&1; then
  zenity --color-selection --color="$1"
elif command -v kdialog >/dev/null 2>&1; then
  kdialog --getcolor "$1"
else
  exit 127
fi
''',
      'smplayer-color-picker',
      hex,
    ]);
    if (result.exitCode != 0) {
      return null;
    }
    return _desktopColorSelectionToHex('${result.stdout}');
  } on Object {
    return null;
  }
}

(int, int, int)? _hexColorToRgb(String value) {
  final hex = _normalizeHexColor(value);
  if (hex == null) {
    return null;
  }
  final digits = hex.substring(1);
  return (
    int.parse(digits.substring(0, 2), radix: 16),
    int.parse(digits.substring(2, 4), radix: 16),
    int.parse(digits.substring(4, 6), radix: 16),
  );
}

(int, int, int)? _hexColorToAppleScriptRgb(String value) {
  final rgb = _hexColorToRgb(value);
  if (rgb == null) {
    return null;
  }
  return (rgb.$1 * 257, rgb.$2 * 257, rgb.$3 * 257);
}

String? _normalizeHexColor(String value) {
  final match = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(value.trim());
  if (match == null) {
    return null;
  }
  return '#${match.group(1)!.toLowerCase()}';
}

String? _desktopColorSelectionToHex(String value) {
  final raw = value.trim();
  final hex = _normalizeHexColor(raw);
  if (hex != null) {
    return hex;
  }
  final rgb = RegExp(
    r'^rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*[^)]*)?\)$',
  ).firstMatch(raw);
  if (rgb == null) {
    return null;
  }
  String component(int index) {
    return int.parse(
      rgb.group(index)!,
    ).clamp(0, 255).toRadixString(16).padLeft(2, '0');
  }

  return '#${component(1)}${component(2)}${component(3)}';
}

String _appleScriptRgbToHex(int red, int green, int blue) {
  String component(int value) {
    return (value / 257)
        .round()
        .clamp(0, 255)
        .toRadixString(16)
        .padLeft(2, '0');
  }

  return '#${component(red)}${component(green)}${component(blue)}';
}

int clampedDesktopLyricsOffset(int offsetMs) {
  return offsetMs.clamp(desktopLyricsOffsetMinMs, desktopLyricsOffsetMaxMs);
}

enum DesktopFeatureCommand {
  toggleWindowVisibility,
  showWindow,
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

abstract class DesktopFeatureService {
  Future<void> initialize(ValueChanged<DesktopFeatureAction> onAction);

  Future<List<String>> getSystemFonts();

  Future<void> updateTray(DesktopTrayState state);

  Future<void> showTrackNotification(TrackNotificationPayload payload);

  Future<void> updateMediaSession(MediaSessionDisplayState state);

  Future<void> updateDesktopLyricsState(DesktopLyricsDisplayState state);

  Future<void> enterMiniMode();

  Future<void> exitMiniMode();

  Future<void> startWindowDrag();

  Future<void> stopWindowDrag();

  Future<void> setWindowFullScreen(bool fullScreen);

  Future<void> setWindowControlsLight(bool light);

  Future<bool> getWindowFullScreen();

  Future<bool> getWindowMaximized();

  Future<bool> getWindowVisible();

  Future<void> showWindow();

  Future<void> toggleWindowVisibility();

  Future<void> minimizeWindow();

  Future<void> toggleWindowMaximized();

  Future<void> closeWindow();

  Future<void> quit();

  void dispose();
}

DesktopFeatureService createDesktopFeatureService({
  LibraryRepository? settingsRepository,
}) {
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    return TrayWindowDesktopFeatureService(
      settingsRepository: settingsRepository ?? const LibraryRepository(),
    );
  }
  if (!kIsWeb && Platform.isAndroid) {
    return MobileExternalOpenFeatureService();
  }
  return const NoopDesktopFeatureService();
}

class NoopDesktopFeatureService implements DesktopFeatureService {
  const NoopDesktopFeatureService();

  @override
  Future<void> initialize(ValueChanged<DesktopFeatureAction> onAction) async {}

  @override
  Future<List<String>> getSystemFonts() async {
    return const [];
  }

  @override
  Future<void> updateTray(DesktopTrayState state) async {}

  @override
  Future<void> showTrackNotification(TrackNotificationPayload payload) async {}

  @override
  Future<void> updateMediaSession(MediaSessionDisplayState state) async {}

  @override
  Future<void> updateDesktopLyricsState(
    DesktopLyricsDisplayState state,
  ) async {}

  @override
  Future<void> enterMiniMode() async {}

  @override
  Future<void> exitMiniMode() async {}

  @override
  Future<void> startWindowDrag() async {}

  @override
  Future<void> stopWindowDrag() async {}

  @override
  Future<void> setWindowFullScreen(bool fullScreen) async {}

  @override
  Future<void> setWindowControlsLight(bool light) async {}

  @override
  Future<bool> getWindowFullScreen() async {
    return false;
  }

  @override
  Future<bool> getWindowMaximized() async {
    return false;
  }

  @override
  Future<bool> getWindowVisible() async {
    return true;
  }

  @override
  Future<void> showWindow() async {}

  @override
  Future<void> toggleWindowVisibility() async {}

  @override
  Future<void> minimizeWindow() async {}

  @override
  Future<void> toggleWindowMaximized() async {}

  @override
  Future<void> closeWindow() async {}

  @override
  Future<void> quit() async {}

  @override
  void dispose() {}
}

class MobileExternalOpenFeatureService extends NoopDesktopFeatureService {
  MobileExternalOpenFeatureService();

  ValueChanged<DesktopFeatureAction>? _onAction;

  @override
  Future<void> initialize(ValueChanged<DesktopFeatureAction> onAction) async {
    _onAction = onAction;
    _desktopFeatureChannel.setMethodCallHandler(_handlePlatformMethodCall);
    final arguments = await _desktopFeatureChannel.invokeMethod<List<dynamic>>(
      'takeInitialExternalArguments',
    );
    if (arguments == null || arguments.isEmpty) {
      return;
    }
    _handleExternalArguments(arguments.whereType<String>().toList());
  }

  Future<void> _handlePlatformMethodCall(MethodCall call) async {
    if (call.method != 'openExternalArguments') {
      return;
    }
    _handleExternalArguments(
      (call.arguments as List).whereType<String>().toList(growable: false),
    );
  }

  void _handleExternalArguments(List<String> arguments) {
    _emitOpenExternalAudioFiles(externalAudioPathsFromArgs(arguments));
    for (final command in externalAppCommandsFromArgs(arguments)) {
      _emit(_desktopFeatureActionFromExternal(command));
    }
  }

  void _emitOpenExternalAudioFiles(List<String> paths) {
    if (paths.isEmpty) {
      return;
    }
    _emit(
      DesktopFeatureAction(
        DesktopFeatureCommand.openExternalAudioFiles,
        filePaths: paths,
      ),
    );
  }

  void _emit(DesktopFeatureAction action) {
    _onAction?.call(action);
  }

  @override
  void dispose() {
    _desktopFeatureChannel.setMethodCallHandler(null);
  }
}

class TrayWindowDesktopFeatureService
    with tray.TrayListener, WindowListener
    implements DesktopFeatureService {
  TrayWindowDesktopFeatureService({LibraryRepository? settingsRepository})
    : _settingsRepository = settingsRepository ?? const LibraryRepository();

  static const _mainWindowStateSaveDelay = Duration(milliseconds: 350);

  final LibraryRepository _settingsRepository;
  ValueChanged<DesktopFeatureAction>? _onAction;
  DesktopTrayState? _lastTrayState;
  List<String>? _cachedSystemFonts;
  Rect? _boundsBeforeMiniMode;
  Timer? _mainWindowStateSaveDebounce;
  Future<void> _mainWindowStateWriteQueue = Future.value();
  var _wasMaximizedBeforeMiniMode = false;
  var _initialized = false;
  var _quitting = false;
  var _shownTrayHint = false;
  var _miniModeActive = false;
  bool? _windowControlsLight;

  @override
  Future<void> initialize(ValueChanged<DesktopFeatureAction> onAction) async {
    _onAction = onAction;
    if (_initialized) {
      return;
    }
    _initialized = true;
    WidgetsFlutterBinding.ensureInitialized();
    await _ignorePlatformErrors(windowManager.ensureInitialized());
    await _ignorePlatformErrors(windowManager.setPreventClose(true));
    windowManager.addListener(this);
    tray.trayManager.addListener(this);
    await _ignorePlatformErrors(
      tray.trayManager.setIcon('assets/branding/monotone_no_bg.png'),
    );
    _desktopFeatureChannel.setMethodCallHandler(_handlePlatformMethodCall);
    await _takeInitialExternalArguments();
  }

  Future<void> _takeInitialExternalArguments() async {
    try {
      final arguments = await _desktopFeatureChannel
          .invokeMethod<List<dynamic>>('takeInitialExternalArguments');
      if (arguments == null || arguments.isEmpty) {
        return;
      }
      _handleExternalArguments(arguments.whereType<String>().toList());
    } on Object {
      // Native argument handoff is only implemented where the platform shell
      // supports live file/protocol open events.
    }
  }

  @override
  Future<List<String>> getSystemFonts() async {
    final cached = _cachedSystemFonts;
    if (cached != null) {
      return cached;
    }
    final fonts = await loadDesktopSystemFonts();
    _cachedSystemFonts = fonts;
    return fonts;
  }

  @override
  Future<void> updateTray(DesktopTrayState state) async {
    _lastTrayState = state;
    final entries = buildDesktopTrayMenuEntries(state);
    final menu = tray.Menu(items: entries.map(_toTrayMenuItem).toList());
    await _ignorePlatformErrors(tray.trayManager.setToolTip(state.appTitle));
    await _ignorePlatformErrors(tray.trayManager.setContextMenu(menu));
    if (Platform.isWindows) {
      await _ignorePlatformErrors(
        _desktopFeatureChannel.invokeMethod<void>('setRecentDocuments', {
          'label': state.labels.recent,
          'paths':
              state.recentSongs
                  .take(desktopRecentSongLimit)
                  .map((song) => song.path)
                  .toList(),
        }),
      );
    }
  }

  @override
  Future<void> showTrackNotification(TrackNotificationPayload payload) async {
    final body = desktopNotificationBody(payload);
    if (Platform.isMacOS) {
      await _ignorePlatformErrors(
        _desktopFeatureChannel.invokeMethod<void>('showTrackNotification', {
          'title': payload.title,
          'body': body,
          'songId': payload.songId,
          'silent': payload.silent,
        }),
      );
      return;
    }

    if (Platform.isWindows) {
      await _ignorePlatformErrors(
        Process.run('powershell', [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          windowsToastPowerShellCommand(payload, body),
        ]),
      );
      return;
    }

    if (Platform.isLinux) {
      await _ignorePlatformErrors(
        _desktopFeatureChannel.invokeMethod<void>('showTrackNotification', {
          'title': payload.title,
          'body': body,
          'songId': payload.songId,
          'silent': payload.silent,
        }),
      );
    }
  }

  @override
  Future<void> updateMediaSession(MediaSessionDisplayState state) async {
    await _ignorePlatformErrors(
      _desktopFeatureChannel.invokeMethod<void>(
        'updateMediaSession',
        state.toPlatformMap(),
      ),
    );
  }

  @override
  Future<void> updateDesktopLyricsState(DesktopLyricsDisplayState state) async {
    await _ignorePlatformErrors(
      _desktopFeatureChannel.invokeMethod<void>(
        'updateDesktopLyricsWindow',
        state.toPlatformMap(),
      ),
    );
  }

  @override
  Future<void> enterMiniMode() async {
    await _ignorePlatformErrors(_enterMiniMode());
  }

  @override
  Future<void> exitMiniMode() async {
    await _ignorePlatformErrors(_exitMiniMode());
  }

  @override
  Future<void> startWindowDrag() async {
    await _ignorePlatformErrors(windowManager.startDragging());
  }

  @override
  Future<void> stopWindowDrag() async {}

  @override
  Future<void> setWindowFullScreen(bool fullScreen) async {
    await _ignorePlatformErrors(_setWindowFullScreen(fullScreen));
  }

  @override
  Future<void> setWindowControlsLight(bool light) async {
    if (_windowControlsLight == light) {
      return;
    }
    _windowControlsLight = light;
    await _ignorePlatformErrors(
      _desktopFeatureChannel.invokeMethod<void>('setWindowControlsLight', {
        'light': light,
      }),
    );
  }

  @override
  Future<bool> getWindowFullScreen() async {
    try {
      return await windowManager.isFullScreen();
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> getWindowMaximized() async {
    return await windowManager.isMaximized();
  }

  @override
  Future<bool> getWindowVisible() async {
    try {
      return await windowManager.isVisible();
    } on Object {
      return true;
    }
  }

  @override
  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
    _emit(
      const DesktopFeatureAction(
        DesktopFeatureCommand.windowVisibilityChanged,
        isWindowVisible: true,
      ),
    );
  }

  @override
  Future<void> toggleWindowVisibility() async {
    final visible = await windowManager.isVisible();
    if (visible) {
      await windowManager.hide();
      _emit(
        const DesktopFeatureAction(
          DesktopFeatureCommand.windowVisibilityChanged,
          isWindowVisible: false,
        ),
      );
    } else {
      await windowManager.show();
      await windowManager.focus();
      _emit(
        const DesktopFeatureAction(
          DesktopFeatureCommand.windowVisibilityChanged,
          isWindowVisible: true,
        ),
      );
    }
  }

  @override
  Future<void> minimizeWindow() async {
    await _ignorePlatformErrors(windowManager.minimize());
  }

  @override
  Future<void> toggleWindowMaximized() async {
    final isMaximized = await windowManager.isMaximized();
    if (isMaximized) {
      await _ignorePlatformErrors(windowManager.unmaximize());
    } else {
      await _ignorePlatformErrors(windowManager.maximize());
    }
  }

  @override
  Future<void> closeWindow() async {
    await _ignorePlatformErrors(windowManager.close());
  }

  @override
  Future<void> quit() async {
    _quitting = true;
    await _ignorePlatformErrors(tray.trayManager.destroy());
    await _ignorePlatformErrors(windowManager.destroy());
  }

  @override
  void onTrayIconMouseDown() {
    _emit(
      const DesktopFeatureAction(DesktopFeatureCommand.toggleWindowVisibility),
    );
  }

  @override
  void onWindowClose() {
    unawaited(_saveMainWindowState(immediate: true));
    final state = _lastTrayState;
    if (_quitting || state?.quitOnClose == true) {
      _emit(const DesktopFeatureAction(DesktopFeatureCommand.quit));
      return;
    }
    unawaited(windowManager.hide());
    _emit(
      const DesktopFeatureAction(
        DesktopFeatureCommand.windowVisibilityChanged,
        isWindowVisible: false,
      ),
    );
    if (!_shownTrayHint && state != null) {
      _shownTrayHint = true;
      unawaited(
        showTrackNotification(
          TrackNotificationPayload(
            songId: 0,
            title: state.labels.trayRunningTitle,
            artist: state.labels.trayRunningBody,
            album: '',
            silent: true,
          ),
        ),
      );
    }
  }

  @override
  void onWindowMoved() {
    unawaited(_saveMainWindowState());
  }

  @override
  void onWindowResized() {
    unawaited(_saveMainWindowState());
  }

  @override
  void onWindowMaximize() {
    _emit(
      const DesktopFeatureAction(
        DesktopFeatureCommand.windowMaximizedChanged,
        isWindowMaximized: true,
      ),
    );
    unawaited(_saveMainWindowState(immediate: true));
  }

  @override
  void onWindowUnmaximize() {
    _emit(
      const DesktopFeatureAction(
        DesktopFeatureCommand.windowMaximizedChanged,
        isWindowMaximized: false,
      ),
    );
    unawaited(_saveMainWindowState(immediate: true));
  }

  @override
  void onWindowEnterFullScreen() {
    _emit(
      const DesktopFeatureAction(
        DesktopFeatureCommand.windowFullScreenChanged,
        isWindowFullScreen: true,
      ),
    );
  }

  @override
  void onWindowLeaveFullScreen() {
    _emit(
      const DesktopFeatureAction(
        DesktopFeatureCommand.windowFullScreenChanged,
        isWindowFullScreen: false,
      ),
    );
  }

  @override
  void dispose() {
    _mainWindowStateSaveDebounce?.cancel();
    tray.trayManager.removeListener(this);
    windowManager.removeListener(this);
    _desktopFeatureChannel.setMethodCallHandler(null);
  }

  Future<void> _handlePlatformMethodCall(MethodCall call) async {
    if (call.method == 'openFiles') {
      _emitOpenExternalAudioFiles(
        (call.arguments as List).whereType<String>().toList(growable: false),
      );
      return;
    }

    if (call.method == 'openExternalArguments') {
      _handleExternalArguments(
        (call.arguments as List).whereType<String>().toList(growable: false),
      );
      return;
    }

    if (call.method == 'desktopLyricsBoundsChanged') {
      final bounds = call.arguments as String;
      _emit(
        DesktopFeatureAction(
          DesktopFeatureCommand.desktopLyricsBoundsChanged,
          desktopLyricsBounds: bounds,
        ),
      );
      return;
    }

    if (call.method != 'desktopCommand') {
      return;
    }
    final command = call.arguments as String;
    if (command.startsWith('seek-to:')) {
      final seconds = double.tryParse(command.substring('seek-to:'.length));
      if (seconds != null) {
        _emit(
          DesktopFeatureAction(
            DesktopFeatureCommand.mediaSessionSeekTo,
            seekSeconds: seconds,
          ),
        );
      }
      return;
    }
    _emit(DesktopFeatureAction(_desktopFeatureCommandFromPlatform(command)));
  }

  void _handleExternalArguments(List<String> arguments) {
    _emitOpenExternalAudioFiles(externalAudioPathsFromArgs(arguments));
    for (final command in externalAppCommandsFromArgs(arguments)) {
      _emit(_desktopFeatureActionFromExternal(command));
    }
  }

  void _emitOpenExternalAudioFiles(List<String> paths) {
    if (paths.isEmpty) {
      return;
    }
    _emit(
      DesktopFeatureAction(
        DesktopFeatureCommand.openExternalAudioFiles,
        filePaths: paths,
      ),
    );
  }

  tray.MenuItem _toTrayMenuItem(DesktopTrayMenuEntry entry) {
    if (entry.separator) {
      return tray.MenuItem.separator();
    }
    if (entry.children.isNotEmpty) {
      return tray.MenuItem.submenu(
        key: _menuKey(entry),
        label: entry.label,
        submenu: tray.Menu(items: entry.children.map(_toTrayMenuItem).toList()),
      );
    }
    return tray.MenuItem(
      key: _menuKey(entry),
      label: entry.label,
      onClick: (_) {
        final action = entry.action;
        if (action != null) {
          _emit(DesktopFeatureAction(action, songId: entry.songId));
        }
      },
    );
  }

  String _menuKey(DesktopTrayMenuEntry entry) {
    final action = entry.action?.name ?? 'submenu';
    return entry.songId == null ? action : '$action-${entry.songId}';
  }

  void _emit(DesktopFeatureAction action) {
    _onAction?.call(action);
  }

  Future<void> _saveMainWindowState({bool immediate = false}) async {
    if (_miniModeActive || await windowManager.isFullScreen()) {
      return;
    }
    final maximized = await windowManager.isMaximized();
    final bounds = await windowManager.getBounds();
    final snapshot = smPlayerGlobalSettingsSnapshot.copyWith(
      mainWindowBounds: serializeMainWindowBounds(bounds),
      mainWindowMaximized: maximized,
    );
    setSmPlayerGlobalSettingsSnapshot(snapshot);
    _mainWindowStateSaveDebounce?.cancel();
    if (immediate) {
      await _persistMainWindowState(snapshot);
      return;
    }
    _mainWindowStateSaveDebounce = Timer(
      _mainWindowStateSaveDelay,
      () => unawaited(_persistMainWindowState(snapshot)),
    );
  }

  Future<void> _persistMainWindowState(SettingsSnapshot snapshot) {
    if (Platform.isMacOS) {
      return Future.value();
    }
    _mainWindowStateWriteQueue = _mainWindowStateWriteQueue
        .catchError((_) {})
        .then(
          (_) => _settingsRepository.saveMainWindowState(
            bounds: snapshot.mainWindowBounds,
            maximized: snapshot.mainWindowMaximized,
          ),
        );
    return _mainWindowStateWriteQueue;
  }

  Future<void> _enterMiniMode() async {
    if (!_miniModeActive) {
      _wasMaximizedBeforeMiniMode = await windowManager.isMaximized();
      if (_wasMaximizedBeforeMiniMode) {
        await windowManager.unmaximize();
      }
      _boundsBeforeMiniMode = await windowManager.getBounds();
    }
    if (await windowManager.isFullScreen()) {
      await windowManager.setFullScreen(false);
    }
    final bounds = await windowManager.getBounds();
    final workArea = await _workAreaForWindow(bounds);
    final miniBounds = miniModeWindowBoundsFor(bounds, workArea);
    _miniModeActive = true;
    await windowManager.setMinimumSize(_miniModeWindowSize);
    await windowManager.setBounds(miniBounds, animate: true);
    await windowManager.setResizable(true);
    await windowManager.setMaximizable(false);
    await windowManager.setAlwaysOnTop(true);
  }

  Future<void> _exitMiniMode() async {
    _miniModeActive = false;
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setResizable(true);
    await windowManager.setMaximizable(true);
    await windowManager.setMinimumSize(_defaultWindowMinimumSize);
    final bounds = _boundsBeforeMiniMode;
    if (bounds != null) {
      await windowManager.setBounds(bounds, animate: true);
    }
    if (_wasMaximizedBeforeMiniMode) {
      await windowManager.maximize();
    }
    _boundsBeforeMiniMode = null;
    _wasMaximizedBeforeMiniMode = false;
  }

  Future<void> _setWindowFullScreen(bool fullScreen) async {
    if (fullScreen && _miniModeActive) {
      await _exitMiniMode();
    }
    await windowManager.setFullScreen(fullScreen);
    _emit(
      DesktopFeatureAction(
        DesktopFeatureCommand.windowFullScreenChanged,
        isWindowFullScreen: fullScreen,
      ),
    );
  }

  Future<Rect> _workAreaForWindow(Rect windowBounds) async {
    final displays = await screen.screenRetriever.getAllDisplays();
    if (displays.isEmpty) {
      final primary = await screen.screenRetriever.getPrimaryDisplay();
      return _workAreaForDisplay(primary);
    }
    var selected = displays.first;
    var selectedOverlap = -1.0;
    for (final display in displays) {
      final overlap = _rectOverlapArea(
        windowBounds,
        _workAreaForDisplay(display),
      );
      if (overlap > selectedOverlap) {
        selected = display;
        selectedOverlap = overlap;
      }
    }
    return _workAreaForDisplay(selected);
  }

  Future<void> _ignorePlatformErrors<T>(Future<T> action) async {
    try {
      await action;
    } on Object {
      // Platform plugins are unavailable in widget tests and on unsupported
      // desktop shells. The feature service remains inert in that case.
    }
  }
}

Rect miniModeWindowBoundsFor(
  Rect currentBounds,
  Rect workArea, {
  Size miniModeSize = _miniModeWindowSize,
}) {
  final x =
      max(
        workArea.left,
        min(
          currentBounds.left + currentBounds.width - miniModeSize.width,
          workArea.right - miniModeSize.width,
        ),
      ).toDouble();
  final y =
      max(
        workArea.top,
        min(currentBounds.top, workArea.bottom - miniModeSize.height),
      ).toDouble();
  return Rect.fromLTWH(x, y, miniModeSize.width, miniModeSize.height);
}

class ShellProcessCommand {
  const ShellProcessCommand(this.executable, this.arguments);

  final String executable;
  final List<String> arguments;
}

Future<void> revealItemInFolder(String targetPath) async {
  final targetType = await FileSystemEntity.type(targetPath);
  if (targetType == FileSystemEntityType.notFound) {
    return;
  }
  final command = revealItemInFolderCommand(
    targetPath,
    operatingSystem: Platform.operatingSystem,
  );
  await Process.start(command.executable, command.arguments);
}

Future<void> openFolderInShell(String folderPath) async {
  final command = openFolderInShellCommand(
    folderPath,
    operatingSystem: Platform.operatingSystem,
  );
  await Process.start(command.executable, command.arguments);
}

ShellProcessCommand revealItemInFolderCommand(
  String targetPath, {
  required String operatingSystem,
}) {
  return switch (operatingSystem) {
    'windows' => ShellProcessCommand('explorer.exe', ['/select,$targetPath']),
    'macos' => ShellProcessCommand('open', ['-R', targetPath]),
    _ => ShellProcessCommand('xdg-open', [path.dirname(targetPath)]),
  };
}

ShellProcessCommand openFolderInShellCommand(
  String folderPath, {
  required String operatingSystem,
}) {
  return switch (operatingSystem) {
    'windows' => ShellProcessCommand('explorer.exe', [folderPath]),
    'macos' => ShellProcessCommand('open', [folderPath]),
    _ => ShellProcessCommand('xdg-open', [folderPath]),
  };
}

Rect _workAreaForDisplay(screen.Display display) {
  final visiblePosition = display.visiblePosition ?? Offset.zero;
  final visibleSize = display.visibleSize ?? display.size;
  return Rect.fromLTWH(
    visiblePosition.dx,
    visiblePosition.dy,
    visibleSize.width,
    visibleSize.height,
  );
}

double _rectOverlapArea(Rect left, Rect right) {
  final overlapWidth = max(
    0,
    min(left.right, right.right) - max(left.left, right.left),
  );
  final overlapHeight = max(
    0,
    min(left.bottom, right.bottom) - max(left.top, right.top),
  );
  return (overlapWidth * overlapHeight).toDouble();
}

Future<List<String>> loadDesktopSystemFonts() async {
  if (kIsWeb) {
    return const [];
  }
  if (Platform.isWindows) {
    return _readWindowsSystemFonts();
  }
  if (Platform.isMacOS) {
    return _readMacSystemFonts();
  }
  if (Platform.isLinux) {
    return _readLinuxSystemFonts();
  }
  return const [];
}

Future<List<String>> _readWindowsSystemFonts() async {
  try {
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      r'''
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$fontNames = foreach ($key in @(
  'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
  'Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
)) {
  if (Test-Path -LiteralPath $key) {
    (Get-ItemProperty -LiteralPath $key).PSObject.Properties |
      Where-Object { $_.MemberType -eq 'NoteProperty' -and $_.Name -notlike 'PS*' } |
      ForEach-Object { $_.Name }
  }
}
$fontNames | Sort-Object -Unique | ConvertTo-Json -Compress
''',
    ]);
    if (result.exitCode != 0) {
      return const [];
    }
    return systemFontFamiliesFromRawNames(_jsonStringArray('${result.stdout}'));
  } on Object {
    return const [];
  }
}

Future<List<String>> _readMacSystemFonts() async {
  try {
    final result = await Process.run('system_profiler', [
      'SPFontsDataType',
      '-json',
    ]);
    if (result.exitCode != 0) {
      return const [];
    }
    final decoded = jsonDecode('${result.stdout}') as Map<String, dynamic>;
    final fonts =
        (decoded['SPFontsDataType'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>();
    final names = <String>[];
    for (final font in fonts) {
      final name = font['_name'];
      if (name is String) {
        names.add(name);
      }
      final typefaces = font['typefaces'];
      if (typefaces is List) {
        names.addAll(
          typefaces
              .whereType<Map<String, dynamic>>()
              .map((typeface) => typeface['_name'])
              .whereType<String>(),
        );
      }
    }
    return systemFontFamiliesFromRawNames(names);
  } on Object {
    return const [];
  }
}

Future<List<String>> _readLinuxSystemFonts() async {
  try {
    final result = await Process.run('fc-list', [':', 'family']);
    if (result.exitCode != 0) {
      return const [];
    }
    return systemFontFamiliesFromRawNames(
      '${result.stdout}'
          .split(RegExp(r'\r?\n'))
          .expand((line) => line.split(','))
          .map((name) => name.trim()),
    );
  } on Object {
    return const [];
  }
}

List<String> _jsonStringArray(String raw) {
  final decoded = jsonDecode(raw.isEmpty ? '[]' : raw) as Object;
  return switch (decoded) {
    String value => [value],
    List<dynamic> values => values.whereType<String>().toList(),
    _ => const [],
  };
}

List<String> systemFontFamiliesFromRawNames(Iterable<String> fontNames) {
  final fontFamilies = <String>{};
  for (final fontName in fontNames) {
    fontFamilies.addAll(systemFontFamilyNames(fontName));
  }
  final sorted =
      fontFamilies
          .where((font) => font.isNotEmpty && !font.startsWith('.'))
          .toList();
  sorted.sort(
    (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
  );
  return sorted;
}

List<String> systemFontFamilyNames(String fontName) {
  final familyName =
      fontName.replaceFirst(RegExp(r'\s+\([^)]*\)\s*$'), '').trim();
  return familyName
      .split(RegExp(r'\s*&\s*'))
      .map(
        (name) =>
            name
                .replaceFirst(
                  RegExp(
                    r'\s+(Bold Italic|Light Italic|Medium Italic|SemiBold Italic|Black Italic|Thin|ExtraLight|UltraLight|Light|SemiLight|Regular|Medium|SemiBold|DemiBold|Bold|ExtraBold|UltraBold|Black|Heavy|Italic|Oblique)$',
                    caseSensitive: false,
                  ),
                  '',
                )
                .trim(),
      )
      .toList();
}

String desktopNotificationArtist(LibrarySong song, SmPlayerI18n i18n) {
  return displayArtists(song, i18n);
}

String desktopNotificationAlbum(LibrarySong song, SmPlayerI18n i18n) {
  return displayAlbum(song, i18n);
}

String desktopNotificationBody(TrackNotificationPayload payload) {
  final lyricsPreview = payload.lyricsPreview.trim();
  if (lyricsPreview.isNotEmpty) {
    return lyricsPreview;
  }
  final body = [
    payload.artist,
    payload.album,
  ].where((value) => value.isNotEmpty).join(' - ');
  return body.isEmpty ? 'Simple Melody Player' : body;
}

String windowsToastPowerShellCommand(
  TrackNotificationPayload payload,
  String body,
) {
  final title = _powerShellString(payload.title);
  final message = _powerShellString(body);
  final appId = _powerShellString(windowsAppUserModelId);
  final activationUri = _powerShellString(windowsToastActivationUri);
  final silentAudio =
      payload.silent
          ? r'''
$audio = $xml.CreateElement('audio')
$audio.SetAttribute('silent', 'true')
$xml.DocumentElement.AppendChild($audio) | Out-Null
'''
          : '';
  return '''
\$template = [Windows.UI.Notifications.ToastTemplateType]::ToastText02
\$xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(\$template)
\$xml.DocumentElement.SetAttribute('launch', $activationUri)
\$textNodes = \$xml.GetElementsByTagName('text')
\$textNodes.Item(0).AppendChild(\$xml.CreateTextNode($title)) | Out-Null
\$textNodes.Item(1).AppendChild(\$xml.CreateTextNode($message)) | Out-Null
$silentAudio\$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show(\$toast)
''';
}

String desktopNotificationLyricsPreview({
  required LyricsSnapshot lyrics,
  required LibrarySong song,
  required double progressSeconds,
}) {
  if (lyrics.lines.isEmpty) {
    return '';
  }
  if (!lyrics.isSynced) {
    return lyrics.lines.first.text.trim();
  }
  final index = currentDesktopLyricIndex(
    lyrics,
    progressSeconds,
    song.lyricsOffsetMs,
  );
  if (index < 0 || index >= lyrics.lines.length) {
    return '';
  }
  return lyrics.lines[index].text.trim();
}

String desktopRecentSongTitle(DesktopRecentSong song) {
  if (song.title.isNotEmpty) {
    return song.title;
  }
  return path.basename(song.path);
}

DesktopFeatureCommand desktopFeatureCommandFromPlatform(String command) {
  return switch (command) {
    'play-pause' => DesktopFeatureCommand.playPause,
    'previous' => DesktopFeatureCommand.previous,
    'next' => DesktopFeatureCommand.next,
    'stop' => DesktopFeatureCommand.stop,
    'quick-play' => DesktopFeatureCommand.quickPlay,
    'show-window' => DesktopFeatureCommand.showWindow,
    'toggle-desktop-lyrics' => DesktopFeatureCommand.toggleDesktopLyrics,
    'disable' ||
    'desktop-lyrics-disable' => DesktopFeatureCommand.disableDesktopLyrics,
    'toggle-lock' || 'desktop-lyrics-toggle-lock' =>
      DesktopFeatureCommand.toggleDesktopLyricsLock,
    'offset:-100' || 'desktop-lyrics-offset-backward' =>
      DesktopFeatureCommand.desktopLyricsOffsetBackward,
    'offset:100' || 'desktop-lyrics-offset-forward' =>
      DesktopFeatureCommand.desktopLyricsOffsetForward,
    'reset-offset' || 'desktop-lyrics-reset-offset' =>
      DesktopFeatureCommand.resetDesktopLyricsOffset,
    'open-settings' => DesktopFeatureCommand.openSettings,
    _ => throw ArgumentError.value(command, 'command'),
  };
}

DesktopFeatureCommand _desktopFeatureCommandFromPlatform(String command) {
  return desktopFeatureCommandFromPlatform(command);
}

DesktopFeatureAction _desktopFeatureActionFromExternal(
  ExternalAppCommand command,
) {
  if (command.kind == ExternalAppCommandKind.voiceCommand) {
    return DesktopFeatureAction(
      DesktopFeatureCommand.voiceCommand,
      voiceCommandText: command.text,
    );
  }
  return DesktopFeatureAction(switch (command.kind) {
    ExternalAppCommandKind.playPause => DesktopFeatureCommand.playPause,
    ExternalAppCommandKind.next => DesktopFeatureCommand.next,
    ExternalAppCommandKind.previous => DesktopFeatureCommand.previous,
    ExternalAppCommandKind.stop => DesktopFeatureCommand.stop,
    ExternalAppCommandKind.quickPlay => DesktopFeatureCommand.quickPlay,
    ExternalAppCommandKind.showWindow => DesktopFeatureCommand.showWindow,
    ExternalAppCommandKind.toggleDesktopLyrics =>
      DesktopFeatureCommand.toggleDesktopLyrics,
    ExternalAppCommandKind.voiceCommand => DesktopFeatureCommand.voiceCommand,
  });
}

const _miniModeWindowSize = Size(360, 360);
const _defaultWindowMinimumSize = Size(506, 840);

String _powerShellString(String value) {
  return "'${value.replaceAll("'", "''")}'";
}
