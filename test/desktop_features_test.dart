import 'package:flutter_test/flutter_test.dart';
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

  test(
    'desktop tray exposes recent songs without IDs and caps like JumpList',
    () {
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

      final recentMenu = entries.firstWhere((entry) => entry.label == 'Recent');

      expect(recentMenu.children, hasLength(desktopRecentSongLimit));
      expect(recentMenu.children.first.label, 'Song 1');
      expect(recentMenu.children.first.songId, 1);
      expect(
        recentMenu.children
            .map((entry) => entry.label)
            .any((label) => RegExp(r'^\d+$').hasMatch(label)),
        isFalse,
      );
      expect(
        recentMenu.children
            .map((entry) => entry.label)
            .any((label) => label.contains('/music')),
        isFalse,
      );
    },
  );

  test('desktop lyrics state follows Electron fallback text', () {
    final settings = const SettingsSnapshot.defaults().copyWith(
      desktopLyricsEnabled: true,
      desktopLyricsLocked: true,
      desktopLyricsColor: '#ffffff',
    );
    final state = DesktopLyricsDisplayState.fromShell(
      settings: settings,
      currentSong: _song,
      isPlaying: true,
      progressSeconds: 12,
    );

    expect(state.visible, isTrue);
    expect(state.playing, isTrue);
    expect(state.fallbackText, 'Track - Artist');
    expect(state.textColor, '#ffffff');
    expect(state.offsetMs, 120);
  });
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
