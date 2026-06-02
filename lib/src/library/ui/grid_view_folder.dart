import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import 'local_folder_card.dart';
import 'local_folder_model.dart';
import 'local_view_shared.dart';

class LocalGridViewFolder extends StatelessWidget {
  const LocalGridViewFolder({
    super.key,
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

  @override
  Widget build(BuildContext context) {
    if (isCompactLayout) {
      return LocalCompactListPanel(
        child: Column(
          children: [
            for (var index = 0; index < childFolders.length; index += 1)
              LocalCompactPanelRow(
                last: index == childFolders.length - 1,
                child: DraggableLocalFolderCard(
                  folder: childFolders[index],
                  selected: selectedFolderPaths.contains(
                    childFolders[index].relativePath,
                  ),
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
                  dragPayload: _folderDragPayload(childFolders[index]),
                  onWillAcceptDrop: _isMoveTargetFolder,
                  onAcceptDrop: _moveDraggedItems,
                ),
              ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 30,
      runSpacing: 26,
      children: [
        for (final folder in childFolders)
          DraggableLocalFolderCard(
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

class DraggableLocalFolderCard extends StatelessWidget {
  const DraggableLocalFolderCard({
    super.key,
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
  final void Function(FolderNode folder, Offset position) onAddFolder;
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
    return normalizePath(fileParentPath(songPath)) == targetPathKey;
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

String fileParentPath(String filePath) {
  final normalized = normalizePath(filePath);
  final separatorIndex = normalized.lastIndexOf('/');
  return separatorIndex < 0 ? '' : normalized.substring(0, separatorIndex);
}
