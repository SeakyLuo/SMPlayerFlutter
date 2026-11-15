import '../../remote/music_share_models.dart';
import '../../remote/music_share_access.dart';
import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../app/smplayer_vector_icons.dart';
import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import 'artists_page_model.dart' show displayAlbum;
import 'local_folder_model.dart';
import 'local_page_model.dart';
import 'local_page_quick_jump.dart';

part 'local_compact_table_surfaces.dart';

class LocalCompactTableContent extends StatelessWidget {
  const LocalCompactTableContent({
    super.key,
    required this.scrollController,
    required this.childFolders,
    required this.currentSongs,
    required this.nodes,
    required this.songsById,
    required this.selectedFolderPaths,
    required this.selectedSongIds,
    required this.selectedTrackId,
    required this.isPlaying,
    required this.multiSelect,
    required this.showLocalSectionHeaders,
    required this.foldersExpanded,
    required this.songsExpanded,
    required this.showSongQuickJump,
    required this.songQuickJumpBasisName,
    required this.songQuickJumpMap,
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
    required this.onPlaySong,
    required this.onTogglePlayPause,
    required this.onToggleSongSelection,
    required this.onPlayNext,
    required this.onAddSong,
    required this.onOpenSongMenu,
    required this.onJumpToSongKey,
  });

