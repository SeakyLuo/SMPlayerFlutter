import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/platform/desktop_features.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

void main() {
  test('desktop tray menu mirrors Electron playback commands', () {
    final entries = buildDesktopTrayMenuEntries(
      DesktopTrayState(
        appTitle: 'Simple Melody Player',
        isPlaying: true,
        isWindowVisible: true,
        quitOnClose: false,
        labels: _labels,
        recentSongs: const [],
      ),
    );

    expect(
      entries.where((entry) => !entry.separator).map((entry) => entry.label),
      [
        'Hide window',
        'Pause',
        'Previous',
        'Next',
        'Quick play',
        'Desktop Lyrics',
        'Settings',
        'Quit',
      ],
    );
    expect(
      entries.where((entry) => !entry.separator).map((entry) => entry.action),
      [
        DesktopFeatureCommand.toggleWindowVisibility,
        DesktopFeatureCommand.playPause,
        DesktopFeatureCommand.previous,
        DesktopFeatureCommand.next,
        DesktopFeatureCommand.quickPlay,
        DesktopFeatureCommand.toggleDesktopLyrics,
        DesktopFeatureCommand.openSettings,
        DesktopFeatureCommand.quit,
      ],
    );
  });

  test('desktop tray keeps recent songs in JumpList only', () {
    final entries = buildDesktopTrayMenuEntries(
      DesktopTrayState(
        appTitle: 'Simple Melody Player',
        isPlaying: false,
        isWindowVisible: false,
        quitOnClose: false,
        labels: _labels,
        recentSongs: List.generate(
          12,
          (index) => DesktopRecentSong(
            id: index + 1,
            title: 'Song ${index + 1}',
            path: '/music/song-${index + 1}.mp3',
          ),
        ),
      ),
    );

    expect(entries.where((entry) => entry.label == 'Recent'), isEmpty);
  });

  test('desktop lyrics commands mirror Electron window command types', () {
    expect(
      desktopFeatureCommandFromPlatform('show-window'),
      DesktopFeatureCommand.showWindow,
    );
    expect(
      desktopFeatureCommandFromPlatform('stop'),
      DesktopFeatureCommand.stop,
    );
    expect(
      desktopFeatureCommandFromPlatform('toggle-lock'),
      DesktopFeatureCommand.toggleDesktopLyricsLock,
    );
    expect(
      desktopFeatureCommandFromPlatform('disable'),
      DesktopFeatureCommand.disableDesktopLyrics,
    );
    expect(
      desktopFeatureCommandFromPlatform('offset:-100'),
      DesktopFeatureCommand.desktopLyricsOffsetBackward,
    );
    expect(
      desktopFeatureCommandFromPlatform('offset:100'),
      DesktopFeatureCommand.desktopLyricsOffsetForward,
    );
    expect(
      desktopFeatureCommandFromPlatform('reset-offset'),
      DesktopFeatureCommand.resetDesktopLyricsOffset,
    );
    expect(
      desktopFeatureCommandFromPlatform('open-settings'),
      DesktopFeatureCommand.openSettings,
    );
  });

  test('desktop lyrics offset follows Electron limits', () {
    expect(clampedDesktopLyricsOffset(-10001), -10000);
    expect(clampedDesktopLyricsOffset(-10000), -10000);
    expect(clampedDesktopLyricsOffset(0), 0);
    expect(clampedDesktopLyricsOffset(10000), 10000);
    expect(clampedDesktopLyricsOffset(10001), 10000);
  });

  test('desktop lyrics state follows Electron fallback text', () {
    final settings = const SettingsSnapshot.defaults().copyWith(
      desktopLyricsEnabled: true,
      desktopLyricsLocked: true,
      desktopLyricsColor: '#ffffff',
    );
    final state = DesktopLyricsDisplayState.fromShell(
      settings: settings,
      currentSong: _song,
      lyricsLoading: true,
      isPlaying: true,
      progressSeconds: 12,
      durationSeconds: 180,
      i18n: const SmPlayerI18n(
        locale: 'zh-CN',
        messages: {
          'common.close': '关闭',
          'common.settings': '设置',
          'player.pause': '暂停',
          'player.play': '播放',
          'player.playPause': '播放或暂停',
          'player.previous': '上一首',
          'player.next': '下一首',
          'settings.desktopLyricsLockAction': '锁定',
          'settings.desktopLyricsUnlockAction': '解锁',
          'settings.desktopLyricsResetOffset': '重置',
        },
      ),
    );

    expect(state.visible, isTrue);
    expect(state.loading, isTrue);
    expect(state.nightMode, isFalse);
    expect(state.playing, isTrue);
    expect(state.fallbackText, 'Track - Artist');
    expect(state.textColor, '#ffffff');
    expect(state.progressSeconds, 12.12);
    expect(state.offsetMs, 120);
    expect(
      state.toPlatformMap(),
      containsPair('fallbackText', 'Track - Artist'),
    );
    expect(state.toPlatformMap(), containsPair('locked', true));
    expect(state.toPlatformMap(), containsPair('loading', true));
    expect(state.toPlatformMap(), containsPair('nightMode', false));
    expect(state.toPlatformMap(), containsPair('labelPrevious', '上一首'));
    expect(state.toPlatformMap(), containsPair('labelNext', '下一首'));
    expect(state.toPlatformMap(), containsPair('labelPlayPause', '暂停'));
    expect(state.toPlatformMap(), containsPair('labelResetOffset', '重置'));
    expect(state.toPlatformMap(), containsPair('labelLock', '锁定'));
    expect(state.toPlatformMap(), containsPair('labelUnlock', '解锁'));
    expect(state.toPlatformMap(), containsPair('labelSettings', '设置'));
    expect(state.toPlatformMap(), containsPair('labelClose', '关闭'));
    expect(state.toPlatformMap(), isNot(contains('labelPlay')));
    expect(state.toPlatformMap(), isNot(contains('labelPause')));
  });

  test('media session state mirrors Electron metadata payload', () {
    final state = MediaSessionDisplayState.fromShell(
      currentSong: _song,
      i18n: const SmPlayerI18n(
        locale: 'en-US',
        messages: {
          'common.artistUnknown': 'Unknown Artist',
          'common.albumUnknown': 'Unknown Album',
        },
      ),
      isPlaying: true,
      durationSeconds: 180,
      progressSeconds: 240,
    );

    expect(state.active, isTrue);
    expect(state.title, 'Track');
    expect(state.artist, 'Artist');
    expect(state.album, 'Album');
    expect(state.progressSeconds, 180);
    expect(state.toPlatformMap(), containsPair('playing', true));
  });

  test('desktop lyrics state carries only Electron current lyric line', () {
    final settings = const SettingsSnapshot.defaults().copyWith(
      desktopLyricsEnabled: true,
    );
    final state = DesktopLyricsDisplayState.fromShell(
      settings: settings,
      currentSong: _song,
      lyrics: const LyricsSnapshot(
        source: LyricsSource.musicFile,
        isSynced: true,
        rawText: '',
        lines: [
          LyricsLine(id: 1, timestampMs: 0, text: 'First line'),
          LyricsLine(id: 2, timestampMs: 1200, text: 'Second line'),
          LyricsLine(id: 3, timestampMs: 2400, text: 'Third line'),
        ],
      ),
      lyricsLoading: false,
      isPlaying: true,
      progressSeconds: 1.2,
      durationSeconds: 180,
    );

    expect(state.lyricText, 'Second line');
    expect(state.toPlatformMap(), isNot(contains('nextLyricText')));
  });

  test('desktop lyrics plain text follows Electron progress ratio', () {
    final settings = const SettingsSnapshot.defaults().copyWith(
      desktopLyricsEnabled: true,
    );
    final state = DesktopLyricsDisplayState.fromShell(
      settings: settings,
      currentSong: _song,
      lyrics: const LyricsSnapshot(
        source: LyricsSource.musicFile,
        isSynced: false,
        rawText: '',
        lines: [
          LyricsLine(id: 1, timestampMs: null, text: 'First plain'),
          LyricsLine(id: 2, timestampMs: null, text: 'Second plain'),
          LyricsLine(id: 3, timestampMs: null, text: 'Third plain'),
        ],
      ),
      lyricsLoading: false,
      isPlaying: true,
      progressSeconds: 60,
      durationSeconds: 180,
    );

    expect(state.lyricText, 'Second plain');
  });

  test('desktop lyrics text collapses multiline content like Electron', () {
    expect(
      desktopLyricsText(
        lyrics: const LyricsSnapshot(
          source: LyricsSource.musicFile,
          isSynced: true,
          rawText: '',
          lines: [
            LyricsLine(id: 1, timestampMs: 0, text: '\n  Current line\\nNext'),
          ],
        ),
        progressSeconds: 0,
        progressRatio: 0,
      ),
      'Current line',
    );
  });

  test('track notification payload matches Electron body contract', () {
    expect(
      desktopNotificationBody(
        const TrackNotificationPayload(
          songId: 12,
          title: 'Track',
          artist: 'Artist',
          album: 'Album',
        ),
      ),
      'Artist - Album',
    );
    expect(
      desktopNotificationBody(
        const TrackNotificationPayload(
          songId: 12,
          title: 'Track',
          artist: '',
          album: '',
        ),
      ),
      'Simple Melody Player',
    );
    expect(
      desktopNotificationBody(
        const TrackNotificationPayload(
          songId: 12,
          title: 'Track',
          artist: 'Artist',
          album: 'Album',
          lyricsPreview: 'Current lyric',
        ),
      ),
      'Current lyric',
    );
  });

  test('windows toast command mirrors Electron app id and silent flag', () {
    final normalCommand = windowsToastPowerShellCommand(
      const TrackNotificationPayload(
        songId: 12,
        title: 'Track',
        artist: 'Artist',
        album: 'Album',
      ),
      'Artist - Album',
    );
    expect(normalCommand, contains("'$windowsAppUserModelId'"));
    expect(normalCommand, contains("'$windowsToastActivationUri'"));
    expect(normalCommand, contains("SetAttribute('launch'"));
    expect(normalCommand, isNot(contains("silent', 'true")));

    final silentCommand = windowsToastPowerShellCommand(
      const TrackNotificationPayload(
        songId: 0,
        title: 'Still running',
        artist: 'Use tray to restore.',
        album: '',
        silent: true,
      ),
      'Use tray to restore.',
    );
    expect(silentCommand, contains("SetAttribute('silent', 'true')"));
    expect(silentCommand, contains("'$windowsAppUserModelId'"));
  });

  test('track notification lyrics preview uses current synced line', () {
    expect(
      desktopNotificationLyricsPreview(
        lyrics: const LyricsSnapshot(
          source: LyricsSource.musicFile,
          isSynced: true,
          rawText: '',
          lines: [
            LyricsLine(id: 1, timestampMs: 0, text: 'First line'),
            LyricsLine(id: 2, timestampMs: 1200, text: 'Second line'),
          ],
        ),
        song: _song,
        progressSeconds: 1.1,
      ),
      'Second line',
    );
    expect(
      desktopNotificationLyricsPreview(
        lyrics: const LyricsSnapshot(
          source: LyricsSource.musicFile,
          isSynced: false,
          rawText: 'Plain lyric',
          lines: [LyricsLine(id: 1, timestampMs: null, text: 'Plain lyric')],
        ),
        song: _song,
        progressSeconds: 1.1,
      ),
      'Plain lyric',
    );
  });

  test('system font names are normalized like Electron font service', () {
    expect(
      systemFontFamiliesFromRawNames([
        'Segoe UI Bold (TrueType)',
        'Microsoft YaHei UI Regular & Microsoft YaHei UI Light',
        'Aptos Italic',
      ]),
      ['Aptos', 'Microsoft YaHei UI', 'Segoe UI'],
    );
  });

  test('mini mode bounds stay inside the current Electron work area', () {
    final bounds = miniModeWindowBoundsFor(
      const Rect.fromLTWH(1120, 20, 400, 700),
      const Rect.fromLTWH(0, 0, 1280, 720),
    );

    expect(bounds, const Rect.fromLTWH(920, 20, 360, 360));

    final clamped = miniModeWindowBoundsFor(
      const Rect.fromLTWH(-80, 500, 400, 700),
      const Rect.fromLTWH(0, 0, 1280, 720),
    );

    expect(clamped, const Rect.fromLTWH(0, 360, 360, 360));
  });

  test('reveal item commands use one Electron-style shell contract', () {
    final windows = revealItemInFolderCommand(
      r'C:\Music\Track.mp3',
      operatingSystem: 'windows',
    );
    expect(windows.executable, 'explorer.exe');
    expect(windows.arguments, [r'/select,C:\Music\Track.mp3']);

    final macos = revealItemInFolderCommand(
      '/Users/me/Music/Track.mp3',
      operatingSystem: 'macos',
    );
    expect(macos.executable, 'open');
    expect(macos.arguments, ['-R', '/Users/me/Music/Track.mp3']);

    final linux = revealItemInFolderCommand(
      '/home/me/Music/Track.mp3',
      operatingSystem: 'linux',
    );
    expect(linux.executable, 'xdg-open');
    expect(linux.arguments, ['/home/me/Music']);
  });

  test(
    'open folder commands are shared by Local, Search, and settings logs',
    () {
      expect(
        openFolderInShellCommand(
          r'C:\Music',
          operatingSystem: 'windows',
        ).arguments,
        [r'C:\Music'],
      );
      expect(
        openFolderInShellCommand(
          '/Users/me/Music',
          operatingSystem: 'macos',
        ).arguments,
        ['/Users/me/Music'],
      );
      expect(
        openFolderInShellCommand(
          '/home/me/Music',
          operatingSystem: 'linux',
        ).arguments,
        ['/home/me/Music'],
      );
    },
  );
}

const _labels = DesktopTrayLabels(
  showWindow: 'Show window',
  hideWindow: 'Hide window',
  play: 'Play',
  pause: 'Pause',
  previous: 'Previous',
  next: 'Next',
  quickPlay: 'Quick play',
  desktopLyrics: 'Desktop Lyrics',
  recent: 'Recent',
  settings: 'Settings',
  quit: 'Quit',
  trayRunningTitle: 'Still running',
  trayRunningBody: 'Use tray to restore.',
);

const _song = LibrarySong(
  id: 1,
  path: '/music/track.mp3',
  title: 'Track',
  artist: 'Artist',
  artists: ['Artist'],
  album: 'Album',
  duration: 180,
  playCount: 0,
  lyricsOffsetMs: 120,
  dateAdded: '2026-05-20',
  favorite: false,
  thumbnailPath: '',
);
