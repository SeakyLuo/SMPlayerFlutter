import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/ui/default_album_artwork.dart';
import 'package:smplayer_flutter/src/platform/desktop_feature_service.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(dismissNativeSplash());
  runApp(const _MediaControlVerifyApp());
}

class _MediaControlVerifyApp extends StatelessWidget {
  const _MediaControlVerifyApp();

  static const _i18n = SmPlayerI18n(
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

  @override
  Widget build(BuildContext context) {
    return SmPlayerI18nScope(
      i18n: _i18n,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          extensions: const [DefaultAlbumArtworkThemeColors.dark],
        ),
        home: Scaffold(
          backgroundColor: const Color(0xff111820),
          body: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [
              SizedBox(width: 520, height: 120, child: _Control()),
              SizedBox(height: 20),
              SizedBox(height: 120, child: _Control()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Control extends StatelessWidget {
  const _Control();

  @override
  Widget build(BuildContext context) {
    return MediaControl(
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
    );
  }
}
