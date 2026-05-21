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
    required this.childFolders,
    required this.currentSongs,
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
    required this.i18n,
    required this.onToggleFoldersExpanded,
    required this.onToggleSongsExpanded,
    required this.onPlayFolder,
    required this.onAddFolder,
    required this.onRefreshFolder,
    required this.onSearchFolder,
    required this.onRevealFolder,
    required this.onOpenFolder,
    required this.onOpenFolderMenu,
    required this.onToggleFolderSelection,
    required this.onPlayTrack,
    required this.onTogglePlayPause,
    required this.onToggleSongSelection,
    required this.onPlayNext,
    required this.onAddSong,
    required this.onOpenSongMenu,
    required this.onJumpToSongKey,
  });

  final List<FolderNode> childFolders;
  final List<LibrarySong> currentSongs;
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
  final SmPlayerI18n i18n;
  final VoidCallback onToggleFoldersExpanded;
  final VoidCallback onToggleSongsExpanded;
  final ValueChanged<FolderNode> onPlayFolder;
  final ValueChanged<FolderNode> onAddFolder;
  final ValueChanged<FolderNode> onRefreshFolder;
  final ValueChanged<FolderNode> onSearchFolder;
  final ValueChanged<FolderNode> onRevealFolder;
  final ValueChanged<String> onOpenFolder;
  final void Function(FolderNode folder, Offset position) onOpenFolderMenu;
  final ValueChanged<String> onToggleFolderSelection;
  final void Function(int trackId, List<int> queueSongIds) onPlayTrack;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<int> onToggleSongSelection;
  final ValueChanged<int> onPlayNext;
  final ValueChanged<LibrarySong> onAddSong;
  final void Function(LibrarySong song, Offset position) onOpenSongMenu;
  final ValueChanged<String> onJumpToSongKey;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.5),
        1: FlexColumnWidth(1.25),
        2: FlexColumnWidth(1.25),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _headerRow(),
        if (showLocalSectionHeaders && childFolders.isNotEmpty)
          _sectionRow(
            title: i18n.t('common.folders'),
            count: childFolders.length,
            expanded: foldersExpanded,
            onToggle: onToggleFoldersExpanded,
          ),
        if (!showLocalSectionHeaders || foldersExpanded)
          for (final folder in childFolders) _folderRow(context, folder),
        if (showLocalSectionHeaders && currentSongs.isNotEmpty)
          _sectionRow(
            title: i18n.t('local.allSongs'),
            count: currentSongs.length,
            expanded: songsExpanded,
            onToggle: onToggleSongsExpanded,
          ),
        if ((!showLocalSectionHeaders || songsExpanded) && showSongQuickJump)
          TableRow(
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
          ),
        if (!showLocalSectionHeaders || songsExpanded)
          for (final song in currentSongs) _songRow(context, song),
      ],
    );
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
                            onPressed: () => onAddFolder(folder),
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
                            onPressed: () => onAddSong(song),
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
