import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'SettingsController updates and persists Electron settings snapshot',
    () async {
      final controller = SettingsController();

      await controller.updateSettings(
        const AppSettingsUpdate(
          rootPath: r'C:\Music',
          themeColor: '#112233',
          nightMode: NightMode.auto,
          nightModeStartTime: '21:00',
          nightModeEndTime: '05:00',
          notificationSend: NotificationSendMode.musicChanged,
          notificationDisplay: NotificationDisplayMode.quick,
          showNotifications: true,
          autoLyrics: false,
          showLyricsInNotification: true,
          notificationLyricsSource: LyricsRequestMode.local,
          playerLyricsSource: LyricsRequestMode.embedded,
          saveLyricsImmediately: false,
          preserveInternetLyricsTimestamps: false,
          desktopLyricsEnabled: true,
          desktopLyricsLocked: true,
          desktopLyricsColor: '#ffffff',
          desktopLyricsFontSize: 32,
          desktopLyricsBounds: '1,2,3,4',
          preferredLanguage: PreferredLanguage.zhCN,
          musicLibrarySort: MusicLibrarySortCriterion.dateAdded,
          albumsSort: AlbumSortCriterion.artist,
          searchArtistsCriterion: SearchSortCriterion.name,
          searchAlbumsCriterion: SearchSortCriterion.album,
          searchSongsCriterion: SearchSortCriterion.playCount,
          searchPlaylistsCriterion: SearchSortCriterion.title,
          searchFoldersCriterion: SearchSortCriterion.dateAdded,
          autoPlay: true,
          shuffleAfterOneRound: false,
          saveMusicProgress: false,
          localViewMode: LocalViewMode.list,
          quitOnClose: false,
          lastReleaseNotesVersion: '1.2.3',
        ),
      );

      expect(controller.snapshot.rootPath, r'C:\Music');
      expect(controller.snapshot.themeColor, '#112233');
      expect(controller.snapshot.nightMode, NightMode.auto);
      expect(
        controller.snapshot.notificationSend,
        NotificationSendMode.musicChanged,
      );
      expect(
        controller.snapshot.notificationDisplay,
        NotificationDisplayMode.quick,
      );
      expect(controller.snapshot.showNotifications, isTrue);
      expect(controller.snapshot.autoLyrics, isFalse);
      expect(controller.snapshot.showLyricsInNotification, isTrue);
      expect(
        controller.snapshot.notificationLyricsSource,
        LyricsRequestMode.local,
      );
      expect(
        controller.snapshot.playerLyricsSource,
        LyricsRequestMode.embedded,
      );
      expect(controller.snapshot.saveLyricsImmediately, isFalse);
      expect(controller.snapshot.preserveInternetLyricsTimestamps, isFalse);
      expect(controller.snapshot.desktopLyricsEnabled, isTrue);
      expect(controller.snapshot.desktopLyricsLocked, isTrue);
      expect(controller.snapshot.desktopLyricsFontSize, 32);
      expect(controller.snapshot.desktopLyricsBounds, '1,2,3,4');
      expect(controller.snapshot.preferredLanguage, PreferredLanguage.zhCN);
      expect(
        controller.snapshot.musicLibrarySort,
        MusicLibrarySortCriterion.dateAdded,
      );
      expect(controller.snapshot.albumsSort, AlbumSortCriterion.artist);
      expect(
        controller.snapshot.searchArtistsCriterion,
        SearchSortCriterion.name,
      );
      expect(
        controller.snapshot.searchAlbumsCriterion,
        SearchSortCriterion.album,
      );
      expect(
        controller.snapshot.searchSongsCriterion,
        SearchSortCriterion.playCount,
      );
      expect(
        controller.snapshot.searchPlaylistsCriterion,
        SearchSortCriterion.title,
      );
      expect(
        controller.snapshot.searchFoldersCriterion,
        SearchSortCriterion.dateAdded,
      );
      expect(controller.snapshot.autoPlay, isTrue);
      expect(controller.snapshot.shuffleAfterOneRound, isFalse);
      expect(controller.snapshot.saveMusicProgress, isFalse);
      expect(controller.snapshot.localViewMode, LocalViewMode.list);
      expect(controller.snapshot.quitOnClose, isFalse);
      expect(controller.snapshot.lastReleaseNotesVersion, '1.2.3');

      await controller.savePlaybackSettings(
        const PlaybackSettingsUpdate(
          lastMusicIndex: 4,
          volume: 72,
          isMuted: true,
          mode: PlaybackMode.repeatOne,
          musicProgress: 92.5,
        ),
      );

      expect(controller.snapshot.lastMusicIndex, 4);
      expect(controller.snapshot.volume, 72);
      expect(controller.snapshot.isMuted, isTrue);
      expect(controller.snapshot.mode, PlaybackMode.repeatOne);
      expect(controller.snapshot.musicProgress, 0);

      final restored = SettingsController();
      await restored.refresh();

      expect(restored.snapshot.rootPath, r'C:\Music');
      expect(restored.snapshot.themeColor, '#112233');
      expect(restored.snapshot.nightMode, NightMode.auto);
      expect(restored.snapshot.nightModeStartTime, '21:00');
      expect(restored.snapshot.nightModeEndTime, '05:00');
      expect(
        restored.snapshot.notificationSend,
        NotificationSendMode.musicChanged,
      );
      expect(
        restored.snapshot.notificationDisplay,
        NotificationDisplayMode.quick,
      );
      expect(restored.snapshot.showNotifications, isTrue);
      expect(restored.snapshot.autoLyrics, isFalse);
      expect(restored.snapshot.showLyricsInNotification, isTrue);
      expect(
        restored.snapshot.notificationLyricsSource,
        LyricsRequestMode.local,
      );
      expect(restored.snapshot.playerLyricsSource, LyricsRequestMode.embedded);
      expect(restored.snapshot.saveLyricsImmediately, isFalse);
      expect(restored.snapshot.preserveInternetLyricsTimestamps, isFalse);
      expect(restored.snapshot.desktopLyricsEnabled, isTrue);
      expect(restored.snapshot.desktopLyricsLocked, isTrue);
      expect(restored.snapshot.desktopLyricsColor, '#ffffff');
      expect(restored.snapshot.desktopLyricsFontSize, 32);
      expect(restored.snapshot.desktopLyricsBounds, '1,2,3,4');
      expect(restored.snapshot.preferredLanguage, PreferredLanguage.zhCN);
      expect(
        restored.snapshot.musicLibrarySort,
        MusicLibrarySortCriterion.dateAdded,
      );
      expect(restored.snapshot.albumsSort, AlbumSortCriterion.artist);
      expect(
        restored.snapshot.searchArtistsCriterion,
        SearchSortCriterion.name,
      );
      expect(
        restored.snapshot.searchAlbumsCriterion,
        SearchSortCriterion.album,
      );
      expect(
        restored.snapshot.searchSongsCriterion,
        SearchSortCriterion.playCount,
      );
      expect(
        restored.snapshot.searchPlaylistsCriterion,
        SearchSortCriterion.title,
      );
      expect(
        restored.snapshot.searchFoldersCriterion,
        SearchSortCriterion.dateAdded,
      );
      expect(restored.snapshot.lastMusicIndex, 4);
      expect(restored.snapshot.volume, 72);
      expect(restored.snapshot.isMuted, isTrue);
      expect(restored.snapshot.mode, PlaybackMode.repeatOne);
      expect(restored.snapshot.musicProgress, 0);
      expect(restored.snapshot.autoPlay, isTrue);
      expect(restored.snapshot.shuffleAfterOneRound, isFalse);
      expect(restored.snapshot.saveMusicProgress, isFalse);
      expect(restored.snapshot.localViewMode, LocalViewMode.list);
      expect(restored.snapshot.quitOnClose, isFalse);
      expect(restored.snapshot.lastReleaseNotesVersion, '1.2.3');
    },
  );

  test(
    'SettingsController refresh keeps Electron defaults when storage is empty',
    () async {
      final controller = SettingsController();

      await controller.refresh();

      expect(controller.snapshot.nightMode, NightMode.never);
      expect(controller.snapshot.nightModeStartTime, '20:00');
      expect(controller.snapshot.nightModeEndTime, '06:00');
      expect(controller.snapshot.notificationSend, NotificationSendMode.never);
      expect(controller.snapshot.volume, 50);
      expect(controller.snapshot.isMuted, isFalse);
      expect(controller.snapshot.mode, PlaybackMode.once);
      expect(controller.snapshot.musicProgress, 0);
      expect(controller.snapshot.shuffleAfterOneRound, isTrue);
      expect(
        controller.snapshot.hideMultiSelectCommandBarAfterOperation,
        isTrue,
      );
      expect(controller.snapshot.quitOnClose, isTrue);
    },
  );

  test(
    'SettingsController mirrors Electron immediate playback settings api',
    () {
      final controller = SettingsController();

      controller.savePlaybackSettingsImmediate(
        const PlaybackSettingsUpdate(
          volume: 30,
          isMuted: true,
          mode: PlaybackMode.repeat,
        ),
      );

      final runtimeSettings = controller.getPlaybackSettingsImmediate();

      expect(runtimeSettings.volume, 30);
      expect(runtimeSettings.isMuted, isTrue);
      expect(runtimeSettings.mode, PlaybackMode.repeat);
    },
  );
}
