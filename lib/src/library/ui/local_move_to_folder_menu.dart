import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';

import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import 'local_folder_model.dart';
import 'menu_flyout.dart';
import 'menu_flyout_helpers.dart';

MenuFlyoutItem? buildLocalMoveToFolderMenuItem({
  required Map<String, FolderNode> nodes,
  required Map<int, LibrarySong> songsById,
  required List<int> songIds,
  required List<String> folderPaths,
  required SmPlayerI18n i18n,
  String key = 'move-to-folder',
  required ValueChanged<FolderNode> onMoveToFolder,
}) {
  final moveItems = buildLocalMoveToFolderMenuItems(
    nodes: nodes,
    songsById: songsById,
    songIds: songIds,
    folderPaths: folderPaths,
    i18n: i18n,
    onMoveToFolder: onMoveToFolder,
  );
  if (moveItems.isEmpty) {
    return null;
  }

  return MenuFlyoutItem(
    key: key,
    text: i18n.t('context.moveToFolder'),
    icon: FluentIcons.folder_20_regular,
    submenu: moveItems,
  );
}

List<MenuFlyoutItem> buildLocalMoveToFolderMenuItems({
  required Map<String, FolderNode> nodes,
  required Map<int, LibrarySong> songsById,
  required List<int> songIds,
  required List<String> folderPaths,
  required SmPlayerI18n i18n,
  required ValueChanged<FolderNode> onMoveToFolder,
}) {
  final nodesByAbsolutePath = {
    for (final node in nodes.values) normalizePath(node.path): node,
  };
  final songParentPaths =
      songIds
          .map(
            (songId) => normalizePath(
              getLocalAbsoluteParentPath(songsById[songId]!.path),
            ),
          )
          .toSet();
  final sourceFolders =
      folderPaths
          .map((folderPath) => nodesByAbsolutePath[normalizePath(folderPath)]!)
          .toList();

  bool isTargetFolder(FolderNode folder) {
    if (songParentPaths.contains(normalizePath(folder.path))) {
      return false;
    }

    return sourceFolders.every(
      (sourceFolder) =>
          folder.relativePath != sourceFolder.relativePath &&
          (folder.relativePath.isEmpty ||
              !folder.relativePath.startsWith('${sourceFolder.relativePath}/')),
    );
  }

  String folderMenuText(FolderNode folder) {
    return folder.name.isEmpty ? i18n.t('local.libraryRoot') : folder.name;
  }

  MenuFlyoutItem targetItem(FolderNode folder) {
    return MenuFlyoutItem(
      key:
          'move-folder-${folder.relativePath.isEmpty ? 'root' : folder.relativePath}-target',
      text: folderMenuText(folder),
      onPressed: () => onMoveToFolder(folder),
    );
  }

  MenuFlyoutItem? treeItem(FolderNode folder) {
    final childItems = [
      for (final childPath in folder.childPaths)
        if (treeItem(nodes[childPath]!) case final item?) item,
    ];
    if (childItems.isEmpty) {
      return isTargetFolder(folder) ? targetItem(folder) : null;
    }

    return MenuFlyoutItem(
      key:
          'move-folder-${folder.relativePath.isEmpty ? 'root' : folder.relativePath}',
      text: folderMenuText(folder),
      submenu:
          isTargetFolder(folder)
              ? [
                targetItem(folder),
                MenuFlyoutItem.separator(
                  key:
                      'move-folder-${folder.relativePath.isEmpty ? 'root' : folder.relativePath}-separator',
                ),
                ...childItems,
              ]
              : childItems,
    );
  }

  final rootItem = treeItem(nodes['']!);
  if (rootItem == null) {
    return const [];
  }
  return rootItem.submenu.isEmpty ? [rootItem] : rootItem.submenu;
}

String getLocalAbsoluteParentPath(String filePath) {
  final windowsIndex = filePath.lastIndexOf('\\');
  final unixIndex = filePath.lastIndexOf('/');
  final index = windowsIndex > unixIndex ? windowsIndex : unixIndex;
  return index < 0 ? '' : filePath.substring(0, index);
}

List<MenuFlyoutFolder> buildLocalMenuFolders(List<LibraryFolder> folders) {
  return folders
      .map(
        (folder) => MenuFlyoutFolder(
          id: folder.id,
          name: getLocalDisplayFolderName(folder.path),
          path: folder.path,
          parentId: folder.parentId,
        ),
      )
      .toList();
}

String getLocalDisplayFolderName(String path) {
  final segments = normalizePath(path).split('/');
  return segments.isEmpty ? path : segments.last;
}
