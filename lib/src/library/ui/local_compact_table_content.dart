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
                      onPressed: () => onRefreshFolder(folder),
                    ),
                    IconButton(
                      tooltip: i18n.t('local.searchFolderButtonTooltip'),
                      icon: const Icon(FluentIcons.search_20_regular),
                      onPressed: () => onSearchFolder(folder),
                    ),
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

class _FolderRowSurface extends StatelessWidget {
  const _FolderRowSurface({
    required this.folder,
    required this.treeRow,
    required this.selected,
    required this.multiSelect,
    required this.i18n,
    required this.onToggleTreeFolderExpanded,
    required this.actions,
  });

  final FolderNode folder;
  final LocalCompactTreeRow? treeRow;
  final bool selected;
  final bool multiSelect;
  final SmPlayerI18n i18n;
  final ValueChanged<String> onToggleTreeFolderExpanded;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.fromLTRB(14 + (treeRow?.depth ?? 0) * 22.0, 0, 14, 0),
      decoration: BoxDecoration(
        color: selected ? colors.rowSelected : colors.panel,
        border: Border.all(color: colors.borderSubtle),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: colors.cardShadow,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          if (treeRow != null)
            SizedBox(
              width: 24,
              height: 24,
              child:
                  treeRow!.expandable
                      ? IconButton(
                        tooltip: folder.name,
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        color: colors.textMuted,
                        icon: Icon(
                          treeRow!.expanded
                              ? FluentIcons.chevron_down_20_regular
                              : FluentIcons.chevron_right_20_regular,
                        ),
                        onPressed:
                            () =>
                                onToggleTreeFolderExpanded(folder.relativePath),
                      )
                      : null,
            ),
          if (multiSelect) ...[
            _CompactTableCheckMark(selected: selected),
            const SizedBox(width: 10),
          ],
          const _CompactTableTypeImage(assetPath: 'assets/branding/folder.png'),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              folder.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            i18n.t('playlists.songCount', {
              'count':
                  treeRow == null
                      ? folder.directSongIds.length
                      : folder.subtreeSongIds.length,
            }),
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Icon(
            FluentIcons.chevron_right_20_regular,
            size: 17,
            color: colors.textMuted,
          ),
          actions,
        ],
      ),
    );
  }
}

class _SongRowSurface extends StatelessWidget {
  const _SongRowSurface({
    required this.song,
    required this.depth,
    required this.selected,
    required this.current,
    required this.multiSelect,
    required this.i18n,
    required this.actions,
  });

  final LibrarySong song;
  final int depth;
  final bool selected;
  final bool current;
  final bool multiSelect;
  final SmPlayerI18n i18n;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: EdgeInsets.fromLTRB(10 + depth * 22.0, 8, 8, 8),
      decoration: BoxDecoration(
        color: selected || current ? colors.rowSelected : Colors.transparent,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 24,
            child: Row(
              children: [
                if (multiSelect) ...[
                  _CompactTableCheckMark(selected: selected),
                  const SizedBox(width: 10),
                ],
                current
                    ? Icon(
                      FluentIcons.play_20_regular,
                      color: colors.accentStrong,
                      size: 18,
                    )
                    : const _CompactTableTypeImage(
                      assetPath: 'assets/branding/colorful_no_bg.png',
                    ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: current ? colors.accentStrong : colors.textStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                actions,
              ],
            ),
          ),
          _SongMetaLine(text: getLocalDisplayArtists(song, i18n)),
          _SongMetaLine(text: displayAlbum(song, i18n)),
        ],
      ),
    );
  }
}

class _SongMetaLine extends StatelessWidget {
  const _SongMetaLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    return SizedBox(
      height: 18,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.textMuted, fontSize: 13),
        ),
      ),
    );
  }
}

class _CompactTableActions extends StatelessWidget {
  const _CompactTableActions({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final visible = _CompactHoverState.of(context);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.ease,
        child: SizedBox(
          height: 24,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children:
                children
                    .map(
                      (child) => IconTheme(
                        data: const IconThemeData(size: 14),
                        child: SizedBox.square(dimension: 24, child: child),
                      ),
                    )
                    .toList(),
          ),
        ),
      ),
    );
  }
}

class _CompactHoverRow extends StatefulWidget {
  const _CompactHoverRow({required this.child, this.onOpenContextMenu});

  final Widget child;
  final FutureOr<void> Function(Offset)? onOpenContextMenu;

  @override
  State<_CompactHoverRow> createState() => _CompactHoverRowState();
}

class _CompactHoverRowState extends State<_CompactHoverRow> {
  var _hovered = false;
  var _focused = false;
  var _contextMenuOpen = false;

  Future<void> _openContextMenu(Offset position) async {
    setState(() => _contextMenuOpen = true);
    try {
      await widget.onOpenContextMenu!(position);
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _contextMenuOpen = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onSecondaryTapDown:
            widget.onOpenContextMenu == null
                ? null
                : (details) =>
                    unawaited(_openContextMenu(details.globalPosition)),
        child: Focus(
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: _CompactHoverState(
            visible: _hovered || _focused || _contextMenuOpen,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _CompactHoverState extends InheritedWidget {
  const _CompactHoverState({required this.visible, required super.child});

  final bool visible;

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_CompactHoverState>()
            ?.visible ??
        false;
  }

  @override
  bool updateShouldNotify(_CompactHoverState oldWidget) {
    return visible != oldWidget.visible;
  }
}

class _CompactTableTypeImage extends StatelessWidget {
  const _CompactTableTypeImage({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 24,
      child: Image.asset(assetPath, fit: BoxFit.contain),
    );
  }
}

class _CompactTableCheckMark extends StatelessWidget {
  const _CompactTableCheckMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = LocalPageColors.of(context);
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: selected ? colors.accentStrong : colors.selectionMark,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: selected ? colors.accentStrong : colors.selectionBorder,
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
