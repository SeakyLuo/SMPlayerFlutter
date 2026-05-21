import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import 'artists_page_model.dart';
import 'local_folder_card.dart';
import 'local_folder_model.dart';
import 'local_page_model.dart';
import 'local_page_quick_jump.dart';
import 'music_library_page.dart';

class LocalGridContent extends StatelessWidget {
  const LocalGridContent({
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
  final String songQuickJumpBasisName;
  final Map<String, int> songQuickJumpMap;
  final LocalSortMode sortMode;
  final LocalSortMode currentSortMode;
  final List<int> queueSongIds;
  final List<LocalCompactTreeRow> compactTreeRows;
  final List<int> compactQueueSongIds;
  final SmPlayerI18n i18n;
  final VoidCallback onToggleFoldersExpanded;
  final VoidCallback onToggleSongsExpanded;
  final ValueChanged<String> onToggleTreeFolderExpanded;
  final ValueChanged<FolderNode> onPlayFolder;
  final ValueChanged<FolderNode> onAddFolder;
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
  final ValueChanged<LibrarySong> onAddSong;
  final void Function(LibrarySong song, Offset position) onOpenSongMenu;
  final ValueChanged<String> onJumpToSongKey;

  @override
  Widget build(BuildContext context) {
    final folderContent =
        isCompactLayout
            ? _LocalCompactTreeContent(
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
            : _LocalFolderGrid(
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
    final songContent = _LocalSongGrid(
      currentSongs: currentSongs,
      selectedSongIds: selectedSongIds,
      selectedTrackId: selectedTrackId,
      isPlaying: isPlaying,
      multiSelect: multiSelect,
      isCompactLayout: isCompactLayout,
      showSongQuickJump: showSongQuickJump,
      songQuickJumpBasisName: songQuickJumpBasisName,
      songQuickJumpMap: songQuickJumpMap,
      sortMode: sortMode,
      currentSortMode: currentSortMode,
      queueSongIds: queueSongIds,
      i18n: i18n,
      onPlayTrack: onPlayTrack,
      onTogglePlayPause: onTogglePlayPause,
      onToggleSongSelection: onToggleSongSelection,
      onPlayNext: onPlayNext,
      onToggleFavorite: onToggleFavorite,
      onAddSong: onAddSong,
      onOpenSongMenu: onOpenSongMenu,
      onJumpToSongKey: onJumpToSongKey,
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
                child: songContent,
              )
              : songContent,
      ],
    );
  }
}

class _LocalCompactTreeContent extends StatelessWidget {
  const _LocalCompactTreeContent({
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
  final ValueChanged<FolderNode> onAddFolder;
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
  final ValueChanged<LibrarySong> onAddSong;
  final void Function(LibrarySong song, Offset position) onOpenSongMenu;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in rows)
          Padding(
            key: ValueKey(row.key),
            padding: EdgeInsets.only(left: row.depth * 22.0, bottom: 8),
            child:
                row.type == LocalCompactTreeRowType.folder
                    ? _DraggableLocalFolderCard(
                      folder: row.folder!,
                      selected: selectedFolderPaths.contains(
                        row.folder!.relativePath,
                      ),
                      multiSelect: multiSelect,
                      nodes: nodes,
                      songsById: songsById,
                      i18n: i18n,
                      variant: LocalFolderCardVariant.list,
                      treeExpanded: row.expanded,
                      treeExpandable: row.expandable,
                      onToggleTreeExpanded:
                          () => onToggleTreeFolderExpanded(
                            row.folder!.relativePath,
                          ),
                      onPlayFolder: onPlayFolder,
                      onAddFolder: onAddFolder,
                      onRefreshFolder: onRefreshFolder,
                      onSearchFolder: onSearchFolder,
                      onRevealFolder: onRevealFolder,
                      onOpenFolder: onOpenFolder,
                      onOpenFolderMenu: onOpenFolderMenu,
                      onToggleSelection: onToggleFolderSelection,
                      dragPayload: _folderDragPayload(row.folder!),
                      onWillAcceptDrop: _isMoveTargetFolder,
                      onAcceptDrop: _moveDraggedItems,
                    )
                    : _CompactLocalSongRow(
                      song: row.song!,
                      selected: selectedSongIds.contains(row.song!.id),
                      current: row.song!.id == selectedTrackId,
                      playing: row.song!.id == selectedTrackId && isPlaying,
                      selectionMode: multiSelect,
                      i18n: i18n,
                      onPlay: () => onPlayTrack(row.song!.id, queueSongIds),
                      onTogglePlayPause: onTogglePlayPause,
                      onToggleSelection:
                          () => onToggleSongSelection(row.song!.id),
                      onPlayNext: () => onPlayNext(row.song!.id),
                      onToggleFavorite:
                          () => onToggleFavorite(
                            row.song!.id,
                            !row.song!.favorite,
                          ),
                      onAddSong: () => onAddSong(row.song!),
                      onOpenMenu:
                          (position) => onOpenSongMenu(row.song!, position),
                    ),
          ),
      ],
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

class _LocalFolderGrid extends StatelessWidget {
  const _LocalFolderGrid({
    required this.childFolders,
    required this.nodes,
    required this.songsById,
    required this.selectedFolderPaths,
    required this.multiSelect,
    required this.isCompactLayout,
    required this.i18n,
    required this.onPlayFolder,
    required this.onAddFolder,
    required this.onRefreshFolder,
    required this.onSearchFolder,
    required this.onRevealFolder,
    required this.onOpenFolder,
    required this.onOpenFolderMenu,
    required this.onToggleFolderSelection,
    required this.onMoveLocalItemsToFolder,
  });

  final List<FolderNode> childFolders;
  final Map<String, FolderNode> nodes;
  final Map<int, LibrarySong> songsById;
  final Set<String> selectedFolderPaths;
  final bool multiSelect;
  final bool isCompactLayout;
  final SmPlayerI18n i18n;
  final ValueChanged<FolderNode> onPlayFolder;
  final ValueChanged<FolderNode> onAddFolder;
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

  @override
  Widget build(BuildContext context) {
    if (isCompactLayout) {
      return Column(
        children: [
          for (final folder in childFolders)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DraggableLocalFolderCard(
                folder: folder,
                selected: selectedFolderPaths.contains(folder.relativePath),
                multiSelect: multiSelect,
                nodes: nodes,
                songsById: songsById,
                i18n: i18n,
                variant: LocalFolderCardVariant.list,
                onPlayFolder: onPlayFolder,
                onAddFolder: onAddFolder,
                onRefreshFolder: onRefreshFolder,
                onSearchFolder: onSearchFolder,
                onRevealFolder: onRevealFolder,
                onOpenFolder: onOpenFolder,
                onOpenFolderMenu: onOpenFolderMenu,
                onToggleSelection: onToggleFolderSelection,
                dragPayload: _folderDragPayload(folder),
                onWillAcceptDrop: _isMoveTargetFolder,
                onAcceptDrop: _moveDraggedItems,
              ),
            ),
        ],
      );
    }

    return Wrap(
      spacing: 30,
      runSpacing: 26,
      children: [
        for (final folder in childFolders)
          _DraggableLocalFolderCard(
            folder: folder,
            selected: selectedFolderPaths.contains(folder.relativePath),
            multiSelect: multiSelect,
            nodes: nodes,
            songsById: songsById,
            i18n: i18n,
            onPlayFolder: onPlayFolder,
            onAddFolder: onAddFolder,
            onRefreshFolder: onRefreshFolder,
            onSearchFolder: onSearchFolder,
            onRevealFolder: onRevealFolder,
            onOpenFolder: onOpenFolder,
            onOpenFolderMenu: onOpenFolderMenu,
            onToggleSelection: onToggleFolderSelection,
            dragPayload: _folderDragPayload(folder),
            onWillAcceptDrop: _isMoveTargetFolder,
            onAcceptDrop: _moveDraggedItems,
          ),
      ],
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

class _DraggableLocalFolderCard extends StatelessWidget {
  const _DraggableLocalFolderCard({
    required this.folder,
    required this.selected,
    required this.multiSelect,
    required this.nodes,
    required this.songsById,
    required this.i18n,
    required this.onPlayFolder,
    required this.onAddFolder,
    required this.onRefreshFolder,
    required this.onSearchFolder,
    required this.onRevealFolder,
    required this.onOpenFolder,
    required this.onOpenFolderMenu,
    required this.onToggleSelection,
    required this.dragPayload,
    required this.onWillAcceptDrop,
    required this.onAcceptDrop,
    this.variant = LocalFolderCardVariant.grid,
    this.treeExpanded,
    this.treeExpandable = false,
    this.onToggleTreeExpanded,
  });

  final FolderNode folder;
  final bool selected;
  final bool multiSelect;
  final Map<String, FolderNode> nodes;
  final Map<int, LibrarySong> songsById;
  final SmPlayerI18n i18n;
  final LocalFolderCardVariant variant;
  final bool? treeExpanded;
  final bool treeExpandable;
  final VoidCallback? onToggleTreeExpanded;
  final ValueChanged<FolderNode> onPlayFolder;
  final ValueChanged<FolderNode> onAddFolder;
  final ValueChanged<FolderNode> onRefreshFolder;
  final ValueChanged<FolderNode> onSearchFolder;
  final ValueChanged<FolderNode> onRevealFolder;
  final ValueChanged<String> onOpenFolder;
  final void Function(FolderNode folder, Offset position) onOpenFolderMenu;
  final ValueChanged<String> onToggleSelection;
  final LocalItemsDragPayload dragPayload;
  final bool Function(FolderNode folder, LocalItemsDragPayload payload)
  onWillAcceptDrop;
  final void Function(FolderNode folder, LocalItemsDragPayload payload)
  onAcceptDrop;

  @override
  Widget build(BuildContext context) {
    final card = LocalFolderCard(
      folder: folder,
      selected: selected,
      multiSelect: multiSelect,
      nodes: nodes,
      songsById: songsById,
      i18n: i18n,
      variant: variant,
      treeExpanded: treeExpanded,
      treeExpandable: treeExpandable,
      onToggleTreeExpanded: onToggleTreeExpanded,
      onPlayFolder: onPlayFolder,
      onAddFolder: onAddFolder,
      onRefreshFolder: onRefreshFolder,
      onSearchFolder: onSearchFolder,
      onRevealFolder: onRevealFolder,
      onOpenFolder: onOpenFolder,
      onOpenFolderMenu: onOpenFolderMenu,
      onToggleSelection: onToggleSelection,
      onWillAcceptDrop: onWillAcceptDrop,
      onAcceptDrop: onAcceptDrop,
    );
    return Draggable<LocalItemsDragPayload>(
      data: dragPayload,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.85, child: SizedBox(width: 180, child: card)),
      ),
      childWhenDragging: Opacity(opacity: 0.55, child: card),
      child: card,
    );
  }
}

class _LocalSongGrid extends StatelessWidget {
  const _LocalSongGrid({
    required this.currentSongs,
    required this.selectedSongIds,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.multiSelect,
    required this.isCompactLayout,
    required this.showSongQuickJump,
    required this.songQuickJumpBasisName,
    required this.songQuickJumpMap,
    required this.sortMode,
    required this.currentSortMode,
    required this.queueSongIds,
    required this.i18n,
    required this.onPlayTrack,
    required this.onTogglePlayPause,
    required this.onToggleSongSelection,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onAddSong,
    required this.onOpenSongMenu,
    required this.onJumpToSongKey,
  });

  final List<LibrarySong> currentSongs;
  final Set<int> selectedSongIds;
  final int? selectedTrackId;
  final bool isPlaying;
  final bool multiSelect;
  final bool isCompactLayout;
  final bool showSongQuickJump;
  final String songQuickJumpBasisName;
  final Map<String, int> songQuickJumpMap;
  final LocalSortMode sortMode;
  final LocalSortMode currentSortMode;
  final List<int> queueSongIds;
  final SmPlayerI18n i18n;
  final void Function(int trackId, List<int> queueSongIds) onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<int> onToggleSongSelection;
  final ValueChanged<int> onPlayNext;
  final void Function(int songId, bool favorite) onToggleFavorite;
  final ValueChanged<LibrarySong> onAddSong;
  final void Function(LibrarySong song, Offset position) onOpenSongMenu;
  final ValueChanged<String> onJumpToSongKey;

  @override
  Widget build(BuildContext context) {
    final visibleSongIds = currentSongs.map((song) => song.id).toSet();
    final effectiveSelectedSongIds =
        selectedSongIds.where(visibleSongIds.contains).toList();
    final songGrid =
        isCompactLayout
            ? Column(
              children: [
                for (final song in currentSongs)
                  _DraggableLocalSong(
                    payload: _songDragPayload(song, effectiveSelectedSongIds),
                    feedbackWidth: 420,
                    child: _CompactLocalSongRow(
                      song: song,
                      selected: selectedSongIds.contains(song.id),
                      current: song.id == selectedTrackId,
                      playing: song.id == selectedTrackId && isPlaying,
                      selectionMode: multiSelect,
                      i18n: i18n,
                      onPlay: () => onPlayTrack(song.id, queueSongIds),
                      onTogglePlayPause: onTogglePlayPause,
                      onToggleSelection: () => onToggleSongSelection(song.id),
                      onPlayNext: () => onPlayNext(song.id),
                      onToggleFavorite:
                          () => onToggleFavorite(song.id, !song.favorite),
                      onAddSong: () => onAddSong(song),
                      onOpenMenu: (position) => onOpenSongMenu(song, position),
                    ),
                  ),
              ],
            )
            : Wrap(
              spacing: 30,
              runSpacing: 26,
              children: [
                for (final song in currentSongs)
                  _DraggableLocalSong(
                    payload: _songDragPayload(song, effectiveSelectedSongIds),
                    feedbackWidth: 180,
                    child: _LocalSongGridItem(
                      song: song,
                      selected: selectedSongIds.contains(song.id),
                      current: song.id == selectedTrackId,
                      playing: song.id == selectedTrackId && isPlaying,
                      multiSelect: multiSelect,
                      detailLabel: getLocalSongDetailLabel(
                        song,
                        sortMode,
                        currentSortMode,
                        i18n,
                      ),
                      i18n: i18n,
                      onPlay: () => onPlayTrack(song.id, queueSongIds),
                      onTogglePlayPause: onTogglePlayPause,
                      onToggleSelection: () => onToggleSongSelection(song.id),
                      onAddSong: () => onAddSong(song),
                      onOpenMenu: (position) => onOpenSongMenu(song, position),
                    ),
                  ),
              ],
            );

    if (!showSongQuickJump) {
      return songGrid;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 420,
          child: LocalSongQuickJump(
            basisName: songQuickJumpBasisName,
            enabledKeys: songQuickJumpMap,
            i18n: i18n,
            visible: showSongQuickJump,
            onJump: onJumpToSongKey,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: songGrid),
      ],
    );
  }

  LocalItemsDragPayload _songDragPayload(
    LibrarySong song,
    List<int> effectiveSelectedSongIds,
  ) {
    final songIds =
        selectedSongIds.contains(song.id) && effectiveSelectedSongIds.isNotEmpty
            ? effectiveSelectedSongIds
            : [song.id];
    return LocalItemsDragPayload(songIds: songIds, folderPaths: const []);
  }
}

class _DraggableLocalSong extends StatelessWidget {
  const _DraggableLocalSong({
    required this.payload,
    required this.feedbackWidth,
    required this.child,
  });

  final LocalItemsDragPayload payload;
  final double feedbackWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Draggable<LocalItemsDragPayload>(
      data: payload,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.85,
          child: SizedBox(width: feedbackWidth, child: child),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.55, child: child),
      child: child,
    );
  }
}

