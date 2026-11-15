part of 'local_table_content.dart';

extension _LocalTableDragActions on LocalTableContent {
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
