import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/smplayer_vector_icons.dart';
import 'package:smplayer_flutter/src/i18n/app_i18n.dart';
import 'package:smplayer_flutter/src/playback/playing_wave.dart';
import 'package:smplayer_flutter/src/settings/artist_split_review_panel.dart';

import '../data/library_models.dart';
import 'artwork_floating_action_button.dart';
import 'default_album_artwork.dart';
import 'folder_update_result_file_title.dart';
import 'local_folder_model.dart';
import 'popup_dialog.dart';
import 'song_artwork.dart';

const _folderUpdateResultRowHeight = 66.0;
const _folderUpdateResultMaxVisibleRows = 14;

class FolderUpdateResultFileSection extends StatelessWidget {
  const FolderUpdateResultFileSection({
    super.key,
    required this.folderPath,
    required this.paths,
    required this.playable,
    required this.songsByPathKey,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.onPlay,
    required this.onOpenSongMenu,
    required this.maxHeight,
  });

  final String folderPath;
  final List<String> paths;
  final bool playable;
  final Map<String, LibrarySong> songsByPathKey;
  final int? selectedTrackId;
  final bool isPlaying;
  final ValueChanged<int> onPlay;
  final FutureOr<void> Function(LibrarySong song, Offset position)
  onOpenSongMenu;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) {
      return const SizedBox.shrink();
    }

    final items = getUpdateResultFileItems(paths, folderPath);
    final visibleRows =
        items.length > _folderUpdateResultMaxVisibleRows
            ? _folderUpdateResultMaxVisibleRows
            : items.length;
    final desiredHeight = visibleRows * _folderUpdateResultRowHeight;
    final listHeight = desiredHeight > maxHeight ? maxHeight : desiredHeight;
    final colors = _FolderUpdateResultColors.resolve(context);
    return SizedBox(
      height: listHeight,
      child: Container(
        decoration: BoxDecoration(
          color: colors.listBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemExtent: _folderUpdateResultRowHeight,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final path = item.path;
            final title = item.title;
            final showsFullPath = title == path;
            final song =
                playable
                    ? songsByPathKey[normalizePath(path).toLowerCase()]
                    : null;
            final current = song != null && song.id == selectedTrackId;
            return _FolderUpdateResultRow(
              title: title,
              fullPath: showsFullPath,
              first: index == 0,
              odd: index.isEven,
              song: song,
              current: current,
              isPlaying: current && isPlaying,
              onPlay: song == null ? null : () => onPlay(song.id),
              onOpenSongMenu:
                  song == null
                      ? null
                      : (position) => onOpenSongMenu(song, position),
            );
          },
        ),
      ),
    );
  }
}

class FolderUpdateResultArtwork extends StatefulWidget {
  const FolderUpdateResultArtwork({
    super.key,
    required this.song,
    required this.current,
    required this.isPlaying,
    required this.onPlay,
    required this.hovered,
  });

  final LibrarySong song;
  final bool current;
  final bool isPlaying;
  final VoidCallback onPlay;
  final bool hovered;

  @override
  State<FolderUpdateResultArtwork> createState() =>
      _FolderUpdateResultArtworkState();
}

