import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';

void main() {
  const i18n = SmPlayerI18n(
    locale: 'en-US',
    messages: {
      'common.myFavorites': 'My Favorites',
      'common.nowPlaying': 'Now Playing',
      'context.addToPlaylist': 'Add To',
      'context.seeAlbum': 'See Album',
      'context.seeAlbumArt': 'See Album Art',
      'context.seeArtist': 'See Artist',
      'context.seeLocalFile': 'See Local File',
      'context.seeLyrics': 'See Lyrics',
      'context.seeMusicInfo': 'See Music Info',
      'context.view': 'View',
      'nowPlaying.fullScreen': 'Full Screen',
      'nowPlaying.quickPlay': 'Quick Play',
      'player.enterMiniMode': 'Enter Mini Mode',
      'player.like': 'Add to My Favorites',
      'player.miniMode': 'Mini Mode',
      'player.more': 'More',
      'player.mute': 'Mute',
      'player.next': 'Next',
      'player.pause': 'Pause',
      'player.play': 'Play',
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
      'player.voiceAssistant': 'Voice Assistant',
      'player.volume': 'Volume',
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

  testWidgets('writes MediaControl alignment screenshots', (tester) async {
    await _writeScreenshot(
      tester,
      i18n: i18n,
      size: const Size(1200, 160),
      path: '/tmp/smplayer_media_control_wide_verify.png',
    );
    await _writeScreenshot(
      tester,
      i18n: i18n,
      size: const Size(520, 160),
      path: '/tmp/smplayer_media_control_compact_verify.png',
    );
  });
}

Future<void> _writeScreenshot(
  WidgetTester tester, {
  required SmPlayerI18n i18n,
  required Size size,
  required String path,
}) async {
  final repaintKey = GlobalKey();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    SmPlayerI18nScope(
      i18n: i18n,
      child: MaterialApp(
        home: RepaintBoundary(
          key: repaintKey,
          child: ColoredBox(
            color: const Color(0xff121820),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: size.width,
                height: 120,
                child: MediaControl(
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
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  final boundary =
      repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
}
