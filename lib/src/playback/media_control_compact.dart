part of 'media_control.dart';

class _CompactMediaControlLayout extends StatelessWidget {
  const _CompactMediaControlLayout({
    required this.narrow,
    required this.track,
    required this.disabled,
    required this.isPlaying,
    required this.volume,
    required this.isMuted,
    required this.mode,
    required this.progressSeconds,
    required this.durationSeconds,
    required this.previousButtonRestartsTrack,
    required this.onTogglePlayPause,
    required this.onPrevious,
    this.onForcePrevious,
    required this.onNext,
    required this.onSeek,
    required this.onBeginSeek,
    required this.onEndSeek,
    required this.onVolumeChange,
    required this.onToggleMute,
    required this.onToggleShuffle,
    required this.onToggleRepeat,
    required this.onToggleRepeatOne,
    required this.onToggleFavorite,
    required this.desktopLyricsEnabled,
    this.onToggleDesktopLyrics,
    required this.onQuickPlay,
    required this.onOpenNowPlaying,
    required this.onToggleWindowFullScreen,
    required this.isWindowFullScreen,
    required this.onEnterMiniMode,
    this.onOpenVoiceAssistant,
    this.playbackNoticeKey,
    this.currentLyricsLine,
    this.currentSong,
    this.nowPlayingSongIds = const [],
    this.onArtworkError,
    this.playlists = const [],
    this.preferenceLevel,
    this.onResolvePreferenceLevel,
    this.onAddToNowPlaying,
    this.onCreatePlaylist,
    this.onAddToPlaylist,
    this.onUndoPreference,
    this.onSetPreference,
    required this.onSeeArtist,
    required this.onSeeAlbum,
    required this.onSeeMusicInfo,
    required this.onSeeLyrics,
    required this.onSeeAlbumArt,
    required this.onSeeLocal,
  });

  final bool narrow;
  final MediaControlTrack track;
  final bool disabled;
  final bool isPlaying;
  final int volume;
  final bool isMuted;
  final PlaybackMode mode;
  final double progressSeconds;
  final double durationSeconds;
  final bool previousButtonRestartsTrack;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onPrevious;
  final VoidCallback? onForcePrevious;
  final VoidCallback onNext;
  final ValueChanged<double> onSeek;
  final VoidCallback onBeginSeek;
  final VoidCallback onEndSeek;
  final ValueChanged<int> onVolumeChange;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleShuffle;
  final VoidCallback onToggleRepeat;
  final VoidCallback onToggleRepeatOne;
  final VoidCallback onToggleFavorite;
  final bool desktopLyricsEnabled;
  final VoidCallback? onToggleDesktopLyrics;
  final VoidCallback onQuickPlay;
  final VoidCallback onOpenNowPlaying;
  final VoidCallback onToggleWindowFullScreen;
  final bool isWindowFullScreen;
  final VoidCallback onEnterMiniMode;
  final VoidCallback? onOpenVoiceAssistant;
  final String? playbackNoticeKey;
  final String? currentLyricsLine;
  final LibrarySong? currentSong;
  final List<int> nowPlayingSongIds;
  final VoidCallback? onArtworkError;
  final List<LibraryPlaylist> playlists;
  final String? preferenceLevel;
  final FutureOr<String?> Function()? onResolvePreferenceLevel;
  final VoidCallback? onAddToNowPlaying;
  final ValueChanged<String>? onCreatePlaylist;
  final ValueChanged<int>? onAddToPlaylist;
  final VoidCallback? onUndoPreference;
  final ValueChanged<String>? onSetPreference;
  final VoidCallback onSeeArtist;
  final VoidCallback onSeeAlbum;
  final VoidCallback onSeeMusicInfo;
  final VoidCallback onSeeLyrics;
  final VoidCallback onSeeAlbumArt;
  final VoidCallback onSeeLocal;

