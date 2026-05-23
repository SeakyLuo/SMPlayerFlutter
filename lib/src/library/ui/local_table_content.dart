import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import 'artists_page_model.dart' show displayAlbum;
import 'local_folder_model.dart';
import 'local_page_model.dart';
import 'local_page_quick_jump.dart';

class LocalTableContent extends StatelessWidget {
  const LocalTableContent({
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
  final void Function(LibrarySong song, Offset position) onAddSong;
  final void Function(LibrarySong song, Offset position) onOpenSongMenu;
  final ValueChanged<String> onJumpToSongKey;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('LocalTableContent.VirtualList'),
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 18),
      itemCount: _rowCount,
      itemBuilder: (context, index) {
        return _TableRowHost(row: _rowAt(context, index));
      },
    );
  }

  int get _rowCount {
    if (compactTreeRows.isNotEmpty) {
      return 1 + compactTreeRows.length + currentSongs.length;
    }

    var count = 1;
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

  TableRow _rowAt(BuildContext context, int index) {
    if (index == 0) {
      return _headerRow();
    }

    var rowIndex = index - 1;
    if (compactTreeRows.isNotEmpty) {
      if (rowIndex < compactTreeRows.length) {
        final row = compactTreeRows[rowIndex];
        return row.type == LocalCompactTreeRowType.folder
            ? _treeFolderRow(context, row)
            : _treeSongRow(context, row);
      }
      rowIndex -= compactTreeRows.length;
      final song = currentSongs[rowIndex];
      return _treeSongRow(
        context,
        LocalCompactTreeRow.song(
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
          title: i18n.t('local.allSongs'),
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

  TableRow _headerRow() {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LocalPageColors.rowBorder)),
      ),
      children: [
        _HeaderCell(i18n.t('common.name')),
        _HeaderCell(i18n.t('common.artist')),
        _HeaderCell(i18n.t('common.album')),
      ],
    );
  }

  TableRow _sectionRow({
    required String title,
    required int count,
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    return TableRow(
      decoration: const BoxDecoration(color: LocalPageColors.accentSoft),
      children: [
        TableCell(
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  Icon(
                    expanded
                        ? FluentIcons.chevron_down_20_regular
                        : FluentIcons.chevron_right_20_regular,
                    size: 18,
                    color: LocalPageColors.accentStrong,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$title ($count)',
                    style: const TextStyle(
                      color: LocalPageColors.accentStrong,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox.shrink(),
        const SizedBox.shrink(),
      ],
    );
  }

  TableRow _quickJumpRow() {
    return TableRow(
      children: [
        TableCell(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: LocalSongQuickJump(
              basisName: songQuickJumpBasisName,
              enabledKeys: songQuickJumpMap,
              visible: showSongQuickJump,
              i18n: i18n,
              onJump: onJumpToSongKey,
            ),
          ),
        ),
        const SizedBox.shrink(),
        const SizedBox.shrink(),
      ],
    );
  }

  TableRow _treeFolderRow(BuildContext context, LocalCompactTreeRow row) {
    final folder = row.folder!;
    final selected = selectedFolderPaths.contains(folder.relativePath);
    return TableRow(
      decoration: BoxDecoration(
        color: selected ? LocalPageColors.rowSelected : Colors.transparent,
        border: const Border(
          bottom: BorderSide(color: LocalPageColors.rowBorder),
        ),
      ),
      children: [
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: DragTarget<LocalItemsDragPayload>(
            onWillAcceptWithDetails:
                (details) => _isMoveTargetFolder(folder, details.data),
            onAcceptWithDetails:
                (details) => _moveDraggedItems(folder, details.data),
            builder: (context, candidateData, rejectedData) {
              final cell = GestureDetector(
                onSecondaryTapDown:
                    (details) =>
                        onOpenFolderMenu(folder, details.globalPosition),
                child: InkWell(
                  onTap:
                      multiSelect
                          ? () => onToggleFolderSelection(folder.relativePath)
                          : () => onOpenFolder(folder.relativePath),
                  child: Container(
                    decoration:
                        candidateData.isEmpty
                            ? null
                            : BoxDecoration(
                              color: LocalPageColors.accentSoft,
                              border: Border.all(
                                color: LocalPageColors.accentStrong,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                    padding: EdgeInsets.fromLTRB(
                      12 + row.depth * 22.0,
                      7,
                      8,
                      7,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: folder.name,
                          icon: Icon(
                            row.expandable
                                ? row.expanded
                                    ? FluentIcons.chevron_down_20_regular
                                    : FluentIcons.chevron_right_20_regular
                                : FluentIcons.chevron_right_20_regular,
                          ),
                          color:
                              row.expandable
                                  ? LocalPageColors.textMuted
                                  : Colors.transparent,
                          iconSize: 18,
                          onPressed:
                              row.expandable
                                  ? () => onToggleTreeFolderExpanded(
                                    folder.relativePath,
                                  )
                                  : null,
                        ),
                        if (multiSelect) ...[
                          _LocalTableCheckMark(selected: selected),
                          const SizedBox(width: 10),
                        ],
                        const Icon(
                          FluentIcons.folder_20_regular,
                          color: LocalPageColors.artworkIcon,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            folder.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: LocalPageColors.textStrong,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          i18n.t('playlists.songCount', {
                            'count': folder.subtreeSongIds.length,
                          }),
                          style: const TextStyle(
                            color: LocalPageColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              return Draggable<LocalItemsDragPayload>(
                data: _folderDragPayload(folder),
                feedback: Material(
                  color: Colors.transparent,
                  child: SizedBox(width: 360, child: cell),
                ),
                childWhenDragging: Opacity(opacity: 0.55, child: cell),
                child: cell,
              );
            },
          ),
        ),
        const SizedBox.shrink(),
        const SizedBox.shrink(),
      ],
    );
  }

  TableRow _treeSongRow(BuildContext context, LocalCompactTreeRow row) {
    final song = row.song!;
    final selected = selectedSongIds.contains(song.id);
    final current = song.id == selectedTrackId;
    return TableRow(
      decoration: BoxDecoration(
        color:
            selected || current
                ? LocalPageColors.rowSelected
                : Colors.transparent,
        border: const Border(
          bottom: BorderSide(color: LocalPageColors.rowBorder),
        ),
      ),
      children: [
        TableCell(
          child: Draggable<LocalItemsDragPayload>(
            data: _songDragPayload(song),
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 320,
                child: _treeSongNameCell(context, row, song, selected, current),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.55,
              child: _treeSongNameCell(context, row, song, selected, current),
            ),
            child: GestureDetector(
              onSecondaryTapDown:
                  (details) => onOpenSongMenu(song, details.globalPosition),
              child: InkWell(
                onTap:
                    multiSelect
                        ? () => onToggleSongSelection(song.id)
                        : () => onPlayTrack(song.id, compactQueueSongIds),
                child: _treeSongNameCell(context, row, song, selected, current),
              ),
            ),
          ),
        ),
        _TextLinkCell(
          text: getLocalDisplayArtists(song, i18n),
          onTap:
              () => context.go(
                '/artists?artist=${Uri.encodeQueryComponent(getLocalDisplayArtists(song, i18n))}',
              ),
        ),
        _TextLinkCell(
          text: displayAlbum(song, i18n),
          onTap:
              () => context.go(
                '/albums?album=${Uri.encodeQueryComponent(displayAlbum(song, i18n))}',
              ),
        ),
      ],
    );
  }

  Widget _treeSongNameCell(
    BuildContext context,
    LocalCompactTreeRow row,
    LibrarySong song,
    bool selected,
    bool current,
  ) {
    final playing = current && isPlaying;
    return Padding(
      padding: EdgeInsets.fromLTRB(42 + row.depth * 22.0, 8, 8, 8),
      child: Row(
        children: [
          if (multiSelect) ...[
            _LocalTableCheckMark(selected: selected),
            const SizedBox(width: 10),
          ],
          Icon(
            current
                ? FluentIcons.play_20_regular
                : FluentIcons.music_note_2_20_regular,
            color:
                current
                    ? LocalPageColors.accentStrong
                    : LocalPageColors.artworkIcon,
          ),
          const SizedBox(width: 10),
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
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (!multiSelect)
            _LocalTableActions(
              children: [
                IconButton(
                  tooltip:
                      playing ? i18n.t('player.pause') : i18n.t('context.play'),
                  icon: Icon(
                    playing
                        ? FluentIcons.pause_20_regular
                        : FluentIcons.play_20_regular,
                  ),
                  onPressed:
                      current
                          ? onTogglePlayPause
                          : () => onPlayTrack(song.id, compactQueueSongIds),
                ),
                IconButton(
                  tooltip: i18n.t('context.addToPlaylist'),
                  icon: const Icon(FluentIcons.add_20_regular),
                  onPressed:
                      () => _invokeAtButtonBottom(
                        context,
                        (position) => onAddSong(song, position),
                      ),
                ),
                IconButton(
                  tooltip: i18n.t('context.playNext'),
                  icon: const Icon(FluentIcons.next_20_regular),
                  onPressed: () => onPlayNext(song.id),
                ),
              ],
            ),
        ],
      ),
    );
  }

  TableRow _folderRow(BuildContext context, FolderNode folder) {
    final selected = selectedFolderPaths.contains(folder.relativePath);
    return TableRow(
      decoration: BoxDecoration(
        color: selected ? LocalPageColors.rowSelected : Colors.transparent,
        border: const Border(
          bottom: BorderSide(color: LocalPageColors.rowBorder),
        ),
      ),
      children: [
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: GestureDetector(
            onSecondaryTapDown:
                (details) => onOpenFolderMenu(folder, details.globalPosition),
            child: InkWell(
              onTap:
                  multiSelect
                      ? () => onToggleFolderSelection(folder.relativePath)
                      : () => onOpenFolder(folder.relativePath),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  children: [
                    if (multiSelect) ...[
                      _LocalTableCheckMark(selected: selected),
                      const SizedBox(width: 10),
                    ],
                    const Icon(
                      FluentIcons.folder_20_regular,
                      color: LocalPageColors.artworkIcon,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        folder.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: LocalPageColors.textStrong,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      i18n.t('playlists.songCount', {
                        'count': folder.subtreeSongIds.length,
                      }),
                      style: const TextStyle(color: LocalPageColors.textMuted),
                    ),
                    const Icon(
                      FluentIcons.chevron_right_20_regular,
                      size: 18,
                      color: LocalPageColors.textMuted,
                    ),
                    if (!multiSelect)
                      _LocalTableActions(
                        children: [
                          IconButton(
                            tooltip: i18n.t('local.playAllButtonTooltip'),
                            icon: const Icon(
                              FluentIcons.arrow_shuffle_20_regular,
                            ),
                            onPressed: () => onPlayFolder(folder),
                          ),
                          IconButton(
                            tooltip: i18n.t('context.addToPlaylist'),
                            icon: const Icon(FluentIcons.add_20_regular),
                            onPressed:
                                () => _invokeAtButtonBottom(
                                  context,
                                  (position) => onAddFolder(folder, position),
                                ),
                          ),
                          IconButton(
                            tooltip: i18n.t('local.updateFolder'),
                            icon: const Icon(FluentIcons.arrow_sync_20_regular),
                            onPressed: () => onRefreshFolder(folder),
                          ),
                          IconButton(
                            tooltip: i18n.t('local.searchFolderButtonTooltip'),
                            icon: const Icon(FluentIcons.search_20_regular),
                            onPressed: () => onSearchFolder(folder),
                          ),
                          IconButton(
                            tooltip: i18n.t('local.openLocalButtonTooltip'),
                            icon: const Icon(
                              FluentIcons.folder_open_20_regular,
                            ),
                            onPressed: () => onRevealFolder(folder),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox.shrink(),
        const SizedBox.shrink(),
      ],
    );
  }

  TableRow _songRow(BuildContext context, LibrarySong song) {
    final selected = selectedSongIds.contains(song.id);
    final current = song.id == selectedTrackId;
    final playing = current && isPlaying;
    return TableRow(
      decoration: BoxDecoration(
        color:
            selected || current
                ? LocalPageColors.rowSelected
                : Colors.transparent,
        border: const Border(
          bottom: BorderSide(color: LocalPageColors.rowBorder),
        ),
      ),
      children: [
        TableCell(
          child: GestureDetector(
            onSecondaryTapDown:
                (details) => onOpenSongMenu(song, details.globalPosition),
            child: InkWell(
              onTap:
                  multiSelect
                      ? () => onToggleSongSelection(song.id)
                      : () => onPlayTrack(song.id, queueSongIds),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  children: [
                    if (multiSelect) ...[
                      _LocalTableCheckMark(selected: selected),
                      const SizedBox(width: 10),
                    ],
                    Icon(
                      current
                          ? FluentIcons.play_20_regular
                          : FluentIcons.music_note_2_20_regular,
                      color:
                          current
                              ? LocalPageColors.accentStrong
                              : LocalPageColors.artworkIcon,
                    ),
                    const SizedBox(width: 10),
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!multiSelect)
                      _LocalTableActions(
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
                                    : () => onPlayTrack(song.id, queueSongIds),
                          ),
                          IconButton(
                            tooltip: i18n.t('context.addToPlaylist'),
                            icon: const Icon(FluentIcons.add_20_regular),
                            onPressed:
                                () => _invokeAtButtonBottom(
                                  context,
                                  (position) => onAddSong(song, position),
                                ),
                          ),
                          IconButton(
                            tooltip: i18n.t('context.playNext'),
                            icon: const Icon(FluentIcons.next_20_regular),
                            onPressed: () => onPlayNext(song.id),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _TextLinkCell(
          text: getLocalDisplayArtists(song, i18n),
          onTap:
              () => context.go(
                '/artists?artist=${Uri.encodeQueryComponent(getLocalDisplayArtists(song, i18n))}',
              ),
        ),
        _TextLinkCell(
          text: displayAlbum(song, i18n),
          onTap:
              () => context.go(
                '/albums?album=${Uri.encodeQueryComponent(displayAlbum(song, i18n))}',
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

  LocalItemsDragPayload _songDragPayload(LibrarySong song) {
    final songIds =
        selectedSongIds.contains(song.id)
            ? selectedSongIds.toList()
            : [song.id];
    return LocalItemsDragPayload(songIds: songIds, folderPaths: const []);
  }

  bool _isMoveTargetFolder(
    FolderNode targetFolder,
    LocalItemsDragPayload payload,
  ) {
    return isLocalMoveTargetFolder(
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

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Text(
        text,
        style: const TextStyle(
          color: LocalPageColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TableRowHost extends StatelessWidget {
  const _TableRowHost({required this.row});

  final TableRow row;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.5),
        1: FlexColumnWidth(1.25),
        2: FlexColumnWidth(1.25),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [row],
    );
  }
}

class _TextLinkCell extends StatelessWidget {
  const _TextLinkCell({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: LocalPageColors.accentStrong,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _LocalTableActions extends StatelessWidget {
  const _LocalTableActions({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children:
            children
                .map(
                  (child) => IconTheme(
                    data: const IconThemeData(size: 18),
                    child: SizedBox(width: 34, height: 34, child: child),
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _LocalTableCheckMark extends StatelessWidget {
  const _LocalTableCheckMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

void _invokeAtButtonBottom(BuildContext context, ValueChanged<Offset> action) {
  final box = context.findRenderObject() as RenderBox;
  action(box.localToGlobal(Offset(0, box.size.height + 6)));
}