class _LocalSongGridItem extends StatelessWidget {
  const _LocalSongGridItem({
    required this.song,
    required this.selected,
    required this.current,
    required this.playing,
    required this.multiSelect,
    required this.detailLabel,
    required this.i18n,
    required this.onPlay,
    required this.onTogglePlayPause,
    required this.onToggleSelection,
    required this.onAddSong,
    required this.onOpenMenu,
  });

  final LibrarySong song;
  final bool selected;
  final bool current;
  final bool playing;
  final bool multiSelect;
  final String? detailLabel;
  final SmPlayerI18n i18n;
  final VoidCallback onPlay;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleSelection;
  final VoidCallback onAddSong;
  final ValueChanged<Offset> onOpenMenu;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) => onOpenMenu(details.globalPosition),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: multiSelect ? onToggleSelection : onPlay,
        child: Container(
          width: 180,
          constraints: const BoxConstraints(minHeight: 232),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:
                selected || current
                    ? LocalPageColors.surfaceCardHover
                    : LocalPageColors.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            boxShadow:
                selected || current
                    ? const [
                      BoxShadow(
                        color: LocalPageColors.panelShadow,
                        offset: Offset(0, 16),
                        blurRadius: 34,
                      ),
                    ]
                    : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  LibraryRowArtwork(song: song, size: 160, onPlay: onPlay),
                  if (multiSelect)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _LocalCheckMark(selected: selected),
                    ),
                  if (!multiSelect)
                    Positioned.fill(
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _RoundSongAction(
                              tooltip: i18n.t('local.gridMusicPlayInfo', {
                                'name': song.title,
                              }),
                              icon:
                                  playing
                                      ? FluentIcons.pause_20_regular
                                      : FluentIcons.play_20_regular,
                              onPressed: current ? onTogglePlayPause : onPlay,
                            ),
                            const SizedBox(width: 10),
                            _RoundSongAction(
                              tooltip: i18n.t('context.addToPlaylist'),
                              icon: FluentIcons.add_20_regular,
                              onPressed: onAddSong,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            current
                                ? LocalPageColors.accentStrong
                                : LocalPageColors.textStrong,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (song.favorite)
                    const Icon(
                      FluentIcons.heart_16_filled,
                      color: LocalPageColors.favorite,
                      size: 16,
                    ),
                ],
              ),
              if (detailLabel != null) ...[
                const SizedBox(height: 3),
                Text(
                  detailLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        current
                            ? LocalPageColors.accentStrong
                            : LocalPageColors.textMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactLocalSongRow extends StatelessWidget {
  const _CompactLocalSongRow({
    required this.song,
    required this.selected,
    required this.current,
    required this.playing,
    required this.selectionMode,
    required this.i18n,
    required this.onPlay,
    required this.onTogglePlayPause,
    required this.onToggleSelection,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onAddSong,
    required this.onOpenMenu,
  });

  final LibrarySong song;
  final bool selected;
  final bool current;
  final bool playing;
  final bool selectionMode;
  final SmPlayerI18n i18n;
  final VoidCallback onPlay;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleSelection;
  final VoidCallback onPlayNext;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddSong;
  final ValueChanged<Offset> onOpenMenu;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) => onOpenMenu(details.globalPosition),
      child: InkWell(
        onTap: selectionMode ? onToggleSelection : onPlay,
        child: Container(
          height: 76,
          padding: const EdgeInsets.fromLTRB(6, 8, 8, 8),
          decoration: BoxDecoration(
            color: selected ? LocalPageColors.rowSelected : Colors.transparent,
            border: const Border(
              top: BorderSide(color: LocalPageColors.rowBorder),
            ),
          ),
          child: Row(
            children: [
              selectionMode
                  ? SizedBox(
                    width: 46,
                    child: _LocalCheckMark(selected: selected),
                  )
                  : LibraryRowArtwork(song: song, size: 46, onPlay: onPlay),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            current
                                ? LocalPageColors.accentStrong
                                : LocalPageColors.textStrong,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      getLocalDisplayArtists(song, i18n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LocalPageColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      displayAlbum(song, i18n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LocalPageColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip:
                    playing ? i18n.t('player.pause') : i18n.t('context.play'),
                icon: Icon(
                  playing
                      ? FluentIcons.pause_20_regular
                      : FluentIcons.play_20_regular,
                  size: 18,
                ),
                onPressed: current ? onTogglePlayPause : onPlay,
              ),
              IconButton(
                tooltip: i18n.t('context.playNext'),
                icon: const Icon(FluentIcons.next_20_regular, size: 18),
                onPressed: onPlayNext,
              ),
              IconButton(
                tooltip:
                    song.favorite
                        ? i18n.t('context.removeFavorite')
                        : i18n.t('context.addFavorite'),
                icon: Icon(
                  song.favorite
                      ? FluentIcons.heart_20_filled
                      : FluentIcons.heart_20_regular,
                  size: 18,
                ),
                onPressed: onToggleFavorite,
              ),
              IconButton(
                tooltip: i18n.t('context.addToPlaylist'),
                icon: const Icon(FluentIcons.add_20_regular, size: 18),
                onPressed: onAddSong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundSongAction extends StatelessWidget {
  const _RoundSongAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        style: IconButton.styleFrom(
          fixedSize: const Size(48, 48),
          backgroundColor: const Color(0xb81e2228),
          foregroundColor: Colors.white,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
      ),
    );
  }
}

class _LocalCheckMark extends StatelessWidget {
  const _LocalCheckMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color:
              selected
                  ? LocalPageColors.accentStrong
                  : LocalPageColors.selectionMark,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color:
                selected
                    ? LocalPageColors.accentStrong
                    : LocalPageColors.selectionBorder,
          ),
        ),
        child:
            selected
                ? const Icon(
                  FluentIcons.checkmark_16_regular,
                  color: Colors.white,
                  size: 14,
                )
                : null,
      ),
    );
  }
}

bool isMoveTargetFolder({
  required LocalItemsDragPayload payload,
  required FolderNode targetFolder,
  required Map<String, FolderNode> nodes,
  required Map<int, LibrarySong> songsById,
}) {
  if (payload.songIds.isEmpty && payload.folderPaths.isEmpty) {
    return false;
  }

  final targetPathKey = normalizePath(targetFolder.path);
  final songAlreadyInTarget = payload.songIds.any((songId) {
    final songPath = songsById[songId]!.path;
    return normalizePath(_fileParentPath(songPath)) == targetPathKey;
  });
  if (songAlreadyInTarget) {
    return false;
  }

  final nodesByAbsolutePath = {
    for (final node in nodes.values) normalizePath(node.path): node,
  };
  for (final folderPath in payload.folderPaths) {
    final sourceFolder = nodesByAbsolutePath[normalizePath(folderPath)]!;
    if (targetFolder.relativePath == sourceFolder.relativePath ||
        targetFolder.relativePath == getParentPath(sourceFolder.relativePath) ||
        targetFolder.relativePath.startsWith('${sourceFolder.relativePath}/')) {
      return false;
    }
  }

  return true;
}

String _fileParentPath(String filePath) {
  final normalized = normalizePath(filePath);
  final separatorIndex = normalized.lastIndexOf('/');
  return separatorIndex < 0 ? '' : normalized.substring(0, separatorIndex);
}
