part of 'media_control.dart';

class _CompactMediaControlLayout extends StatelessWidget {
  const _CompactMediaControlLayout({
    this.leading,
    this.onMoreClick,
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
    this.playButtonDisabled,
    this.playButtonTooltip,
    this.onPlayButtonPressed,
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
    this.onToggleWindowFullScreen,
    required this.isWindowFullScreen,
    this.onEnterMiniMode,
    this.onOpenVoiceAssistant,
    this.playbackNoticeKey,
    this.currentLyricsLine,
    this.currentSong,
    this.nowPlayingSongIds = const [],
    this.randomPlaySubmenu,
    this.randomPlayDisabled = false,
    this.onPlayArtist,
    this.onPlayAlbum,
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

  final Widget? leading;
  final ValueChanged<BuildContext>? onMoreClick;
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
  final bool? playButtonDisabled;
  final String? playButtonTooltip;
  final VoidCallback onTogglePlayPause;
  final VoidCallback? onPlayButtonPressed;
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
  final VoidCallback? onToggleWindowFullScreen;
  final bool isWindowFullScreen;
  final VoidCallback? onEnterMiniMode;
  final VoidCallback? onOpenVoiceAssistant;
  final String? playbackNoticeKey;
  final String? currentLyricsLine;
  final LibrarySong? currentSong;
  final List<int> nowPlayingSongIds;
  final List<MenuFlyoutItem>? randomPlaySubmenu;
  final bool randomPlayDisabled;
  final VoidCallback? onPlayArtist;
  final VoidCallback? onPlayAlbum;
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
    final utilityButtonCount = 2 + (onOpenVoiceAssistant == null ? 0 : 1);
    final compactUtility = narrow || utilityButtonCount >= 3;
    final utilitySize = compactUtility ? 34.0 : 36.0;
    final utilityPadding = compactUtility ? 5.0 : 6.0;
    final utilityIconSize = utilitySize - utilityPadding * 2;
    const utilityGap = 6.0;
    const utilityControlOuterSlack = 4.0;
    final resolvedPlayButtonDisabled = playButtonDisabled ?? disabled;
    final playButtonTitle =
        playButtonTooltip ??
        (isPlaying ? i18n.t('player.pause') : i18n.t('player.play'));
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
          showDisabledSurface: false,
          onPressed: onPrevious,
          onLongPress: previousButtonRestartsTrack ? onForcePrevious : null,
        ),
        const SizedBox(width: 16),
        _PlayerIconButton(
          key: const ValueKey('MediaControl.PlayPauseButton'),
          tooltip: playButtonTitle,
          icon: isPlaying ? _pauseIcon : _playIcon,
          primary: true,
          buttonSize: primarySize,
          padding: primaryPadding,
          iconSize: primaryIconSize,
          loading: track.isLoading,
          disabled: resolvedPlayButtonDisabled,
          onPressed: onPlayButtonPressed ?? onTogglePlayPause,
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
          showDisabledSurface: false,
          onPressed: onNext,
        ),
      ],
    );

    final utilityControls = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Builder(
          builder: (modeButtonContext) {
            return Padding(
              padding: EdgeInsets.only(right: utilityGap),
              child: _PlayerIconButton(
                key: const ValueKey('MediaControl.CompactModeButton'),
                tooltip:
                    '${i18n.t('player.playbackMode')}: ${_playbackModeName(i18n, mode)}',
                icon: _playbackModeIcon(mode),
                disabled: false,
                buttonSize: utilitySize,
                padding: utilityPadding,
                iconSize: utilityIconSize,
                showLongPressProgress: false,
                holdDuration: const Duration(milliseconds: 520),
                onPressed: () {
                  _cyclePlaybackMode(
                    mode: mode,
                    onToggleShuffle: onToggleShuffle,
                    onToggleRepeat: onToggleRepeat,
                    onToggleRepeatOne: onToggleRepeatOne,
                  );
                },
                onLongPress: () {
                  _showPlaybackModeMenu(
                    modeButtonContext,
                    i18n: i18n,
                    mode: mode,
                    onToggleShuffle: onToggleShuffle,
                    onToggleRepeat: onToggleRepeat,
                    onToggleRepeatOne: onToggleRepeatOne,
                  );
                },
                onSecondaryTap: () {
                  _showPlaybackModeMenu(
                    modeButtonContext,
                    i18n: i18n,
                    mode: mode,
                    onToggleShuffle: onToggleShuffle,
                    onToggleRepeat: onToggleRepeat,
                    onToggleRepeatOne: onToggleRepeatOne,
                  );
                },
              ),
            );
          },
        ),
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
              disabled: false,
              buttonSize: utilitySize,
              padding: utilityPadding,
              iconSize: utilityIconSize,
              onPressed: () {
                if (onMoreClick case final callback?) {
                  callback(moreButtonContext);
                  return;
                }
                _showCompactMoreMenu(
                  moreButtonContext,
                  i18n: i18n,
                  isMuted: isMuted,
                  volumeValue: volume,
                  desktopLyricsEnabled: desktopLyricsEnabled,
                  onToggleDesktopLyrics: onToggleDesktopLyrics,
                  onQuickPlay: onQuickPlay,
                  randomPlaySubmenu: randomPlaySubmenu,
                  randomPlayDisabled: randomPlayDisabled,
                  onPlayArtist: onPlayArtist,
                  onPlayAlbum: onPlayAlbum,
                  onToggleMute: onToggleMute,
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
              final transportWidth = narrow ? 160.0 : 192.0;
              final transportOpticalOffset = narrow ? 6.0 : 10.0;
              final leadingWidth =
                  (constraints.maxWidth - transportWidth) / 2 +
                  transportOpticalOffset;

              return Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Transform.translate(
                      offset: Offset(transportOpticalOffset, 0),
                      child: SizedBox(
                        width: transportWidth,
                        child: transportControls,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: leadingWidth,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child:
                            leading ??
                            MediaControlTrackInfo(
                              track: track,
                              artworkPath: resolvePlayerArtworkPath(
                                track,
                                currentSong,
                              ),
                              currentLyricsLine: currentLyricsLine,
                              onArtworkError: onArtworkError,
                              disabled: track.id == null,
                              compact: true,
                              onPressed: onOpenNowPlaying,
                            ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: utilityWidth,
                      child: utilityControls,
                    ),
                  ),
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
    required bool isMuted,
    required int volumeValue,
    required bool desktopLyricsEnabled,
    VoidCallback? onToggleDesktopLyrics,
    required VoidCallback onQuickPlay,
    List<MenuFlyoutItem>? randomPlaySubmenu,
    required bool randomPlayDisabled,
    VoidCallback? onPlayArtist,
    VoidCallback? onPlayAlbum,
    required VoidCallback onToggleMute,
    VoidCallback? onToggleWindowFullScreen,
    required bool isWindowFullScreen,
    VoidCallback? onEnterMiniMode,
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
    await showMediaControlMoreMenu(
      context: context,
      i18n: i18n,
      isMuted: isMuted,
      volumeValue: volumeValue,
      desktopLyricsEnabled: desktopLyricsEnabled,
      onToggleDesktopLyrics: onToggleDesktopLyrics,
      onQuickPlay: onQuickPlay,
      alwaysShowQuickPlay: true,
      randomPlaySubmenu: randomPlaySubmenu,
      randomPlayDisabled: randomPlayDisabled,
      onVolumeChange: onVolumeChange,
      onToggleMute: onToggleMute,
      onToggleFavorite: onToggleFavorite,
      onToggleWindowFullScreen: onToggleWindowFullScreen,
      isWindowFullScreen: isWindowFullScreen,
      onEnterMiniMode: onEnterMiniMode,
      showFavoriteWhenUnavailable: true,
      isCompact: true,
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
      onPlayArtist: onPlayArtist,
      onPlayAlbum: onPlayAlbum,
      onSeeArtist: onSeeArtist,
      onSeeAlbum: onSeeAlbum,
      onSeeMusicInfo: onSeeMusicInfo,
      onSeeLyrics: onSeeLyrics,
      onSeeAlbumArt: onSeeAlbumArt,
      onSeeLocal: onSeeLocal,
    );
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
    anchorPlacement: MenuFlyoutAnchorPlacement.above,
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
    final sliderColors = MediaControlSliderColors.forBrightness(
      Theme.of(context).brightness,
    );
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
                      activeTrackColor: sliderColors.progressActive,
                      inactiveTrackColor: sliderColors.progressInactive,
                      thumbColor: sliderColors.progressThumb,
                      thumbShadow: sliderColors.progressThumbShadow,
                      overlayColor: Colors.transparent,
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
