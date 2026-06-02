import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import 'local_folder_model.dart';
import 'grid_view_folder.dart';
import 'grid_view_music.dart';
import 'local_page_model.dart';
import 'local_page_quick_jump.dart';
import 'tree_view.dart';

class LocalContentView extends StatelessWidget {
  const LocalContentView({
    super.key,
    required this.childFolders,
    required this.currentSongs,
    required this.nodes,
    required this.songsById,
    required this.selectedFolderPaths,
    required this.selectedSongIds,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.multiSelect,
    required this.isCompactLayout,
    required this.showLocalSectionHeaders,
    required this.foldersExpanded,
    required this.songsExpanded,
    required this.showSongQuickJump,
    required this.songQuickJumpBasisName,
    required this.songQuickJumpMap,
    required this.sortMode,
    required this.currentSortMode,
    required this.queueSongIds,
    required this.folderQueueSongIds,
    required this.compactTreeRows,
    required this.compactQueueSongIds,
    required this.i18n,
    required this.onToggleFoldersExpanded,
    required this.onToggleSongsExpanded,
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
    required this.onTogglePlayPause,
    required this.onToggleSongSelection,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onAddSong,
    required this.onOpenSongMenu,
    required this.onJumpToSongKey,
    this.reserveSongQuickJumpSpace = false,
    this.scrollController,
  });

  final List<FolderNode> childFolders;
  final List<LibrarySong> currentSongs;
  final Map<String, FolderNode> nodes;
  final Map<int, LibrarySong> songsById;
  final Set<String> selectedFolderPaths;
  final Set<int> selectedSongIds;
  final int? selectedTrackId;
  final bool isPlaying;
  final bool multiSelect;
  final bool isCompactLayout;
  final bool showLocalSectionHeaders;
  final bool foldersExpanded;
  final bool songsExpanded;
  final bool showSongQuickJump;
  final bool reserveSongQuickJumpSpace;
  final String songQuickJumpBasisName;
  final Map<String, int> songQuickJumpMap;
  final LocalSortMode sortMode;
  final LocalSortMode currentSortMode;
  final List<int> queueSongIds;
  final List<int> folderQueueSongIds;
  final List<LocalCompactTreeRow> compactTreeRows;
  final List<int> compactQueueSongIds;
  final SmPlayerI18n i18n;
  final VoidCallback onToggleFoldersExpanded;
  final VoidCallback onToggleSongsExpanded;
  final ValueChanged<String> onToggleTreeFolderExpanded;
  final ValueChanged<FolderNode> onPlayFolder;
  final void Function(FolderNode folder, Offset position) onAddFolder;
  final ValueChanged<FolderNode> onRefreshFolder;
  final ValueChanged<FolderNode> onSearchFolder;
  final ValueChanged<FolderNode> onRevealFolder;
  final ValueChanged<String> onOpenFolder;
  final void Function(FolderNode folder, Offset position) onOpenFolderMenu;
  final ValueChanged<String> onToggleFolderSelection;
  final void Function({
    required List<int> songIds,
    required List<String> folderPaths,
    required String targetFolderPath,
  })
  onMoveLocalItemsToFolder;
  final void Function(int trackId, List<int> queueSongIds) onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<int> onToggleSongSelection;
  final ValueChanged<int> onPlayNext;
  final void Function(int songId, bool favorite) onToggleFavorite;
  final void Function(LibrarySong song, Offset position) onAddSong;
  final void Function(LibrarySong song, Offset position) onOpenSongMenu;
  final ValueChanged<String> onJumpToSongKey;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final folderContent =
        isCompactLayout
            ? LocalTreeView(
              rows: compactTreeRows,
              nodes: nodes,
              songsById: songsById,
              selectedFolderPaths: selectedFolderPaths,
              selectedSongIds: selectedSongIds,
              selectedTrackId: selectedTrackId,
              isPlaying: isPlaying,
              multiSelect: multiSelect,
              queueSongIds: compactQueueSongIds,
              i18n: i18n,
              onToggleTreeFolderExpanded: onToggleTreeFolderExpanded,
              onPlayFolder: onPlayFolder,
              onAddFolder: onAddFolder,
              onRefreshFolder: onRefreshFolder,
              onSearchFolder: onSearchFolder,
              onRevealFolder: onRevealFolder,
              onOpenFolder: onOpenFolder,
              onOpenFolderMenu: onOpenFolderMenu,
              onToggleFolderSelection: onToggleFolderSelection,
              onMoveLocalItemsToFolder: onMoveLocalItemsToFolder,
              onPlayTrack: onPlayTrack,
              onTogglePlayPause: onTogglePlayPause,
              onToggleSongSelection: onToggleSongSelection,
              onPlayNext: onPlayNext,
              onToggleFavorite: onToggleFavorite,
              onAddSong: onAddSong,
              onOpenSongMenu: onOpenSongMenu,
            )
            : LocalGridViewFolder(
              childFolders: childFolders,
              nodes: nodes,
              songsById: songsById,
              selectedFolderPaths: selectedFolderPaths,
              multiSelect: multiSelect,
              isCompactLayout: isCompactLayout,
              i18n: i18n,
              onPlayFolder: onPlayFolder,
              onAddFolder: onAddFolder,
              onRefreshFolder: onRefreshFolder,
              onSearchFolder: onSearchFolder,
              onRevealFolder: onRevealFolder,
              onOpenFolder: onOpenFolder,
              onOpenFolderMenu: onOpenFolderMenu,
              onToggleFolderSelection: onToggleFolderSelection,
              onMoveLocalItemsToFolder: onMoveLocalItemsToFolder,
            );
    final songContent = LocalGridViewMusic(
      currentSongs: currentSongs,
      selectedSongIds: selectedSongIds,
      selectedTrackId: selectedTrackId,
      isPlaying: isPlaying,
      multiSelect: multiSelect,
      isCompactLayout: isCompactLayout,
      showSongQuickJump: showSongQuickJump,
      reserveSongQuickJumpSpace: reserveSongQuickJumpSpace,
      songQuickJumpBasisName: songQuickJumpBasisName,
      songQuickJumpMap: songQuickJumpMap,
      sortMode: sortMode,
      currentSortMode: currentSortMode,
      queueSongIds: queueSongIds,
      folderQueueSongIds: folderQueueSongIds,
      i18n: i18n,
      onPlayTrack: onPlayTrack,
      onTogglePlayPause: onTogglePlayPause,
      onToggleSongSelection: onToggleSongSelection,
      onPlayNext: onPlayNext,
      onToggleFavorite: onToggleFavorite,
      onAddSong: onAddSong,
      onOpenSongMenu: onOpenSongMenu,
      onJumpToSongKey: onJumpToSongKey,
      scrollController: scrollController,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (childFolders.isNotEmpty)
          showLocalSectionHeaders
              ? LocalContentSection(
                title: i18n.t('common.folders'),
                count: childFolders.length,
                expanded: foldersExpanded,
                onToggle: onToggleFoldersExpanded,
                compact: isCompactLayout,
                child: folderContent,
              )
              : folderContent,
        if (currentSongs.isNotEmpty)
          showLocalSectionHeaders
              ? LocalContentSection(
                title: i18n.t('local.allSongs'),
                count: currentSongs.length,
                expanded: songsExpanded,
                onToggle: onToggleSongsExpanded,
                compact: isCompactLayout,
                child: songContent,
              )
              : songContent,
      ],
    );
  }
}
