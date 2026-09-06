import 'package:flutter/foundation.dart';

import '../data/library_models.dart';
import '../data/library_providers.dart';
import 'local_folder_model.dart';

class LibraryPageDataCache {
  (LibraryContentData, Map<int, LibrarySong>)? _songsKey;
  late LibraryContentData _songsSnapshot;
  (LibraryContentData, Map<int, LibraryPlaylist>, Set<int>, List<int>?)?
  _pageKey;
  late LibraryContentData _pageSnapshot;
  (List<LibrarySong>, List<LibraryFolder>, String)? _folderKey;
  Set<String> _createdFolders = const {};
  late FolderIndex _folderIndex;

  LibraryContentData snapshot(
    LibraryContentData source,
    Map<int, LibrarySong> songs,
    Map<int, LibraryPlaylist> playlists,
    Set<int> deletedPlaylists,
    List<int>? playlistOrder,
  ) {
    final songsKey = (source, songs);
    if (_songsKey != songsKey) {
      _songsSnapshot = applyLibraryFavoriteOverrides(source, const {}, songs);
      _songsKey = songsKey;
    }
    final pageKey = (
      _songsSnapshot,
      playlists,
      deletedPlaylists,
      playlistOrder,
    );
    if (_pageKey != pageKey) {
      _pageSnapshot = applyLibraryFavoriteOverrides(
        _songsSnapshot,
        const {},
        const {},
        playlists,
        deletedPlaylists,
        playlistOrder,
      );
      _pageKey = pageKey;
    }
    return _pageSnapshot;
  }

  FolderIndex folders(
    LibraryContentData snapshot, {
    Set<String> created = const {},
  }) {
    final key = (snapshot.songs, snapshot.folders, snapshot.rootPath);
    if (_folderKey != key || !setEquals(_createdFolders, created)) {
      final index = buildFolderIndex(
        snapshot.songs,
        snapshot.folders,
        snapshot.rootPath,
      );
      final nodes = index.nodes;
      for (final path in created) {
        final folder = nodes.putIfAbsent(
          path,
          () => createFolderNode(path, snapshot.rootPath),
        );
        final parentPath = getParentPath(folder.relativePath);
        final parent = nodes.putIfAbsent(
          parentPath,
          () => createFolderNode(parentPath, snapshot.rootPath),
        );
        if (!parent.childPaths.contains(folder.relativePath)) {
          parent.childPaths.add(folder.relativePath);
        }
      }
      if (created.isNotEmpty) {
        for (final node in nodes.values) {
          node.childPaths.sort(
            (left, right) =>
                compareLocalText(nodes[left]!.name, nodes[right]!.name),
          );
        }
      }
      _folderIndex = index;
      _folderKey = key;
      _createdFolders = Set.of(created);
    }
    return _folderIndex;
  }
}
