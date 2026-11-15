import 'package:path/path.dart' as p;
import '../library/data/library_queries.dart';
import '../library/data/library_repository.dart';

Future<Map<String, dynamic>> readSharedDirectoryIndex(
  LibraryRepository repository,
) async {
  final data = await repository.queryLibrary(
    const LibraryDataQuery(LibraryQueryKind.directoryIndex),
  );
  final root = data.rootPath;
  String relative(String path) =>
      p.relative(path, from: root).split(p.separator).join('/');
  final folders = data.folders.toList()..sort((a, b) => a.id.compareTo(b.id));
  return {
    'rootName': p.basename(root),
    'folders': [
      '',
      for (final folder in folders)
        if (p.isWithin(root, folder.path)) relative(folder.path),
    ],
    'folderInfo': {
      for (final folder in folders)
        if (folder.path == root || p.isWithin(root, folder.path))
          folder.path == root ? '' : relative(folder.path): {
            'id': folder.id,
            'criterion': folder.criterion,
          },
    },
  };
}
