import 'package:path/path.dart' as p;
import '../library/data/library_queries.dart';
import '../library/data/library_repository.dart';
import 'music_share_models.dart';

Future<Map<String, dynamic>> sharedDownloadManifest(
  LibraryRepository repository,
  Map<String, String> query,
) async {
  final metadata = await repository.queryLibrary(
    const LibraryDataQuery(LibraryQueryKind.directoryIndex),
  );
  final root = metadata.rootPath;
  final directories = {
    'folders': [
      '',
      for (final folder in metadata.folders)
        if (p.isWithin(root, folder.path))
          p.relative(folder.path, from: root).split(p.separator).join('/'),
    ],
  };
  final selection = query['folder'];
  final selectedSongs = query['songs']?.split(',').map(int.parse).toSet();
  if (selection != null &&
      !(directories['folders'] as List).contains(selection)) {
    throw const MusicShareException('share.fileChanged');
  }
  final songs =
      selection == null
          ? await repository.songReferences(selectedSongs!.toList())
          : await repository.readLocalSongPaths(
            p.joinAll([root, ...selection.split('/')]),
          );
  songs.removeWhere((id, path) => !p.isWithin(root, path));
  if (selectedSongs != null && !selectedSongs.every(songs.containsKey)) {
    throw const MusicShareException('share.fileChanged');
  }
  String relative(String path) =>
      p.relative(path, from: root).split(p.separator).join('/');
  bool includes(String path) =>
      selection == null || selection.isEmpty || path.startsWith('$selection/');
  return {
    'name':
        selection == null
            ? ''
            : selection.isEmpty
            ? p.basename(root)
            : p.posix.basename(selection),
    'folders':
        selection == null
            ? <String>[]
            : [
              for (final folder
                  in (directories['folders'] as List).cast<String>())
                if (folder == selection || includes('$folder/'))
                  selection.isEmpty
                      ? folder
                      : p.posix.relative(folder, from: selection),
            ],
    'files': [
      for (final song in songs.entries)
        if ((selectedSongs == null || selectedSongs.contains(song.key)) &&
            includes(relative(song.value)))
          {
            'song': song.key,
            'path':
                selection == null
                    ? p.basename(song.value)
                    : selection.isEmpty
                    ? relative(song.value)
                    : p.posix.relative(relative(song.value), from: selection),
          },
    ],
  };
}
