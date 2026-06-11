import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smplayer_flutter/src/app/shell_layout_state.dart';
import 'package:smplayer_flutter/src/app/shell_models.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/library/data/library_models.dart';
import 'package:smplayer_flutter/src/library/data/library_providers.dart';
import 'package:smplayer_flutter/src/library/ui/music_dialog.dart';
import 'package:smplayer_flutter/src/playback/media_control.dart';
import 'package:smplayer_flutter/src/playback/media_control_model.dart';
import 'package:smplayer_flutter/src/playback/mini_mode_surface.dart';
import 'package:smplayer_flutter/src/settings/settings_controller.dart';

typedef ShellPlayerDialog = ({LibrarySong song, SongDialogMode mode});

typedef ShellDesktopSync =
    void Function({
      required SmPlayerI18n i18n,
      required LibraryContentData? snapshot,
      required List<RecentLibrarySong> recentSongs,
      required MediaControlState mediaControlState,
      required LibrarySong? currentSong,
    });

class ShellPlayerHost extends StatelessWidget {
  const ShellPlayerHost({
    super.key,
    required this.layout,
    required this.mediaControlController,
    required this.settingsController,
    required this.isWindowFullScreen,
    required this.playerDialogNotifier,
    required this.resolvePlayerSong,
    required this.playbackSongIds,
    required this.isPlaybackQueueEmpty,
    required this.scheduleRestorePlaybackTrack,
    required this.ensurePlayerArtworkResolved,
    required this.syncDesktopFeatures,
    required this.desktopLyricsForSong,
    required this.onTogglePlayPause,
    required this.onPrevious,
    required this.onForcePrevious,
    required this.onNext,
    required this.onToggleShuffle,
    required this.onToggleFavorite,
    required this.onQuickPlay,
    required this.onOpenNowPlaying,
    required this.onArtworkError,
    required this.onToggleWindowFullScreen,
    required this.onEnterMiniMode,
    required this.onOpenVoiceAssistant,
    required this.onAddToNowPlaying,
    required this.onCreatePlaylist,
    required this.onAddToPlaylist,
    required this.onRevealPath,
    required this.onNavigate,
  });