class _FolderUpdateResultArtworkState extends State<FolderUpdateResultArtwork> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final showPlayOverlay = widget.hovered || _hovered || _focused;
    return SizedBox(
      width: 42,
      height: 42,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SongArtwork(
                artworkPath: widget.song.thumbnailPath,
                fallback: const DefaultAlbumArtwork(logoOpacity: 0.9),
              ),
            ),
            if (widget.current && !showPlayOverlay)
              SmPlayerPlayingWaveGlass(
                playing: widget.isPlaying,
                keyPrefix: 'FolderUpdateResult.Playing.${widget.song.id}',
              ),
            IgnorePointer(
              ignoring: !showPlayOverlay,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: showPlayOverlay ? 1 : 0,
                child: Focus(
                  onFocusChange:
                      (focused) => setState(() => _focused = focused),
                  child: ArtworkFloatingActionButton(
                    tooltip:
                        widget.isPlaying
                            ? context.smPlayerI18n.t('player.pause')
                            : context.smPlayerI18n.t('context.play'),
                    size: 34,
                    iconSize: 16,
                    icon:
                        widget.isPlaying
                            ? const SmPlayerPauseIcon(
                              size: 16,
                              color: Colors.white,
                            )
                            : const SmPlayerPlayIcon(
                              size: 16,
                              color: Colors.white,
                            ),
                    onPressed: widget.onPlay,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderUpdateResultRow extends StatefulWidget {
  const _FolderUpdateResultRow({
    required this.title,
    required this.fullPath,
    required this.first,
    required this.odd,
    required this.song,
    required this.current,
    required this.isPlaying,
    required this.onPlay,
    required this.onOpenSongMenu,
  });

  final String title;
  final bool fullPath;
  final bool first;
  final bool odd;
  final LibrarySong? song;
  final bool current;
  final bool isPlaying;
  final VoidCallback? onPlay;
  final FutureOr<void> Function(Offset)? onOpenSongMenu;

  @override
  State<_FolderUpdateResultRow> createState() => _FolderUpdateResultRowState();
}

class _FolderUpdateResultRowState extends State<_FolderUpdateResultRow> {
  var _hovered = false;
  var _contextMenuOpen = false;

  Future<void> _openContextMenu(Offset position) async {
    setState(() {
      _contextMenuOpen = true;
    });
    try {
      await widget.onOpenSongMenu!(position);
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _contextMenuOpen = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _FolderUpdateResultColors.resolve(context);
    final playable = widget.song != null;
    final background = colors.rowBackground(
      playable: playable,
      odd: widget.odd,
    );
    final rowColor =
        (_hovered || _contextMenuOpen) && playable
            ? colors.rowHover
            : background;

    return MouseRegion(
      cursor: playable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown:
            playable
                ? (details) =>
                    unawaited(_openContextMenu(details.globalPosition))
                : null,
        child: Container(
          decoration: BoxDecoration(
            color: rowColor,
            border:
                widget.first
                    ? null
                    : Border(top: BorderSide(color: colors.rowBorder)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              if (playable) ...[
                FolderUpdateResultArtwork(
                  song: widget.song!,
                  current: widget.current,
                  isPlaying: widget.isPlaying,
                  onPlay: widget.onPlay!,
                  hovered: _hovered,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: widget.fullPath ? 2 : 1,
                  overflow:
                      widget.fullPath
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                  style: TextStyle(
                    color: playable ? colors.textStrong : colors.textMuted,
                    fontSize: widget.fullPath ? 13 : 16,
                    fontWeight: FontWeight.w500,
                    height: widget.fullPath ? 1.25 : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderUpdateResultColors {
  const _FolderUpdateResultColors({
    required this.listBackground,
    required this.border,
    required this.rowBorder,
    required this.rowEven,
    required this.rowOdd,
    required this.playableRow,
    required this.rowHover,
    required this.textStrong,
    required this.textMuted,
  });

  final Color listBackground;
  final Color border;
  final Color rowBorder;
  final Color rowEven;
  final Color rowOdd;
  final Color playableRow;
  final Color rowHover;
  final Color textStrong;
  final Color textMuted;

  Color rowBackground({required bool playable, required bool odd}) {
    if (playable && _isLight) {
      return playableRow;
    }
    return odd ? rowOdd : rowEven;
  }

  bool get _isLight => playableRow == const Color(0xb8ffffff);

  static _FolderUpdateResultColors resolve(BuildContext context) {
    final popupColors = PopupDialogColors.resolve(context);
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    if (nightMode) {
      return _FolderUpdateResultColors(
        listBackground: Colors.white.withValues(alpha: 0.035),
        border: popupColors.border,
        rowBorder: popupColors.border,
        rowEven: Colors.white.withValues(alpha: 0.035),
        rowOdd: Colors.white.withValues(alpha: 0.055),
        playableRow: Colors.white.withValues(alpha: 0.035),
        rowHover: popupColors.accent.withValues(alpha: 0.20),
        textStrong: popupColors.textStrong,
        textMuted: popupColors.textMuted,
      );
    }

    return _FolderUpdateResultColors(
      listBackground: const Color(0xb8ffffff),
      border: const Color(0x9ebec8d6),
      rowBorder: const Color(0x85bec8d6),
      rowEven: const Color(0xb8ffffff),
      rowOdd: const Color(0xd1f6f9fd),
      playableRow: const Color(0xb8ffffff),
      rowHover: popupColors.accent.withValues(alpha: 0.10),
      textStrong: popupColors.textStrong,
      textMuted: popupColors.textMuted,
    );
  }
}

class FolderUpdateResultArtistSection extends StatelessWidget {
  const FolderUpdateResultArtistSection({
    super.key,
    required this.result,
    required this.applying,
    required this.artworkPathBySongId,
    required this.onApply,
    required this.onClose,
  });

  final LocalFolderRefreshResult result;
  final bool applying;
  final Map<int, String> artworkPathBySongId;
  final FutureOr<void> Function(List<ArtistSplitResultItem> splits) onApply;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ArtistSplitReviewPanel(
        directSplits: result.artistSplitsApplied,
        possibleSplits: result.artistSplitSuggestions,
        mergeSuggestions: result.artistMergeSuggestions,
        applying: applying,
        artworkPathBySongId: artworkPathBySongId,
        embeddedInFolderUpdateResult: true,
        onApply: onApply,
        onClose: onClose,
      ),
    );
  }
}
