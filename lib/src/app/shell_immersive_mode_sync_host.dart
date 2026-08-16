import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/media_control_provider.dart';

typedef ShellImmersiveModeSync =
    void Function({
      required SmPlayerI18n i18n,
      required LibraryContentData? snapshot,
      required List<LibrarySong> recentSongs,
      required MediaControlState mediaControlState,
      required LibrarySong? currentSong,
    });

class ShellImmersiveModeSyncHost extends ConsumerWidget {
  const ShellImmersiveModeSyncHost({
    super.key,
    required this.visible,
    required this.mediaControlController,
    required this.resolvePlayerSong,
    required this.scheduleRestorePlaybackTrack,
    required this.ensurePlayerArtworkResolved,
    required this.syncDesktopFeatures,
  });

  final bool visible;
  final MediaControlController mediaControlController;
  final LibrarySong? Function(
    MediaControlState mediaControlState,
    LibraryContentData? snapshot,
  )
  resolvePlayerSong;
  final void Function(LibraryContentData? snapshot)
  scheduleRestorePlaybackTrack;
  final void Function(LibrarySong? currentSong, WidgetRef ref)
  ensurePlayerArtworkResolved;
  final ShellImmersiveModeSync syncDesktopFeatures;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!visible) {
      return const SizedBox.shrink();
    }
    ref.watch(
      mediaControlControllerProvider.select(
        (controller) => (
          track: controller.state.track,
          selectedQueueIndex: controller.state.selectedQueueIndex,
          isPlaying: controller.state.isPlaying,
          volume: controller.state.volume,
          isMuted: controller.state.isMuted,
          mode: controller.state.mode,
          progressSecond: controller.state.progressSeconds.round(),
          durationSeconds: controller.state.durationSeconds,
          playbackStatus: controller.state.playbackStatus,
        ),
      ),
    );
    final snapshot = ref.watch(libraryContentDataProvider).valueOrNull;
    scheduleRestorePlaybackTrack(snapshot);
    final mediaControlState = mediaControlController.state;
    final currentSong = resolvePlayerSong(mediaControlState, snapshot);
    ensurePlayerArtworkResolved(currentSong, ref);
    final recentSongs =
        ref.watch(recentPageDataProvider).valueOrNull?.recentSongs ??
        const <LibrarySong>[];
    final i18n =
        ref.watch(smPlayerI18nProvider).valueOrNull ??
        const SmPlayerI18n(locale: smPlayerFallbackLocale, messages: {});
    syncDesktopFeatures(
      i18n: i18n,
      snapshot: snapshot,
      recentSongs: recentSongs,
      mediaControlState: mediaControlState,
      currentSong: currentSong,
    );
    return Positioned.fill(
      child: IgnorePointer(child: const SizedBox.shrink()),
    );
  }
}