  final ShellLayoutState layout;
  final MediaControlController mediaControlController;
  final SettingsController settingsController;
  final bool isWindowFullScreen;
  final ValueNotifier<ShellPlayerDialog?> playerDialogNotifier;
  final LibrarySong? Function(
    MediaControlState mediaControlState,
    LibraryContentData? snapshot,
  )
  resolvePlayerSong;
  final List<int> Function(LibraryContentData snapshot) playbackSongIds;
  final bool Function(LibraryContentData? snapshot) isPlaybackQueueEmpty;
  final void Function(LibraryContentData? snapshot)
  scheduleRestorePlaybackTrack;
  final void Function(LibrarySong? currentSong, WidgetRef ref)
  ensurePlayerArtworkResolved;
  final ShellDesktopSync syncDesktopFeatures;
  final LyricsSnapshot? Function(LibrarySong? song) desktopLyricsForSong;
  final bool Function() onTogglePlayPause;
  final bool Function({bool forcePrevious}) onPrevious;
  final VoidCallback onForcePrevious;
  final bool Function() onNext;
  final VoidCallback onToggleShuffle;
  final void Function(WidgetRef ref, LibrarySong song) onToggleFavorite;
  final void Function(WidgetRef ref) onQuickPlay;
  final VoidCallback onOpenNowPlaying;
  final void Function(LibrarySong song, WidgetRef ref) onArtworkError;
  final VoidCallback onToggleWindowFullScreen;
  final VoidCallback onEnterMiniMode;
  final void Function(LibraryContentData? snapshot, SmPlayerI18n i18n)?
  onOpenVoiceAssistant;
  final void Function(WidgetRef ref, LibrarySong song) onAddToNowPlaying;
  final void Function(WidgetRef ref, LibrarySong song, String name)
  onCreatePlaylist;
  final void Function(WidgetRef ref, LibrarySong song, int playlistId)
  onAddToPlaylist;
  final ValueChanged<String> onRevealPath;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    if (layout.isImmersiveModeRoute) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: SmPlayerShellMetrics.playerHeight,
      child: SizedBox.expand(
        key: SmPlayerShellKeys.reservedPlayer,
        child: AnimatedBuilder(
          animation: mediaControlController,
          builder: (context, _) {
            final mediaControlState = mediaControlController.state;
            return Consumer(
              builder: (context, ref, _) {
                final snapshot =
                    ref.watch(libraryContentDataProvider).valueOrNull;
                scheduleRestorePlaybackTrack(snapshot);
                final currentSong = resolvePlayerSong(
                  mediaControlState,
                  snapshot,
                );
                final playbackIds =
                    snapshot == null
                        ? const <int>[]
                        : playbackSongIds(snapshot);
                final previousButtonRestartsTrack =
                    playbackIds.isNotEmpty &&
                    shouldRestartCurrentTrackForPrevious(
                      progressSeconds: mediaControlState.progressSeconds,
                      queueLength: playbackIds.length,
                      restartAfterThresholdEnabled:
                          settingsController
                              .snapshot
                              .previousButtonRestartsTrack,
                    );
                ensurePlayerArtworkResolved(currentSong, ref);
                final i18n =
                    ref.watch(smPlayerI18nProvider).valueOrNull ??
                    const SmPlayerI18n(
                      locale: smPlayerFallbackLocale,
                      messages: {},
                    );
                final recentSongs =
                    ref
                        .watch(recentPageDataProvider)
                        .valueOrNull
                        ?.recentSongs ??
                    const <RecentLibrarySong>[];
                syncDesktopFeatures(
                  i18n: i18n,
                  snapshot: snapshot,
                  recentSongs: recentSongs,
                  mediaControlState: mediaControlState,
                  currentSong: currentSong,
                );
                final playerLyricsLine = resolvePlayerLyricLine(
                  lyrics: desktopLyricsForSong(currentSong),
                  song: currentSong,
                  progressSeconds: mediaControlState.progressSeconds,
                  durationSeconds: mediaControlState.durationSeconds,
                );
                return MediaControl(
                  track: mediaControlState.track,
                  currentSong: currentSong,
                  playlists: snapshot?.playlists ?? const [],
                  disabled: isPlaybackQueueEmpty(snapshot),
                  isPlaying: mediaControlState.isPlaying,
                  volume: mediaControlState.volume,
                  isMuted: mediaControlState.isMuted,
                  mode: mediaControlState.mode,
                  progressSeconds: mediaControlState.progressSeconds,
                  durationSeconds: mediaControlState.durationSeconds,
                  previousButtonRestartsTrack: previousButtonRestartsTrack,
                  playbackNoticeKey: mediaControlState.playbackNoticeKey,
                  currentLyricsLine: playerLyricsLine,
                  onTogglePlayPause: onTogglePlayPause,
                  onPrevious: onPrevious,
                  onForcePrevious: onForcePrevious,
                  onNext: onNext,
                  onSeek: mediaControlController.onSeek,
                  onBeginSeek: mediaControlController.onBeginSeek,
                  onEndSeek: mediaControlController.onEndSeek,
                  onVolumeChange: mediaControlController.onVolumeChange,
                  onToggleMute: mediaControlController.onToggleMute,
                  onToggleShuffle: onToggleShuffle,
                  onToggleRepeat: mediaControlController.onToggleRepeat,
                  onToggleRepeatOne: mediaControlController.onToggleRepeatOne,
                  onToggleFavorite:
                      currentSong == null
                          ? mediaControlController.onToggleFavorite
                          : () {
                            onToggleFavorite(ref, currentSong);
                          },
                  onQuickPlay: () {
                    onQuickPlay(ref);
                  },
                  onOpenNowPlaying: onOpenNowPlaying,
                  onArtworkError:
                      currentSong == null
                          ? null
                          : () {
                            onArtworkError(currentSong, ref);
                          },
                  onToggleWindowFullScreen: onToggleWindowFullScreen,
                  isWindowFullScreen: isWindowFullScreen,
                  onEnterMiniMode: onEnterMiniMode,
                  onOpenVoiceAssistant:
                      onOpenVoiceAssistant == null
                          ? null
                          : () {
                            onOpenVoiceAssistant!(snapshot, i18n);
                          },
                  onAddToNowPlaying:
                      currentSong == null
                          ? null
                          : () {
                            onAddToNowPlaying(ref, currentSong);
                          },
                  onCreatePlaylist:
                      currentSong == null
                          ? null
                          : (name) {
                            onCreatePlaylist(ref, currentSong, name);
                          },
                  onAddToPlaylist:
                      currentSong == null
                          ? null
                          : (playlistId) {
                            onAddToPlaylist(ref, currentSong, playlistId);
                          },
                  onResolvePreferenceLevel:
                      currentSong == null
                          ? null
                          : () {
                            return ref
                                .read(libraryRepositoryProvider)
                                .getPreferenceLevel(
                                  'song',
                                  '${currentSong.id}',
                                );
                          },
                  onUndoPreference:
                      currentSong == null
                          ? null
                          : () {
                            unawaited(
                              ref
                                  .read(libraryRepositoryProvider)
                                  .removePreferenceItem(
                                    'song',
                                    '${currentSong.id}',
                                  ),
                            );
                          },
                  onSetPreference:
                      currentSong == null
                          ? null
                          : (level) {
                            unawaited(
                              ref
                                  .read(libraryRepositoryProvider)
                                  .addPreferenceItem(
                                    'song',
                                    '${currentSong.id}',
                                    currentSong.title,
                                    level,
                                  ),
                            );
                          },
                  onSeeArtist:
                      currentSong == null
                          ? null
                          : () {
                            final artist = resolvePlayerArtistRouteName(
                              currentSong,
                              context.smPlayerI18n,
                            );
                            onNavigate(
                              '/artists?artist=${Uri.encodeQueryComponent(artist)}',
                            );
                          },
                  onSeeAlbum:
                      currentSong == null
                          ? null
                          : () {
                            final album =
                                currentSong.album.isEmpty
                                    ? context.smPlayerI18n.t(
                                      'common.albumUnknown',
                                    )
                                    : currentSong.album;
                            onNavigate(
                              '/albums?album=${Uri.encodeQueryComponent(album)}',
                            );
                          },
                  onSeeMusicInfo:
                      currentSong == null
                          ? null
                          : () {
                            playerDialogNotifier.value = (
                              song: currentSong,
                              mode: SongDialogMode.properties,
                            );
                          },
                  onSeeLyrics:
                      currentSong == null
                          ? null
                          : () {
                            playerDialogNotifier.value = (
                              song: currentSong,
                              mode: SongDialogMode.lyrics,
                            );
                          },
                  onSeeAlbumArt:
                      currentSong == null
                          ? null
                          : () {
                            playerDialogNotifier.value = (
                              song: currentSong,
                              mode: SongDialogMode.albumArt,
                            );
                          },
                  onSeeLocal:
                      currentSong == null
                          ? null
                          : () {
                            onRevealPath(currentSong.path);
                          },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
