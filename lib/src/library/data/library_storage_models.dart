part of 'library_models.dart';

class LibraryStorageChange {
  const LibraryStorageChange({
    required this.source,
    required this.count,
    required this.undo,
    required this.commit,
  });
  final LibrarySource source;
  final int count;
  final Future<void> Function() undo;
  final Future<void> Function() commit;
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