  @override
  Widget build(BuildContext context) {
    final i18n = _mediaControlI18n(context);
    final primarySize = narrow ? 48.0 : 52.0;
    final primaryPadding = narrow ? 12.0 : 13.0;
    final primaryIconSize = primarySize - primaryPadding * 2;
    final utilitySize = narrow ? 34.0 : 36.0;
    final utilityPadding = narrow ? 5.0 : 6.0;
    final utilityIconSize = utilitySize - utilityPadding * 2;
    final utilityGap = narrow ? 2.0 : 6.0;
    const utilityControlOuterSlack = 4.0;
    final utilityButtonCount = 1 + (onOpenVoiceAssistant == null ? 0 : 1);
    final previousTitle =
        previousButtonRestartsTrack
            ? i18n.t('player.restartCurrentTrackHoldPrevious')
            : i18n.t('player.previous');

    final transportControls = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PlayerIconButton(
          key: const ValueKey('MediaControl.PreviousButton'),
          tooltip: previousTitle,
          longPressTooltip: i18n.t('player.forcePrevious'),
          icon: _previousIcon,
          buttonSize: 36,
          padding: 6,
          iconSize: 21,
          disabled: disabled,
          onPressed: onPrevious,
          onLongPress: previousButtonRestartsTrack ? onForcePrevious : null,
        ),
        const SizedBox(width: 16),
        _PlayerIconButton(
          key: const ValueKey('MediaControl.PlayPauseButton'),
          tooltip: isPlaying ? i18n.t('player.pause') : i18n.t('player.play'),
          icon: isPlaying ? _pauseIcon : _playIcon,
          primary: true,
          buttonSize: primarySize,
          padding: primaryPadding,
          iconSize: primaryIconSize,
          loading: track.isLoading,
          disabled: disabled,
          onPressed: onTogglePlayPause,
        ),
        const SizedBox(width: 16),
        _PlayerIconButton(
          key: const ValueKey('MediaControl.NextButton'),
          tooltip: i18n.t('player.next'),
          icon: _nextIcon,
          buttonSize: 36,
          padding: 6,
          iconSize: 21,
          disabled: disabled,
          onPressed: onNext,
        ),
      ],
    );

    final utilityControls = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (onOpenVoiceAssistant != null)
          Padding(
            padding: EdgeInsets.only(right: utilityGap),
            child: _PlayerIconButton(
              tooltip: i18n.t('player.voiceAssistant'),
              icon: _voiceIcon,
              buttonSize: utilitySize,
              padding: utilityPadding,
              iconSize: utilityIconSize,
              disabled: false,
              onPressed: onOpenVoiceAssistant!,
            ),
          ),
        Builder(
          builder: (moreButtonContext) {
            return _PlayerIconButton(
              key: const ValueKey('MediaControl.MoreButton'),
              tooltip: i18n.t('player.more'),
              icon: _moreIcon,
              buttonSize: utilitySize,
              padding: utilityPadding,
              iconSize: utilityIconSize,
              onPressed: () {
                _showCompactMoreMenu(
                  moreButtonContext,
                  i18n: i18n,
                  disabled: disabled,
                  trackId: track.id,
                  mode: mode,
                  isMuted: isMuted,
                  volumeValue: volume,
                  desktopLyricsEnabled: desktopLyricsEnabled,
                  onToggleDesktopLyrics: onToggleDesktopLyrics,
                  onQuickPlay: onQuickPlay,
                  onToggleMute: onToggleMute,
                  onToggleShuffle: onToggleShuffle,
                  onToggleRepeat: onToggleRepeat,
                  onToggleRepeatOne: onToggleRepeatOne,
                  onOpenNowPlaying: onOpenNowPlaying,
                  onToggleWindowFullScreen: onToggleWindowFullScreen,
                  isWindowFullScreen: isWindowFullScreen,
                  onEnterMiniMode: onEnterMiniMode,
                  currentSong: currentSong,
                  nowPlayingSongIds: nowPlayingSongIds,
                  playlists: playlists,
                  preferenceLevel: preferenceLevel,
                  onResolvePreferenceLevel: onResolvePreferenceLevel,
                  onAddToNowPlaying: onAddToNowPlaying,
                  onCreatePlaylist: onCreatePlaylist,
                  onAddToPlaylist: onAddToPlaylist,
                  onUndoPreference: onUndoPreference,
                  onSetPreference: onSetPreference,
                  onSeeArtist: onSeeArtist,
                  onSeeAlbum: onSeeAlbum,
                  onSeeMusicInfo: onSeeMusicInfo,
                  onSeeLyrics: onSeeLyrics,
                  onSeeAlbumArt: onSeeAlbumArt,
                  onSeeLocal: onSeeLocal,
                );
              },
            );
          },
        ),
      ],
    );

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final utilityWidth =
                  utilitySize * utilityButtonCount +
                  utilityGap * (utilityButtonCount - 1) +
                  utilityControlOuterSlack;
              final transportWidth = narrow ? 176.0 : 208.0;

              return Row(
                children: [
                  Expanded(
                    child: _PlayerTrack(
                      track: track,
                      artworkPath: resolvePlayerArtworkPath(track, currentSong),
                      currentLyricsLine: currentLyricsLine,
                      onArtworkError: onArtworkError,
                      disabled: track.id == null,
                      compact: true,
                      onOpenNowPlaying: onOpenNowPlaying,
                    ),
                  ),
                  SizedBox(width: transportWidth, child: transportControls),
                  SizedBox(width: utilityWidth, child: utilityControls),
                ],
              );
            },
          ),
        ),
        _CompactMediaProgressRow(
          isLoading: track.isLoading,
          disabled: disabled,
          progressSeconds: progressSeconds,
          durationSeconds: durationSeconds,
          onSeek: onSeek,
          onBeginSeek: onBeginSeek,
          onEndSeek: onEndSeek,
        ),
      ],
    );
  }

  Future<void> _showCompactMoreMenu(
    BuildContext context, {
    required SmPlayerI18n i18n,
    required bool disabled,
    required int? trackId,
    required PlaybackMode mode,
    required bool isMuted,
    required int volumeValue,
    required bool desktopLyricsEnabled,
    VoidCallback? onToggleDesktopLyrics,
    required VoidCallback onQuickPlay,
    required VoidCallback onToggleMute,
    required VoidCallback onToggleShuffle,
    required VoidCallback onToggleRepeat,
    required VoidCallback onToggleRepeatOne,
    required VoidCallback onOpenNowPlaying,
    required VoidCallback onToggleWindowFullScreen,
    required bool isWindowFullScreen,
    required VoidCallback onEnterMiniMode,
    LibrarySong? currentSong,
    List<int> nowPlayingSongIds = const [],
    List<LibraryPlaylist> playlists = const [],
    String? preferenceLevel,
    FutureOr<String?> Function()? onResolvePreferenceLevel,
    VoidCallback? onAddToNowPlaying,
    ValueChanged<String>? onCreatePlaylist,
    ValueChanged<int>? onAddToPlaylist,
    VoidCallback? onUndoPreference,
    ValueChanged<String>? onSetPreference,
    required VoidCallback onSeeArtist,
    required VoidCallback onSeeAlbum,
    required VoidCallback onSeeMusicInfo,
    required VoidCallback onSeeLyrics,
    required VoidCallback onSeeAlbumArt,
    required VoidCallback onSeeLocal,
  }) async {
    if (!context.mounted) {
      return;
    }
    List<MenuFlyoutItem> buildItems(String? resolvedPreferenceLevel) {
      return _buildPlayerMoreMenuItems(
        i18n: i18n,
        disabled: disabled,
        trackId: trackId,
        mode: mode,
        isMuted: isMuted,
        volumeValue: volumeValue,
        desktopLyricsEnabled: desktopLyricsEnabled,
        onToggleDesktopLyrics: onToggleDesktopLyrics,
        onQuickPlay: onQuickPlay,
        onVolumeChange: onVolumeChange,
        onToggleMute: onToggleMute,
        onToggleShuffle: onToggleShuffle,
        onToggleRepeat: onToggleRepeat,
        onToggleRepeatOne: onToggleRepeatOne,
        onToggleFavorite: onToggleFavorite,
        onOpenNowPlaying: onOpenNowPlaying,
        onToggleWindowFullScreen: onToggleWindowFullScreen,
        isWindowFullScreen: isWindowFullScreen,
        onEnterMiniMode: onEnterMiniMode,
        isCompact: true,
        currentSong: currentSong,
        nowPlayingSongIds: nowPlayingSongIds,
        playlists: playlists,
        preferenceLevel: resolvedPreferenceLevel,
        onAddToNowPlaying: onAddToNowPlaying,
        onCreatePlaylist: onCreatePlaylist,
        onAddToPlaylist: onAddToPlaylist,
        onUndoPreference: onUndoPreference,
        onSetPreference: onSetPreference,
        onSeeArtist: onSeeArtist,
        onSeeAlbum: onSeeAlbum,
        onSeeMusicInfo: onSeeMusicInfo,
        onSeeLyrics: onSeeLyrics,
        onSeeAlbumArt: onSeeAlbumArt,
        onSeeLocal: onSeeLocal,
      );
    }

    final itemsNotifier = ValueNotifier<List<MenuFlyoutItem>>(
      buildItems(preferenceLevel),
    );
    var menuClosed = false;
    if (onResolvePreferenceLevel != null) {
      unawaited(
        Future.sync(onResolvePreferenceLevel).then((resolvedPreferenceLevel) {
          if (!menuClosed) {
            itemsNotifier.value = buildItems(resolvedPreferenceLevel);
          }
        }),
      );
    }
    await showMenuFlyout(
      context,
      position: _menuFlyoutPositionAboveAnchor(context),
      avoidPlayerBar: false,
      items: itemsNotifier.value,
      itemsListenable: itemsNotifier,
    );
    menuClosed = true;
    itemsNotifier.dispose();
  }
}

