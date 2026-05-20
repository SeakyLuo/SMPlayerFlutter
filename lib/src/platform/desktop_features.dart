import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

const desktopRecentSongLimit = 10;
const _desktopFeatureChannel = MethodChannel(
  'smplayer_flutter/desktop_features',
);

enum DesktopFeatureCommand {
  toggleWindowVisibility,
  playPause,
  previous,
  next,
  stop,
  quickPlay,
  toggleDesktopLyrics,
  openSettings,
  quit,
  playRecentSong,
}

class DesktopFeatureAction {
  const DesktopFeatureAction(this.command, {this.songId});

  final DesktopFeatureCommand command;
  final int? songId;
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
  final recentSongs = state.recentSongs.take(desktopRecentSongLimit).toList();
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
    if (recentSongs.isNotEmpty) ...[
      const DesktopTrayMenuEntry.separator(),
      DesktopTrayMenuEntry(
        label: labels.recent,
        action: null,
        children:
            recentSongs
                .map(
                  (song) => DesktopTrayMenuEntry(
                    label: desktopRecentSongTitle(song),
                    action: DesktopFeatureCommand.playRecentSong,
                    songId: song.id,
                  ),
                )
                .toList(),
      ),
    ],
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
    required this.title,
    required this.artist,
    required this.album,
  });

  final String title;
  final String artist;
  final String album;
}

class DesktopLyricsDisplayState {
  const DesktopLyricsDisplayState({
    required this.visible,
    required this.playing,
    required this.locked,
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
  });

  factory DesktopLyricsDisplayState.fromShell({
    required SettingsSnapshot settings,
    required LibrarySong? currentSong,
    required bool isPlaying,
    required double progressSeconds,
  }) {
    final artist = currentSong?.artist ?? '';
    final fallbackText =
        currentSong == null
            ? ''
            : artist.isEmpty
            ? currentSong.title
            : '${currentSong.title} - $artist';
    return DesktopLyricsDisplayState(
      visible: settings.desktopLyricsEnabled && currentSong != null,
      playing: isPlaying,
      locked: settings.desktopLyricsLocked,
      opacity: settings.desktopLyricsOpacity,
      fontSize: settings.desktopLyricsFontSize,
      fontFamily: settings.desktopLyricsFontFamily,
      textColor: settings.desktopLyricsColor,
      strokeColor: settings.desktopLyricsStrokeColor,
      lyricText: '',
      fallbackText: fallbackText,
      songTitle: currentSong?.title ?? '',
      artist: artist,
      progressSeconds: progressSeconds,
      offsetMs: currentSong?.lyricsOffsetMs ?? 0,
    );
  }

  final bool visible;
  final bool playing;
  final bool locked;
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

  String get signature {
    return [
      visible,
      playing,
      locked,
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
    ].join('\n');
  }
}

abstract class DesktopFeatureService {
  Future<void> initialize(ValueChanged<DesktopFeatureAction> onAction);

  Future<void> updateTray(DesktopTrayState state);

  Future<void> showTrackNotification(TrackNotificationPayload payload);

  Future<void> updateDesktopLyricsState(DesktopLyricsDisplayState state);

  Future<void> enterMiniMode();

  Future<void> exitMiniMode();

  Future<void> toggleWindowVisibility();

  Future<void> quit();

  void dispose();
}

DesktopFeatureService createDesktopFeatureService() {
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    return TrayWindowDesktopFeatureService();
  }
  return const NoopDesktopFeatureService();
}

class NoopDesktopFeatureService implements DesktopFeatureService {
  const NoopDesktopFeatureService();

  @override
  Future<void> initialize(ValueChanged<DesktopFeatureAction> onAction) async {}

  @override
  Future<void> updateTray(DesktopTrayState state) async {}

  @override
  Future<void> showTrackNotification(TrackNotificationPayload payload) async {}

  @override
  Future<void> updateDesktopLyricsState(
    DesktopLyricsDisplayState state,
  ) async {}

  @override
  Future<void> enterMiniMode() async {}

  @override
  Future<void> exitMiniMode() async {}

  @override
  Future<void> toggleWindowVisibility() async {}

  @override
  Future<void> quit() async {}

  @override
  void dispose() {}
}

