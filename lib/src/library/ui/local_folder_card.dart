import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import 'local_folder_model.dart';
import 'local_page_quick_jump.dart';

class LocalFolderCard extends StatelessWidget {
  const LocalFolderCard({
    super.key,
    required this.folder,
    required this.selected,
    required this.multiSelect,
    required this.nodes,
    required this.songsById,
    required this.i18n,
    this.variant = LocalFolderCardVariant.grid,
    this.treeExpanded,
    this.treeExpandable = false,
    this.onToggleTreeExpanded,
    required this.onPlayFolder,
    required this.onAddFolder,
    required this.onRefreshFolder,
    required this.onSearchFolder,
    required this.onRevealFolder,
    required this.onOpenFolder,
    required this.onOpenFolderMenu,
    required this.onToggleSelection,
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

  @override
  Widget build(BuildContext context) {
    if (variant == LocalFolderCardVariant.list) {
      return _buildListCard();
    }

    return _buildGridCard();
  }

  Widget _buildGridCard() {
    return GestureDetector(
      onSecondaryTapDown:
          (details) => onOpenFolderMenu(folder, details.globalPosition),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap:
            multiSelect ? () => onToggleSelection(folder.relativePath) : _open,
        child: Container(
          width: 180,
          constraints: const BoxConstraints(minHeight: 232),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:
                selected
                    ? LocalPageColors.surfaceCardHover
                    : LocalPageColors.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            boxShadow:
                selected
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
                  _FolderArtwork(folder: folder, songsById: songsById),
                  if (multiSelect)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _LocalCheckMark(selected: selected),
                    ),
                  if (!multiSelect)
                    Positioned.fill(
                      child: _FolderCardActions(
                        folder: folder,
                        i18n: i18n,
                        onPlayFolder: onPlayFolder,
                        onAddFolder: onAddFolder,
                      ),
                    ),
                  const Positioned(
                    right: 7,
                    bottom: 7,
                    child: _FolderTypeBadge(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LocalPageColors.textStrong,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _folderInfo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LocalPageColors.textMuted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListCard() {
    return GestureDetector(
      onSecondaryTapDown:
          (details) => onOpenFolderMenu(folder, details.globalPosition),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap:
            multiSelect ? () => onToggleSelection(folder.relativePath) : _open,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color:
                selected ? LocalPageColors.rowSelected : LocalPageColors.panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: LocalPageColors.rowBorder),
          ),
          child: Row(
            children: [
              if (onToggleTreeExpanded != null)
                IconButton(
                  tooltip: folder.name,
                  visualDensity: VisualDensity.compact,
                  onPressed: treeExpandable ? onToggleTreeExpanded : null,
                  icon: Icon(
                    treeExpandable && treeExpanded == true
                        ? FluentIcons.chevron_down_20_regular
                        : FluentIcons.chevron_right_20_regular,
                    size: 18,
                  ),
                ),
              if (multiSelect) ...[
                _LocalCheckMark(selected: selected),
                const SizedBox(width: 10),
              ],
              const _FolderTypeBadge(size: 34, iconSize: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  folder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: LocalPageColors.textStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _folderInfo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LocalPageColors.textMuted,
                  fontSize: 12,
                ),
              ),
              if (!multiSelect) ...[
                const SizedBox(width: 8),
                _LocalIconAction(
                  tooltip: i18n.t('local.gridFolderPlayInfo', {
                    'name': folder.name,
                  }),
                  icon: FluentIcons.play_20_regular,
                  onPressed: () => onPlayFolder(folder),
                ),
                _LocalIconAction(
                  tooltip: i18n.t('context.addToPlaylist'),
                  icon: FluentIcons.add_20_regular,
                  onPressed:
                      folder.subtreeSongIds.isEmpty
                          ? null
                          : () => onAddFolder(folder),
                ),
                _LocalIconAction(
                  tooltip: i18n.t('local.updateFolder'),
                  icon: FluentIcons.arrow_sync_20_regular,
                  onPressed: () => onRefreshFolder(folder),
                ),
                _LocalIconAction(
                  tooltip: i18n.t('local.searchFolderButtonTooltip'),
                  icon: FluentIcons.search_20_regular,
                  onPressed: () => onSearchFolder(folder),
                ),
                _LocalIconAction(
                  tooltip: i18n.t('local.openLocalButtonTooltip'),
                  icon: FluentIcons.folder_open_20_regular,
                  onPressed: () => onRevealFolder(folder),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String get _folderInfo {
    if (folder.childPaths.isNotEmpty) {
      return i18n.t('local.folderCardStats', {
        'folders': folder.childPaths.length,
        'songs': folder.directSongIds.length,
      });
    }

    return i18n.t('local.folderSongsShort', {
      'count': folder.directSongIds.length,
    });
  }

  void _open() {
    onOpenFolder(folder.relativePath);
  }
}

enum LocalFolderCardVariant { grid, list }

class _FolderArtwork extends StatelessWidget {
  const _FolderArtwork({required this.folder, required this.songsById});

  final FolderNode folder;
  final Map<int, LibrarySong> songsById;

  @override
  Widget build(BuildContext context) {
    final thumbnailPaths =
        folder.thumbnailSubtreeSongIds
            .map((songId) => songsById[songId]!.thumbnailPath)
            .where((path) => path.isNotEmpty)
            .take(4)
            .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: 160,
        child:
            thumbnailPaths.isEmpty
                ? const DecoratedBox(
                  decoration: BoxDecoration(color: LocalPageColors.artwork),
                  child: Icon(
                    FluentIcons.folder_48_regular,
                    color: LocalPageColors.artworkIcon,
                    size: 48,
                  ),
                )
                : GridView.count(
                  crossAxisCount: thumbnailPaths.length == 1 ? 1 : 2,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    for (final path in thumbnailPaths)
                      Image.file(File(path), fit: BoxFit.cover),
                  ],
                ),
      ),
    );
  }
}

class _FolderCardActions extends StatelessWidget {
  const _FolderCardActions({
    required this.folder,
    required this.i18n,
    required this.onPlayFolder,
    required this.onAddFolder,
  });

  final FolderNode folder;
  final SmPlayerI18n i18n;
  final ValueChanged<FolderNode> onPlayFolder;
  final ValueChanged<FolderNode> onAddFolder;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundAction(
            tooltip: i18n.t('local.gridFolderPlayInfo', {'name': folder.name}),
            icon: FluentIcons.play_20_regular,
            onPressed:
                folder.subtreeSongIds.isEmpty
                    ? null
                    : () => onPlayFolder(folder),
          ),
          const SizedBox(width: 10),
          _RoundAction(
            tooltip: i18n.t('context.addToPlaylist'),
            icon: FluentIcons.add_20_regular,
            onPressed:
                folder.subtreeSongIds.isEmpty
                    ? null
                    : () => onAddFolder(folder),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        style: IconButton.styleFrom(
          fixedSize: const Size(48, 48),
          backgroundColor: const Color(0xb81e2228),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0x521e2228),
          disabledForegroundColor: Colors.white54,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
      ),
    );
  }
}

class _LocalIconAction extends StatelessWidget {
  const _LocalIconAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 18),
      onPressed: onPressed,
    );
  }
}

class _FolderTypeBadge extends StatelessWidget {
  const _FolderTypeBadge({this.size = 32, this.iconSize = 20});

  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xedffffff),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1f1f2a38),
            offset: Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      ),
      child: Icon(
        FluentIcons.folder_20_regular,
        color: LocalPageColors.accentStrong,
        size: iconSize,
      ),
    );
  }
}

class _LocalCheckMark extends StatelessWidget {
  const _LocalCheckMark({required this.selected});

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
