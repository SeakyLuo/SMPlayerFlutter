import 'dart:async';

import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import 'local_folder_card.dart';
import 'local_folder_model.dart';
import 'local_view_shared.dart';
import 'grid_view_folder.dart';
import 'grid_view_music.dart';
import 'local_page_model.dart';

class LocalTreeView extends StatelessWidget {
  const LocalTreeView({
    super.key,
    required this.rows,
    required this.nodes,
    required this.songsById,
    required this.selectedFolderPaths,
    required this.selectedSongIds,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.multiSelect,
    required this.queueSongIds,
    required this.i18n,
    required this.onToggleTreeFolderExpanded,
    required this.onPlayFolder,
    required this.onAddFolder,
    required this.onRefreshFolder,
    required this.onSearchFolder,
    required this.onRevealFolder,
    required this.onOpenFolder,
    required this.onOpenFolderMenu,
    required this.onToggleFolderSelection,
    required this.onMoveLocalItemsToFolder,
    required this.onPlayTrack,
    required this.onPlaySong,
    required this.onTogglePlayPause,
    required this.onToggleSongSelection,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onAddSong,
    required this.onOpenSongMenu,
  });

  final List<LocalCompactTreeRow> rows;
  final Map<String, FolderNode> nodes;
  final Map<int, LibrarySong> songsById;
  final Set<String> selectedFolderPaths;
  final Set<int> selectedSongIds;
  final int? selectedTrackId;
  final bool isPlaying;
  final bool multiSelect;
  final List<int> queueSongIds;
  final SmPlayerI18n i18n;
  final ValueChanged<String> onToggleTreeFolderExpanded;
  final ValueChanged<FolderNode> onPlayFolder;
  final FutureOr<void> Function(FolderNode folder, Offset position) onAddFolder;
  final ValueChanged<FolderNode> onRefreshFolder;
  final ValueChanged<FolderNode> onSearchFolder;
  final ValueChanged<FolderNode> onRevealFolder;
  final ValueChanged<String> onOpenFolder;
  final FutureOr<void> Function(FolderNode folder, Offset position)
  onOpenFolderMenu;
  final ValueChanged<String> onToggleFolderSelection;
  final void Function({
    required List<int> songIds,
    required List<String> folderPaths,
    required String targetFolderPath,
  })
  onMoveLocalItemsToFolder;
  final void Function(int trackId, List<int> queueSongIds) onPlayTrack;
  final ValueChanged<int> onPlaySong;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<int> onToggleSongSelection;
  final ValueChanged<int> onPlayNext;
  final void Function(int songId, bool favorite) onToggleFavorite;
  final FutureOr<void> Function(LibrarySong song, Offset position) onAddSong;
  final FutureOr<void> Function(LibrarySong song, Offset position)
  onOpenSongMenu;

  @override
  Widget build(BuildContext context) {
    return LocalCompactListPanel(
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index += 1)
            LocalCompactPanelRow(
              key: ValueKey(rows[index].key),
              last: index == rows.length - 1,
              padding: EdgeInsets.only(left: rows[index].depth * 22.0),
              reserveSeparatorSpace:
                  rows[index].type == LocalCompactTreeRowType.song,
              child:
                  rows[index].type == LocalCompactTreeRowType.folder
                      ? DraggableLocalFolderCard(
                        folder: rows[index].folder!,
                        selected: selectedFolderPaths.contains(
                          rows[index].folder!.relativePath,
                        ),
                        multiSelect: multiSelect,
                        nodes: nodes,
                        songsById: songsById,
                        i18n: i18n,
                        variant: LocalFolderCardVariant.list,
                        treeExpanded: rows[index].expanded,
                        treeExpandable: rows[index].expandable,
                        onToggleTreeExpanded:
                            () => onToggleTreeFolderExpanded(
                              rows[index].folder!.relativePath,
                            ),
                        onPlayFolder: onPlayFolder,
                        onAddFolder: onAddFolder,
                        onRefreshFolder: onRefreshFolder,
                        onSearchFolder: onSearchFolder,
                        onRevealFolder: onRevealFolder,
                        onOpenFolder: onOpenFolder,
                        onOpenFolderMenu: onOpenFolderMenu,
                        onToggleSelection: onToggleFolderSelection,
                        dragPayload: _folderDragPayload(rows[index].folder!),
                        onWillAcceptDrop: _isMoveTargetFolder,
                        onAcceptDrop: _moveDraggedItems,
                      )
                      : CompactLocalSongRow(
                        song: rows[index].song!,
                        selected: selectedSongIds.contains(
                          rows[index].song!.id,
                        ),
                        current: rows[index].song!.id == selectedTrackId,
                        playing:
                            rows[index].song!.id == selectedTrackId &&
                            isPlaying,
                        selectionMode: multiSelect,
                        i18n: i18n,
                        onPlay:
                            () =>
                                onPlayTrack(rows[index].song!.id, queueSongIds),
                        onPlayButton: () => onPlaySong(rows[index].song!.id),
                        onTogglePlayPause: onTogglePlayPause,
                        onToggleSelection:
                            () => onToggleSongSelection(rows[index].song!.id),
                        onPlayNext: () => onPlayNext(rows[index].song!.id),
                        onToggleFavorite:
                            () => onToggleFavorite(
                              rows[index].song!.id,
                              !rows[index].song!.favorite,
                            ),
                        onAddSong:
                            (position) =>
                                onAddSong(rows[index].song!, position),
                        onOpenMenu:
                            (position) =>
                                onOpenSongMenu(rows[index].song!, position),
                      ),
            ),
        ],
      ),
    );
  }

  LocalItemsDragPayload _folderDragPayload(FolderNode folder) {
    final folderPaths =
        selectedFolderPaths.contains(folder.relativePath)
            ? selectedFolderPaths.map((path) => nodes[path]!.path).toList()
            : [folder.path];
    return LocalItemsDragPayload(songIds: const [], folderPaths: folderPaths);
  }

  bool _isMoveTargetFolder(
    FolderNode targetFolder,
    LocalItemsDragPayload payload,
  ) {
    return isMoveTargetFolder(
      payload: payload,
      targetFolder: targetFolder,
      nodes: nodes,
      songsById: songsById,
    );
  }

  void _moveDraggedItems(FolderNode folder, LocalItemsDragPayload payload) {
    onMoveLocalItemsToFolder(
      songIds: payload.songIds,
      folderPaths: payload.folderPaths,
      targetFolderPath: folder.path,
    );
  }
}
