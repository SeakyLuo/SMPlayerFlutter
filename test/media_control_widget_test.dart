import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'common.nowPlaying': 'Now Playing',
      'common.myFavorites': 'My Favorites',
      'context.addToPlaylist': 'Add To',
      'context.seeAlbum': 'See Album',
      'context.seeAlbumArt': 'See Album Art',
      'context.seeLyrics': 'See Lyrics',
      'context.seeLocalFile': 'See Local File',
      'context.seeMusicInfo': 'See Music Info',
      'nowPlaying.exitFullScreenItem': 'Exit Full Screen',
      'nowPlaying.fullScreen': 'Full Screen',
      'nowPlaying.quickPlay': 'Quick Play',
      'player.enterMiniMode': 'Enter Mini Mode',
      'player.like': 'Add to My Favorites',
      'player.more': 'More',
      'player.mute': 'Mute',
      'player.next': 'Next',
      'player.pause': 'Pause',
      'player.play': 'Play',
      'player.playbackLoadFailed': 'Could not play this song.',
      'player.playbackMode': 'Playback Mode',
      'player.playbackModeList': 'List',
      'player.playbackModeRepeat': 'Repeat',
      'player.playbackModeRepeatOne': 'Repeat One',
      'player.playbackModeShuffle': 'Shuffle',
      'player.previous': 'Previous',
      'player.repeatDisabled': 'Repeat: Disabled',
      'player.repeatEnabled': 'Repeat: Enabled',
      'player.repeatOneDisabled': 'Repeat One: Disabled',
      'player.repeatOneEnabled': 'Repeat One: Enabled',
      'player.shuffleDisabled': 'Shuffle: Disabled',
      'player.shuffleEnabled': 'Shuffle: Enabled',
      'player.unlike': 'Remove from My Favorites',
      'player.unmute': 'Unmute',
      'playlists.newPlaylist': 'New Playlist',
      'preferences.level.dislike': 'Dislike',
      'preferences.level.do-not-appear': 'Do not appear',
      'preferences.level.high': 'High',
      'preferences.level.higher': 'Higher',
      'preferences.level.normal': 'Normal',
      'preferences.level.very-high': 'Very High',
      'preferences.undoPrefer': 'Undo Preference',
      'settings.preferenceSettings': 'Preference Settings',
    },
  );

  test('clampVolumeValue mirrors Electron volume bounds', () {
    expect(clampVolumeValue(-12), 0);
    expect(clampVolumeValue(42.4), 42);
    expect(clampVolumeValue(42.6), 43);
    expect(clampVolumeValue(150), 100);
  });

  testWidgets('VolumeSlider shows transient Electron-style value tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              child: VolumeSlider(
                value: 37,
                disabled: false,
                showTooltipOnMount: true,
                onChange: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('VolumeSlider.Tooltip')), findsOneWidget);
    expect(find.text('37'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 901));

    expect(find.byKey(const ValueKey('VolumeSlider.Tooltip')), findsNothing);
  });

  testWidgets('VolumeSlider rounds and de-dupes live changes', (tester) async {
    final changes = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              child: VolumeSlider(
                value: 20,
                disabled: false,
                onChange: changes.add,
              ),
            ),
          ),
        ),
      ),
    );

    var slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(72.3);
    await tester.pump();
    slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(72.4);
    await tester.pump();
    slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(73.0);
    await tester.pump();

    expect(changes, [72, 73]);
  });

  testWidgets(
    'MediaControl renders Electron player actions and updates state',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 120);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = MediaControlController(
        const MediaControlState(
          track: MediaControlTrack(
            id: 1,
            title: 'Song',
            artist: 'Artist',
            artworkUrl: '',
            isLoading: false,
            favorite: false,
          ),
          disabled: false,
          isPlaying: false,
          volume: 50,
          isMuted: false,
          mode: PlaybackMode.once,
          progressSeconds: 0,
          durationSeconds: 180,
          isProgressSeeking: false,
        ),
      );

      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            home: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final state = controller.state;
                  return MediaControl(
                    track: state.track,
                    disabled: state.disabled,
                    isPlaying: state.isPlaying,
                    volume: state.volume,
                    isMuted: state.isMuted,
                    mode: state.mode,
                    progressSeconds: state.progressSeconds,
                    durationSeconds: state.durationSeconds,
                    playbackNoticeKey: state.playbackNoticeKey,
                    onTogglePlayPause: controller.onTogglePlayPause,
                    onPrevious: controller.onPrevious,
                    onNext: controller.onNext,
                    onSeek: controller.onSeek,
                    onBeginSeek: controller.onBeginSeek,
                    onEndSeek: controller.onEndSeek,
                    onVolumeChange: controller.onVolumeChange,
                    onToggleMute: controller.onToggleMute,
                    onToggleShuffle: controller.onToggleShuffle,
                    onToggleRepeat: controller.onToggleRepeat,
                    onToggleRepeatOne: controller.onToggleRepeatOne,
                    onToggleFavorite: controller.onToggleFavorite,
                    onQuickPlay: () {},
                    onOpenNowPlaying: () {},
                    onToggleWindowFullScreen: () {},
                    isWindowFullScreen: false,
                    onEnterMiniMode: () {},
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Song'), findsOneWidget);
      expect(find.text('Artist'), findsOneWidget);
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('3:00'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(const ValueKey('MediaControl.PlayPauseButton')),
      );
      await tester.pump();
      expect(controller.state.isPlaying, isTrue);

      await tester.tap(find.byKey(const ValueKey('MediaControl.NextButton')));
      await tester.pump();
      expect(controller.state.progressSeconds, 0);
    },
  );

  testWidgets(
    'MediaControl renders playback load failure without file details',
    (tester) async {
      await tester.pumpWidget(
        SmPlayerI18nScope(
          i18n: i18n,
          child: MaterialApp(
            home: Scaffold(
              body: MediaControl(
                track: const MediaControlTrack(
                  id: 1,
                  title: 'Song',
                  artist: 'Artist',
                  artworkUrl: '',
                  isLoading: false,
                ),
                disabled: false,
                isPlaying: false,
                volume: 50,
                isMuted: false,
                mode: PlaybackMode.once,
                progressSeconds: 0,
                durationSeconds: 180,
                playbackNoticeKey: 'player.playbackLoadFailed',
                onTogglePlayPause: () {},
                onPrevious: () {},
                onNext: () {},
                onSeek: (_) {},
                onBeginSeek: () {},
                onEndSeek: () {},
                onVolumeChange: (_) {},
                onToggleMute: () {},
                onToggleShuffle: () {},
                onToggleRepeat: () {},
                onToggleRepeatOne: () {},
                onToggleFavorite: () {},
                onQuickPlay: () {},
                onOpenNowPlaying: () {},
                onToggleWindowFullScreen: () {},
                isWindowFullScreen: false,
                onEnterMiniMode: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Could not play this song.'), findsOneWidget);
      expect(find.textContaining('/'), findsNothing);
    },
  );

  testWidgets('MediaControl More menu mirrors Electron player flyout', (
    tester,
  ) async {
    var miniModeEntered = false;
    final controller = MediaControlController(
      const MediaControlState(
        track: MediaControlTrack(
          id: 1,
          title: 'Song',
          artist: 'Artist',
          artworkUrl: '',
          isLoading: false,
          favorite: false,
        ),
        disabled: false,
        isPlaying: false,
        volume: 50,
        isMuted: false,
        mode: PlaybackMode.once,
        progressSeconds: 0,
        durationSeconds: 180,
        isProgressSeeking: false,
      ),
    );

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: MediaControl(
              track: controller.state.track,
              disabled: controller.state.disabled,
              isPlaying: controller.state.isPlaying,
              volume: controller.state.volume,
              isMuted: controller.state.isMuted,
              mode: controller.state.mode,
              progressSeconds: controller.state.progressSeconds,
              durationSeconds: controller.state.durationSeconds,
              onTogglePlayPause: controller.onTogglePlayPause,
              onPrevious: controller.onPrevious,
              onNext: controller.onNext,
              onSeek: controller.onSeek,
              onBeginSeek: controller.onBeginSeek,
              onEndSeek: controller.onEndSeek,
              onVolumeChange: controller.onVolumeChange,
              onToggleMute: controller.onToggleMute,
              onToggleShuffle: controller.onToggleShuffle,
              onToggleRepeat: controller.onToggleRepeat,
              onToggleRepeatOne: controller.onToggleRepeatOne,
              onToggleFavorite: controller.onToggleFavorite,
              onQuickPlay: () {},
              onOpenNowPlaying: () {},
              onToggleWindowFullScreen: () {},
              isWindowFullScreen: false,
              onEnterMiniMode: () {
                miniModeEntered = true;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('More').last);
    await tester.pumpAndSettle();

    expect(find.text('Quick Play'), findsOneWidget);
    expect(find.text('Playback Mode: List'), findsOneWidget);
    expect(find.text('See Album'), findsOneWidget);
    expect(find.text('See Lyrics'), findsOneWidget);
    expect(find.text('Enter Mini Mode'), findsOneWidget);

    await tester.tap(find.text('Enter Mini Mode'));
    await tester.pump();

    expect(miniModeEntered, isTrue);
  });

  testWidgets('MediaControl More menu exposes current song actions', (
    tester,
  ) async {
    int? addedPlaylistId;
    var favoriteToggled = false;
    var localOpened = false;

    await tester.pumpWidget(
      SmPlayerI18nScope(
        i18n: i18n,
        child: MaterialApp(
          home: Scaffold(
            body: MediaControl(
              track: const MediaControlTrack(
                id: 1,
                title: 'Song',
                artist: 'Artist',
                artworkUrl: '',
                isLoading: false,
                favorite: false,
              ),
              currentSong: _song,
              playlists: const [
                LibraryPlaylist(
                  id: 3,
                  name: 'Built in',
                  priority: 0,
                  songCount: 0,
                  songIds: [],
                  sortCriterion: PlaylistSortCriterion.title,
                  isBuiltIn: true,
                ),
                LibraryPlaylist(
                  id: 10,
                  name: 'Mix',
                  priority: 1,
                  songCount: 0,
                  songIds: [],
                  sortCriterion: PlaylistSortCriterion.title,
                  isBuiltIn: false,
                ),
              ],
              disabled: false,
              isPlaying: false,
              volume: 50,
              isMuted: false,
              mode: PlaybackMode.once,
              progressSeconds: 0,
              durationSeconds: 180,
              onTogglePlayPause: () {},
              onPrevious: () {},
              onNext: () {},
              onSeek: (_) {},
              onBeginSeek: () {},
              onEndSeek: () {},
              onVolumeChange: (_) {},
              onToggleMute: () {},
              onToggleShuffle: () {},
              onToggleRepeat: () {},
              onToggleRepeatOne: () {},
              onToggleFavorite: () {
                favoriteToggled = true;
              },
              onQuickPlay: () {},
              onOpenNowPlaying: () {},
              onToggleWindowFullScreen: () {},
              isWindowFullScreen: false,
              onEnterMiniMode: () {},
              onAddToPlaylist: (playlistId) {
                addedPlaylistId = playlistId;
              },
              onCreatePlaylist: () {},
              onSetPreference: (level) {},
              onSeeLocal: () {
                localOpened = true;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('More').last);
    await tester.pumpAndSettle();

    expect(find.text('Add To'), findsOneWidget);
    expect(find.text('Preference Settings'), findsOneWidget);
    expect(find.text('See Local File'), findsOneWidget);
    expect(find.text('Built in'), findsNothing);

    await tester.tap(find.text('Add To'));
    await tester.pumpAndSettle();
    expect(find.text('My Favorites'), findsOneWidget);
    expect(find.text('New Playlist'), findsOneWidget);
    expect(find.text('Mix'), findsOneWidget);

    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();
    expect(addedPlaylistId, 10);

    await tester.tap(find.byTooltip('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('See Local File'));
    expect(localOpened, isTrue);

    expect(favoriteToggled, isFalse);
  });
}

const _song = LibrarySong(
  id: 1,
  path: r'C:\Music\song.mp3',
  title: 'Song',
  artist: 'Artist',
  artists: ['Artist'],
  album: 'Album',
  duration: 180,
  playCount: 0,
  lyricsOffsetMs: 0,
  dateAdded: '2026-05-20T00:00:00',
  favorite: false,
  thumbnailPath: '',
);
