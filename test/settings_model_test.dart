import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

void main() {
  test('SettingsSnapshot defaults use Flutter startup defaults', () {
    const snapshot = SettingsSnapshot.defaults();

    expect(snapshot.rootPath, '');
    expect(snapshot.useFilenameNotMusicName, isFalse);
    expect(snapshot.smartMultiArtistRecognition, isTrue);
    expect(snapshot.showCount, isTrue);
    expect(snapshot.themeColor, '#0078D7');
    expect(snapshot.nightMode, NightMode.system);
    expect(snapshot.nightModeStartTime, '20:00');
    expect(snapshot.nightModeEndTime, '06:00');
    expect(snapshot.notificationSend, NotificationSendMode.never);
    expect(snapshot.notificationDisplay, NotificationDisplayMode.normal);
    expect(snapshot.showNotifications, isFalse);
    expect(snapshot.autoLyrics, isTrue);
    expect(snapshot.showLyricsInNotification, isFalse);
    expect(snapshot.notificationLyricsSource, LyricsRequestMode.internet);
    expect(snapshot.playerLyricsSource, LyricsRequestMode.auto);
    expect(snapshot.saveLyricsImmediately, isTrue);
    expect(snapshot.preserveInternetLyricsTimestamps, isTrue);
    expect(snapshot.desktopLyricsEnabled, isFalse);
    expect(snapshot.desktopLyricsLocked, isFalse);
    expect(snapshot.desktopLyricsColor, '#4aa8ff');
    expect(snapshot.desktopLyricsStrokeColor, '#111111');
    expect(snapshot.desktopLyricsFontSize, 28);
    expect(snapshot.desktopLyricsFontFamily, 'system');
    expect(snapshot.desktopLyricsOpacity, 88);
    expect(snapshot.desktopLyricsBounds, '');
    expect(snapshot.mainWindowBounds, '');
    expect(snapshot.mainWindowMaximized, isFalse);
    expect(snapshot.lastDisplayMode, SmPlayerDisplayMode.normal);
    expect(snapshot.preferredLanguage, PreferredLanguage.system);
    expect(snapshot.musicLibrarySort, MusicLibrarySortCriterion.title);
    expect(snapshot.albumsSort, AlbumSortCriterion.defaultCriterion);
    expect(
      snapshot.searchArtistsCriterion,
      SearchSortCriterion.defaultCriterion,
    );
    expect(
      snapshot.searchAlbumsCriterion,
      SearchSortCriterion.defaultCriterion,
    );
    expect(snapshot.searchSongsCriterion, SearchSortCriterion.defaultCriterion);
    expect(
      snapshot.searchPlaylistsCriterion,
      SearchSortCriterion.defaultCriterion,
    );
    expect(
      snapshot.searchFoldersCriterion,
      SearchSortCriterion.defaultCriterion,
    );
    expect(snapshot.lastMusicIndex, -1);
    expect(snapshot.volume, 50);
    expect(snapshot.isMuted, isFalse);
    expect(snapshot.mode, PlaybackMode.once);
    expect(snapshot.musicProgress, 0);
    expect(snapshot.autoPlay, isFalse);
    expect(snapshot.shuffleAfterOneRound, isTrue);
    expect(snapshot.previousButtonRestartsTrack, isTrue);
    expect(snapshot.saveMusicProgress, isTrue);
    expect(snapshot.hideMultiSelectCommandBarAfterOperation, isTrue);
    expect(snapshot.localViewMode, LocalViewMode.grid);
    expect(snapshot.quitOnClose, isTrue);
    expect(snapshot.lastPage, '/songs');
    expect(snapshot.lastPlaylistId, 0);
    expect(snapshot.lastReleaseNotesVersion, '');
  });

  test('SettingsSnapshot applies Electron AppSettingsUpdate fields', () {
    final snapshot = const SettingsSnapshot.defaults().apply(
      const AppSettingsUpdate(
        rootPath: r'C:\Music',
        useFilenameNotMusicName: true,
        smartMultiArtistRecognition: false,
        showCount: false,
        themeColor: '#112233',
        nightMode: NightMode.never,
        nightModeStartTime: '21:00',
        nightModeEndTime: '06:00',
        notificationSend: NotificationSendMode.never,
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
        desktopLyricsColor: '#FFFFFF',
        desktopLyricsStrokeColor: '',
        desktopLyricsFontSize: 32,
        desktopLyricsFontFamily: 'Segoe UI',
        desktopLyricsOpacity: 72,
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
        shuffleAfterOneRound: true,
        previousButtonRestartsTrack: false,
        saveMusicProgress: false,
        hideMultiSelectCommandBarAfterOperation: true,
        localViewMode: LocalViewMode.list,
        quitOnClose: true,
        lastReleaseNotesVersion: '1.2.3',
      ),
    );

    expect(snapshot.rootPath, r'C:\Music');
    expect(snapshot.useFilenameNotMusicName, isTrue);
    expect(snapshot.smartMultiArtistRecognition, isFalse);
    expect(snapshot.showCount, isFalse);
    expect(snapshot.themeColor, '#112233');
    expect(snapshot.nightMode, NightMode.never);
    expect(snapshot.nightModeStartTime, '21:00');
    expect(snapshot.nightModeEndTime, '06:00');
    expect(snapshot.notificationSend, NotificationSendMode.never);
    expect(snapshot.notificationDisplay, NotificationDisplayMode.quick);
    expect(snapshot.showNotifications, isTrue);
    expect(snapshot.autoLyrics, isFalse);
    expect(snapshot.showLyricsInNotification, isTrue);
    expect(snapshot.notificationLyricsSource, LyricsRequestMode.local);
    expect(snapshot.playerLyricsSource, LyricsRequestMode.embedded);
    expect(snapshot.saveLyricsImmediately, isFalse);
    expect(snapshot.preserveInternetLyricsTimestamps, isFalse);
    expect(snapshot.desktopLyricsEnabled, isTrue);
    expect(snapshot.desktopLyricsLocked, isTrue);
    expect(snapshot.desktopLyricsColor, '#FFFFFF');
    expect(snapshot.desktopLyricsStrokeColor, '');
    expect(snapshot.desktopLyricsFontSize, 32);
    expect(snapshot.desktopLyricsFontFamily, 'Segoe UI');
    expect(snapshot.desktopLyricsOpacity, 72);
    expect(snapshot.desktopLyricsBounds, '1,2,3,4');
    expect(snapshot.preferredLanguage, PreferredLanguage.zhCN);
    expect(snapshot.musicLibrarySort, MusicLibrarySortCriterion.dateAdded);
    expect(snapshot.albumsSort, AlbumSortCriterion.artist);
    expect(snapshot.searchArtistsCriterion, SearchSortCriterion.name);
    expect(snapshot.searchAlbumsCriterion, SearchSortCriterion.album);
    expect(snapshot.searchSongsCriterion, SearchSortCriterion.playCount);
    expect(snapshot.searchPlaylistsCriterion, SearchSortCriterion.title);
    expect(snapshot.searchFoldersCriterion, SearchSortCriterion.dateAdded);
    expect(snapshot.autoPlay, isTrue);
    expect(snapshot.shuffleAfterOneRound, isTrue);
    expect(snapshot.previousButtonRestartsTrack, isFalse);
    expect(snapshot.saveMusicProgress, isFalse);
    expect(snapshot.hideMultiSelectCommandBarAfterOperation, isTrue);
    expect(snapshot.localViewMode, LocalViewMode.list);
    expect(snapshot.quitOnClose, isTrue);
    expect(snapshot.lastReleaseNotesVersion, '1.2.3');
  });

  test('SettingsSnapshot applies Electron PlaybackSettingsUpdate fields', () {
    final snapshot = const SettingsSnapshot.defaults().applyPlaybackSettings(
      const PlaybackSettingsUpdate(
        lastMusicIndex: 3,
        volume: 72,
        isMuted: true,
        mode: PlaybackMode.shuffle,
        musicProgress: 45.5,
      ),
    );

    expect(snapshot.lastMusicIndex, 3);
    expect(snapshot.volume, 72);
    expect(snapshot.isMuted, isTrue);
    expect(snapshot.mode, PlaybackMode.shuffle);
    expect(snapshot.musicProgress, 45.5);
    expect(snapshot.playbackRuntimeSettings.volume, 72);
    expect(snapshot.playbackRuntimeSettings.isMuted, isTrue);
    expect(snapshot.playbackRuntimeSettings.mode, PlaybackMode.shuffle);
  });

  test(
    'SettingsSnapshot clears playback progress when saving progress is off',
    () {
      final snapshot = const SettingsSnapshot.defaults()
          .copyWith(musicProgress: 120)
          .apply(const AppSettingsUpdate(saveMusicProgress: false))
          .applyPlaybackSettings(
            const PlaybackSettingsUpdate(lastMusicIndex: 2, musicProgress: 45),
          );

      expect(snapshot.saveMusicProgress, isFalse);
      expect(snapshot.lastMusicIndex, 2);
      expect(snapshot.musicProgress, 0);
    },
  );

  test('settings labels mirror Electron zh-CN translations', () {
    expect(nightModeLabel(NightMode.system), '跟随系统');
    expect(nightModeLabel(NightMode.auto), '自定义');
    expect(nightModeLabel(NightMode.onMode), '开启');
    expect(nightModeLabel(NightMode.never), '永不');
    expect(notificationSendLabel(NotificationSendMode.musicChanged), '音乐变更');
    expect(notificationSendLabel(NotificationSendMode.never), '永不发送');
    expect(preferredLanguageLabel(PreferredLanguage.system), '跟随系统');
    expect(preferredLanguageLabel(PreferredLanguage.zhCN), '简体中文');
    expect(preferenceLevelLabel(PreferenceLevel.veryHigh), '非常高');
    expect(preferenceLevelLabel(PreferenceLevel.doNotAppear), '不出现');
  });

  test(
    'default preference snapshot keeps Electron section names and limits data',
    () {
      final snapshot = PreferenceSettingsSnapshot.defaults();

      expect(snapshot.enabled[PreferenceSectionKey.songs], isTrue);
      expect(snapshot.enabled[PreferenceSectionKey.artists], isTrue);
      expect(snapshot.others.map((item) => item.name), ['最近添加', '我喜欢']);
      expect(snapshot.others.first.level, PreferenceLevel.high);
      expect(snapshot.others.last.level, PreferenceLevel.higher);
    },
  );
}