  final ScrollController scrollController;
  final List<FolderNode> childFolders;
  final List<LibrarySong> currentSongs;
  final Map<String, FolderNode> nodes;
  final Map<int, LibrarySong> songsById;
  final Set<String> selectedFolderPaths;
  final Set<int> selectedSongIds;
  final int? selectedTrackId;
  final bool isPlaying;
  final bool multiSelect;
  final bool showLocalSectionHeaders;
  final bool foldersExpanded;
  final bool songsExpanded;
  final bool showSongQuickJump;
  final String songQuickJumpBasisName;
  final Map<String, int> songQuickJumpMap;
  final List<int> queueSongIds;
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
  final FutureOr<void> Function(LibrarySong song, Offset position) onAddSong;
  final FutureOr<void> Function(LibrarySong song, Offset position)
  onOpenSongMenu;
  final ValueChanged<String> onJumpToSongKey;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('LocalTableContent.CompactList'),
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
      itemCount: _rowCount,
      itemBuilder: (context, index) => _rowAt(context, index),
    );
  }

  int get _rowCount {
    if (compactTreeRows.isNotEmpty) {
      return compactTreeRows.length + currentSongs.length;
    }

    var count = 0;
    if (showLocalSectionHeaders && childFolders.isNotEmpty) {
      count += 1;
    }
    if (!showLocalSectionHeaders || foldersExpanded) {
      count += childFolders.length;
    }
    if (showLocalSectionHeaders && currentSongs.isNotEmpty) {
      count += 1;
    }
    if ((!showLocalSectionHeaders || songsExpanded) && showSongQuickJump) {
      count += 1;
    }
    if (!showLocalSectionHeaders || songsExpanded) {
      count += currentSongs.length;
    }
    return count;
  }

  Widget _rowAt(BuildContext context, int index) {
    var rowIndex = index;
    if (compactTreeRows.isNotEmpty) {
      if (rowIndex < compactTreeRows.length) {
        final row = compactTreeRows[rowIndex];
        return row.type == LocalCompactTreeRowType.folder
            ? _folderRow(context, row.folder!, treeRow: row)
            : _songRow(context, row.song!, treeRow: row);
      }
      rowIndex -= compactTreeRows.length;
      final song = currentSongs[rowIndex];
      return _songRow(
        context,
        song,
        treeRow: LocalCompactTreeRow.song(
          key: 'song:${song.id}',
          song: song,
          depth: 0,
          songIndex: rowIndex,
        ),
      );
    }

    if (showLocalSectionHeaders && childFolders.isNotEmpty) {
      if (rowIndex == 0) {
        return _sectionRow(
          context,
          title: i18n.t('common.folders'),
          count: childFolders.length,
          expanded: foldersExpanded,
          onToggle: onToggleFoldersExpanded,
        );
      }
      rowIndex -= 1;
    }

    if (!showLocalSectionHeaders || foldersExpanded) {
      if (rowIndex < childFolders.length) {
        return _folderRow(context, childFolders[rowIndex]);
      }
      rowIndex -= childFolders.length;
    }

    if (showLocalSectionHeaders && currentSongs.isNotEmpty) {
      if (rowIndex == 0) {
        return _sectionRow(
          context,
          title: i18n.t('common.songs'),
          count: currentSongs.length,
          expanded: songsExpanded,
          onToggle: onToggleSongsExpanded,
        );
      }
      rowIndex -= 1;
    }

    if ((!showLocalSectionHeaders || songsExpanded) && showSongQuickJump) {
      if (rowIndex == 0) {
        return _quickJumpRow();
      }
      rowIndex -= 1;
    }

    return _songRow(context, currentSongs[rowIndex]);
  }

  Widget _sectionRow(
    BuildContext context, {
    required String title,
    required int count,
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    final colors = LocalPageColors.of(context);
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
        child: Row(
          children: [
            Icon(
              expanded
                  ? FluentIcons.chevron_down_20_regular
                  : FluentIcons.chevron_right_20_regular,
              size: 18,
              color: colors.accentStrong,
            ),
            const SizedBox(width: 8),
            Text(
              '$title ($count)',
              style: TextStyle(
                color: colors.accentStrong,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickJumpRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: LocalSongQuickJump(
        basisName: songQuickJumpBasisName,
        enabledKeys: songQuickJumpMap,
        visible: showSongQuickJump,
        i18n: i18n,
        axis: Axis.horizontal,
        compact: true,
        onJump: onJumpToSongKey,
      ),
    );
  }

  Widget _folderRow(
    BuildContext context,
    FolderNode folder, {
    LocalCompactTreeRow? treeRow,
  }) {
    final rowContent = _CompactHoverRow(
      onOpenContextMenu: (position) => onOpenFolderMenu(folder, position),
      child: _FolderRowSurface(
        folder: folder,
        treeRow: treeRow,
        selected: selectedFolderPaths.contains(folder.relativePath),
        multiSelect: multiSelect,
        i18n: i18n,
        onToggleTreeFolderExpanded: onToggleTreeFolderExpanded,
        actions:
            multiSelect
                ? const SizedBox.shrink()
                : _CompactTableActions(
                  children: [
                    IconButton(
                      tooltip: i18n.t('local.playAllButtonTooltip'),
                      icon: const ShuffleIcon(),
                      onPressed: () => onPlayFolder(folder),
                    ),
                    Builder(
                      builder:
                          (buttonContext) => IconButton(
                            tooltip: i18n.t('context.addToPlaylist'),
                            icon: const Icon(FluentIcons.add_20_regular),
                            onPressed:
                                () => _invokeAtButtonBottom(
                                  buttonContext,
                                  (position) => onAddFolder(folder, position),
                                ),
                          ),
                    ),
                    IconButton(
                      tooltip: i18n.t('local.updateFolder'),
                      icon: const Icon(FluentIcons.arrow_sync_20_regular),
                      onPressed:
                          !isRemoteMusicPath(folder.path) ||
                                  activeMusicShareAccess!.canWrite(folder.path)
                              ? () => onRefreshFolder(folder)
                              : null,
                    ),
                    IconButton(
                      tooltip: i18n.t('local.searchFolderButtonTooltip'),
                      icon: const Icon(FluentIcons.search_20_regular),
                      onPressed: () => onSearchFolder(folder),
                    ),
                    if (!isRemoteMusicPath(folder.path))
                      IconButton(
                        tooltip: i18n.t('local.openLocalButtonTooltip'),
                        icon: const Icon(FluentIcons.folder_open_20_regular),
                        onPressed: () => onRevealFolder(folder),
                      ),
                  ],
                ),
      ),
    );
    return DragTarget<LocalItemsDragPayload>(
      onWillAcceptWithDetails:
          (details) => isLocalMoveTargetFolder(
            payload: details.data,
            targetFolder: folder,
            nodes: nodes,
            songsById: songsById,
          ),
      onAcceptWithDetails:
          (details) => onMoveLocalItemsToFolder(
            songIds: details.data.songIds,
            folderPaths: details.data.folderPaths,
            targetFolderPath: folder.path,
          ),
      builder: (context, candidateData, rejectedData) {
        final child = InkWell(
          onTap:
              multiSelect
                  ? () => onToggleFolderSelection(folder.relativePath)
                  : () => onOpenFolder(folder.relativePath),
          child: rowContent,
        );
        return Draggable<LocalItemsDragPayload>(
          data: LocalItemsDragPayload(
            songIds: const [],
            folderPaths:
                selectedFolderPaths.contains(folder.relativePath)
                    ? selectedFolderPaths
                        .map((path) => nodes[path]!.path)
                        .toList()
                    : [folder.path],
          ),
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(width: 360, child: rowContent),
          ),
          childWhenDragging: Opacity(opacity: 0.55, child: child),
          child: child,
        );
      },
    );
  }

  Widget _songRow(
    BuildContext context,
    LibrarySong song, {
    LocalCompactTreeRow? treeRow,
  }) {
    final current = song.id == selectedTrackId;
    final selected = selectedSongIds.contains(song.id);
    final playing = current && isPlaying;
    final queueIds = treeRow == null ? queueSongIds : compactQueueSongIds;
    return Draggable<LocalItemsDragPayload>(
      data: LocalItemsDragPayload(
        songIds: selected ? selectedSongIds.toList() : [song.id],
        folderPaths: const [],
      ),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 320,
          child: _SongRowSurface(
            song: song,
            depth: treeRow?.depth ?? 0,
            selected: selected,
            current: current,
            multiSelect: multiSelect,
            i18n: i18n,
            actions: const SizedBox.shrink(),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.55,
        child: _songRowSurface(
          song,
          treeRow,
          selected,
          current,
          playing,
          queueIds,
        ),
      ),
      child: InkWell(
        onTap:
            multiSelect
                ? () => onToggleSongSelection(song.id)
                : () => onPlayTrack(song.id, queueIds),
        child: _songRowSurface(
          song,
          treeRow,
          selected,
          current,
          playing,
          queueIds,
        ),
      ),
    );
  }

  Widget _songRowSurface(
    LibrarySong song,
    LocalCompactTreeRow? treeRow,
    bool selected,
    bool current,
    bool playing,
    List<int> queueIds,
  ) {
    return _CompactHoverRow(
      onOpenContextMenu: (position) => onOpenSongMenu(song, position),
      child: _SongRowSurface(
        song: song,
        depth: treeRow?.depth ?? 0,
        selected: selected,
        current: current,
        multiSelect: multiSelect,
        i18n: i18n,
        actions:
            multiSelect
                ? const SizedBox.shrink()
                : _CompactTableActions(
                  children: [
                    IconButton(
                      tooltip:
                          playing
                              ? i18n.t('player.pause')
                              : i18n.t('context.play'),
                      icon: Icon(
                        playing
                            ? FluentIcons.pause_20_regular
                            : FluentIcons.play_20_regular,
                      ),
                      onPressed:
                          current
                              ? onTogglePlayPause
                              : () => onPlaySong(song.id),
                    ),
                    Builder(
                      builder:
                          (buttonContext) => IconButton(
                            tooltip: i18n.t('context.addToPlaylist'),
                            icon: const Icon(FluentIcons.add_20_regular),
                            onPressed:
                                () => _invokeAtButtonBottom(
                                  buttonContext,
                                  (position) => onAddSong(song, position),
                                ),
                          ),
                    ),
                    IconButton(
                      tooltip: i18n.t('context.playNext'),
                      icon: const SmPlayerPlayNextIcon(),
                      onPressed: () => onPlayNext(song.id),
                    ),
                  ],
                ),
      ),
    );
  }
}