void _showPlaybackModeMenu(
  BuildContext context, {
  required SmPlayerI18n i18n,
  required PlaybackMode mode,
  required VoidCallback onToggleShuffle,
  required VoidCallback onToggleRepeat,
  required VoidCallback onToggleRepeatOne,
}) {
  showMenuFlyout(
    context,
    position: _menuFlyoutPositionAboveAnchor(context),
    avoidPlayerBar: false,
    items: buildPlaybackModeMenuFlyoutItems(
      i18n: i18n,
      mode: mode,
      onToggleShuffle: onToggleShuffle,
      onToggleRepeat: onToggleRepeat,
      onToggleRepeatOne: onToggleRepeatOne,
    ),
  );
}

Offset _menuFlyoutPositionAboveAnchor(BuildContext context) {
  final box = context.findRenderObject() as RenderBox;
  return box.localToGlobal(const Offset(0, -8));
}

class _CompactMediaProgressRow extends StatefulWidget {
  const _CompactMediaProgressRow({
    required this.isLoading,
    required this.disabled,
    required this.progressSeconds,
    required this.durationSeconds,
    required this.onSeek,
    required this.onBeginSeek,
    required this.onEndSeek,
  });

  final bool isLoading;
  final bool disabled;
  final double progressSeconds;
  final double durationSeconds;
  final ValueChanged<double> onSeek;
  final VoidCallback onBeginSeek;
  final VoidCallback onEndSeek;