class TrayWindowDesktopFeatureService
    with tray.TrayListener, WindowListener
    implements DesktopFeatureService {
  ValueChanged<DesktopFeatureAction>? _onAction;
  DesktopTrayState? _lastTrayState;
  Rect? _boundsBeforeMiniMode;
  var _initialized = false;
  var _quitting = false;
  var _shownTrayHint = false;
  var _miniModeActive = false;

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
        _desktopFeatureChannel.invokeMethod<void>(
          'setRecentDocuments',
          state.recentSongs
              .take(desktopRecentSongLimit)
              .map((song) => song.path)
              .toList(),
        ),
      );
    }
  }

  @override
  Future<void> showTrackNotification(TrackNotificationPayload payload) async {
    final body =
        payload.album.isEmpty
            ? payload.artist
            : '${payload.artist}\n${payload.album}';
    if (Platform.isMacOS) {
      await _ignorePlatformErrors(
        Process.run('osascript', [
          '-e',
          'display notification ${_appleScriptString(body)} with title ${_appleScriptString(payload.title)}',
        ]),
      );
      return;
    }

    if (Platform.isWindows) {
      final title = _powerShellString(payload.title);
      final message = _powerShellString(body);
      await _ignorePlatformErrors(
        Process.run('powershell', [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          '''
\$template = [Windows.UI.Notifications.ToastTemplateType]::ToastText02
\$xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(\$template)
\$textNodes = \$xml.GetElementsByTagName('text')
\$textNodes.Item(0).AppendChild(\$xml.CreateTextNode($title)) | Out-Null
\$textNodes.Item(1).AppendChild(\$xml.CreateTextNode($message)) | Out-Null
\$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('SMPlayer').Show(\$toast)
''',
        ]),
      );
      return;
    }

    if (Platform.isLinux) {
      await _ignorePlatformErrors(
        Process.run('notify-send', [payload.title, body]),
      );
    }
  }

  @override
  Future<void> updateDesktopLyricsState(DesktopLyricsDisplayState state) async {
    await _ignorePlatformErrors(
      windowManager.setIgnoreMouseEvents(state.visible && state.locked),
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
  Future<void> toggleWindowVisibility() async {
    final visible = await windowManager.isVisible();
    if (visible) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
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
    final state = _lastTrayState;
    if (_quitting || state?.quitOnClose == true) {
      _emit(const DesktopFeatureAction(DesktopFeatureCommand.quit));
      return;
    }
    unawaited(windowManager.hide());
    if (!_shownTrayHint && state != null) {
      _shownTrayHint = true;
      unawaited(
        showTrackNotification(
          TrackNotificationPayload(
            title: state.labels.trayRunningTitle,
            artist: state.labels.trayRunningBody,
            album: '',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    tray.trayManager.removeListener(this);
    windowManager.removeListener(this);
    _desktopFeatureChannel.setMethodCallHandler(null);
  }

  Future<void> _handlePlatformMethodCall(MethodCall call) async {
    if (call.method != 'desktopCommand') {
      return;
    }
    final command = call.arguments as String;
    _emit(DesktopFeatureAction(_desktopFeatureCommandFromPlatform(command)));
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

  Future<void> _enterMiniMode() async {
    if (!_miniModeActive) {
      _boundsBeforeMiniMode = await windowManager.getBounds();
    }
    if (await windowManager.isFullScreen()) {
      await windowManager.setFullScreen(false);
    }
    final bounds = await windowManager.getBounds();
    final x = bounds.left + bounds.width - _miniModeWindowSize.width;
    final y = bounds.top;
    _miniModeActive = true;
    await windowManager.setMinimumSize(_miniModeWindowSize);
    await windowManager.setBounds(
      Rect.fromLTWH(
        x,
        y,
        _miniModeWindowSize.width,
        _miniModeWindowSize.height,
      ),
      animate: true,
    );
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
    _boundsBeforeMiniMode = null;
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

String desktopNotificationArtist(LibrarySong song, SmPlayerI18n i18n) {
  if (song.artists.isNotEmpty) {
    return song.artists.join(i18n.t('common.artistSeparator'));
  }
  if (song.artist.isNotEmpty) {
    return song.artist;
  }
  return i18n.t('common.artistUnknown');
}

String desktopNotificationAlbum(LibrarySong song, SmPlayerI18n i18n) {
  return song.album.isEmpty ? i18n.t('common.albumUnknown') : song.album;
}

String desktopRecentSongTitle(DesktopRecentSong song) {
  if (song.title.isNotEmpty) {
    return song.title;
  }
  return path.basename(song.path);
}

DesktopFeatureCommand _desktopFeatureCommandFromPlatform(String command) {
  return switch (command) {
    'play-pause' => DesktopFeatureCommand.playPause,
    'previous' => DesktopFeatureCommand.previous,
    'next' => DesktopFeatureCommand.next,
    'stop' => DesktopFeatureCommand.stop,
    'quick-play' => DesktopFeatureCommand.quickPlay,
    'show-window' => DesktopFeatureCommand.toggleWindowVisibility,
    'toggle-desktop-lyrics' => DesktopFeatureCommand.toggleDesktopLyrics,
    _ => throw ArgumentError.value(command, 'command'),
  };
}

const _miniModeWindowSize = Size(360, 360);
const _defaultWindowMinimumSize = Size(506, 840);

String _appleScriptString(String value) {
  return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
}

String _powerShellString(String value) {
  return "'${value.replaceAll("'", "''")}'";
}
