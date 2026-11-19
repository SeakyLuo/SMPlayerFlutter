part of 'library_models.dart';

class LibraryStorageChange {
  const LibraryStorageChange({
    required this.source,
    required this.count,
    required this.undo,
    required this.commit,
    this.deletedSongIds = const {},
    this.deletedSongPaths = const {},
    this.localMove,
    this.overwrittenSongPaths = const {},
    this.directoryOnly = false,
  });
  final LibrarySource source;
  final int count;
  final Future<void> Function() undo;
  final Future<void> Function() commit;
  final Set<int> deletedSongIds;
  final Set<String> deletedSongPaths;
  final LocalItemsMoveResult? localMove;
  final Set<String> overwrittenSongPaths;
  final bool directoryOnly;
}

class LibraryStorageFolder {
  const LibraryStorageFolder({
    required this.id,
    required this.name,
    required this.path,
    required this.parentId,
  });
  final int id;
  final String name;
  final String path;
  final int parentId;
}

class LibraryStorageFolders {
  const LibraryStorageFolders({
    required this.folders,
    required this.songParentPath,
  });
  final List<LibraryStorageFolder> folders;
  final String songParentPath;
}