  @override
  State<_CompactMediaProgressRow> createState() =>
      _CompactMediaProgressRowState();
}

class _CompactMediaProgressRowState extends State<_CompactMediaProgressRow> {
  var _isProgressSeeking = false;
  var _draftProgressSeconds = 0.0;

  @override
  Widget build(BuildContext context) {
    final progressMax =
        widget.durationSeconds > 0 ? widget.durationSeconds : 0.0;
    final textMuted = MediaControlColors.textMutedFor(context);
    final displayProgressSeconds =
        _isProgressSeeking ? _draftProgressSeconds : widget.progressSeconds;
    final progressValue =
        widget.disabled || progressMax <= 0
            ? 0.0
            : displayProgressSeconds.clamp(0, progressMax).toDouble();

    return SizedBox(
      height: 28,
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              formatDuration(progressValue),
              style: const TextStyle(fontSize: 12).copyWith(color: textMuted),
            ),
          ),
          Expanded(
            child:
                widget.isLoading
                    ? const _MediaProgressLoading()
                    : _MediaProgressSlider(
                      value: progressValue,
                      max: progressMax,
                      disabled: widget.disabled || widget.durationSeconds <= 0,
                      onChanged: (value) {
                        setState(() {
                          _draftProgressSeconds = value;
                        });
                      },
                      onChangeStart: (_) {
                        setState(() {
                          _isProgressSeeking = true;
                          _draftProgressSeconds = progressValue;
                        });
                        widget.onBeginSeek();
                      },
                      onChangeEnd: (value) {
                        if (!_isProgressSeeking) {
                          return;
                        }
                        widget.onSeek(value);
                        widget.onEndSeek();
                        setState(() {
                          _isProgressSeeking = false;
                        });
                      },
                    ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              formatDuration(widget.durationSeconds),
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12).copyWith(color: textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
