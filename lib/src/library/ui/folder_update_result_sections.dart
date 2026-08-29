import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smplayer_flutter/src/app/clipped_rounded_surface.dart';
import 'package:smplayer_flutter/src/app/edge_auto_hide_scrollbar.dart';
import 'package:smplayer_flutter/src/playback/playlist_control_item.dart';
import 'package:smplayer_flutter/src/settings/artist_split_review_panel.dart';

import '../data/library_models.dart';
import 'folder_update_result_file_title.dart';
import 'local_folder_model.dart';
import 'popup_dialog.dart';

const _folderUpdateResultRowHeight = 78.0;
const _folderUpdateResultListBorderWidth = 1.0;
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
  final ValueChanged<int>? onPlay;
  final FutureOr<void> Function(LibrarySong song, Offset position)?
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
    const rowHeight = _folderUpdateResultRowHeight;
    final desiredContentHeight = visibleRows * rowHeight;
    final desiredListHeight =
        desiredContentHeight + _folderUpdateResultListBorderWidth * 2;
    final listHeight =
        desiredListHeight > maxHeight ? maxHeight : desiredListHeight;
    final scrollable =
        items.length > visibleRows || desiredListHeight > maxHeight;
    final colors = _FolderUpdateResultColors.resolve(context);
    final popupColors = PopupDialogColors.resolve(context);
    final playlistColors = PlaylistControlItemColors(
      border: colors.rowBorder,
      hover: Color.alphaBlend(colors.rowHover, popupColors.surface),
      hoverBorder: colors.border,
      current: Color.alphaBlend(
        popupColors.accent.withValues(alpha: 0.16),
        popupColors.surface,
      ),
      currentForeground: popupColors.accentStrong,
      currentMuted: popupColors.accentStrong.withValues(alpha: 0.78),
      textStrong: colors.textStrong,
      textMuted: colors.textMuted,
      artworkBackground: popupColors.fieldSurface,
      actionForeground: colors.textMuted,
      actionHover: popupColors.accent.withValues(alpha: 0.12),
    );

    Widget buildItem(int index) {
      final item = items[index];
      final path = item.path;
      final title = item.title;
      final showsFullPath = title == path;
      final song =
          playable ? songsByPathKey[normalizePath(path).toLowerCase()] : null;
      final current = song != null && song.id == selectedTrackId;
      if (song != null && onPlay != null && onOpenSongMenu != null) {
        void play() {
          onPlay!(song.id);
        }

        return PlaylistControlItem(
          key: ValueKey('FolderUpdateResult.Song.${song.id}'),
          song: song,
          current: current,
          playing: current && isPlaying,
          selected: false,
          selectionMode: false,
          showAlbum: true,
          variant: PlaylistControlItemVariant.compact,
          colors: playlistColors,
          showCompactPrimaryActions: true,
          collapseCompactPrimaryActions: true,
          compactTrailingPadding: 20,
          showFavoriteAction: false,
          swipeEnabled: false,
          showBottomBorder: index != items.length - 1,
          onActivateRow: play,
          onPlayTrack: play,
          onTogglePlayPause: play,
          onToggleSelection: () {},
          onOpenContextMenu: (position) => onOpenSongMenu!(song, position),
        );
      }
      return _FolderUpdateResultRow(
        title: title,
        fullPath: showsFullPath,
        first: index == 0,
        odd: index.isEven,
      );
    }

    Widget buildSurface(Widget child) {
      return SmPlayerClippedRoundedSurface(
        color: colors.listBackground,
        radius: 12,
        borderSide: BorderSide(
          color: colors.border,
          width: _folderUpdateResultListBorderWidth,
        ),
        child: child,
      );
    }

    final content =
        scrollable
            ? EdgeAutoHideScrollbar(
              trailingEdgeOffset: 10,
              builder:
                  (controller) => buildSurface(
                    ListView.builder(
                      controller: controller,
                      padding: EdgeInsets.zero,
                      itemExtent: rowHeight,
                      itemCount: items.length,
                      itemBuilder: (context, index) => buildItem(index),
                    ),
                  ),
            )
            : buildSurface(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < items.length; index += 1)
                    SizedBox(height: rowHeight, child: buildItem(index)),
                ],
              ),
            );
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(height: listHeight, child: content),
    );
  }
}

class _FolderUpdateResultRow extends StatelessWidget {
  const _FolderUpdateResultRow({
    required this.title,
    required this.fullPath,
    required this.first,
    required this.odd,
  });

  final String title;
  final bool fullPath;
  final bool first;
  final bool odd;

  @override
  Widget build(BuildContext context) {
    final colors = _FolderUpdateResultColors.resolve(context);
    final popupColors = PopupDialogColors.resolve(context);
    final nightMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: colors.rowBackground(playable: false, odd: odd),
        border: first ? null : Border(top: BorderSide(color: colors.rowBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: popupColors.accent.withValues(
                alpha: nightMode ? 0.16 : 0.09,
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              FluentIcons.music_note_2_20_regular,
              size: 20,
              color: popupColors.accentStrong.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: fullPath ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fullPath ? colors.textMuted : colors.textStrong,
                fontSize: fullPath ? 13 : 15,
                fontWeight: fullPath ? FontWeight.w500 : FontWeight.w600,
                height: fullPath ? 1.25 : 1.2,
              ),
            ),
          ),
        ],
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
        listBackground: Colors.white.withValues(alpha: 0.055),
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
      listBackground: const Color(0xd1f6f9fd),
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
