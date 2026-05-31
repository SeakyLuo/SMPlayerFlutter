import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import 'artists_page_model.dart' show displayAlbum, getSongArtists;
import 'local_folder_model.dart';

String getFolderListItemKey(String folderPath) {
  return 'folder:$folderPath';
}

String getSongListItemKey(int songId) {
  return 'song:$songId';
}

bool areSetsEqual<T>(Set<T> left, Set<T> right) {
  return left.length == right.length && left.every(right.contains);
}

String getRefreshResultMessage(
  LocalFolderRefreshResult result,
  SmPlayerI18n i18n,
) {
  final messages = [
    if (result.filesAdded.isNotEmpty)
      _getRefreshChangeMessage(
        result.filesAdded,
        'local.refreshAddedOne',
        'local.refreshAddedMultiple',
        i18n,
      ),
    if (result.filesRemoved.isNotEmpty)
      _getRefreshChangeMessage(
        result.filesRemoved,
        'local.refreshRemovedOne',
        'local.refreshRemovedMultiple',
        i18n,
      ),
    if (result.filesMoved.isNotEmpty)
      _getRefreshChangeMessage(
        result.filesMoved,
        'local.refreshMovedOne',
        'local.refreshMovedMultiple',
        i18n,
      ),
    if (result.artistSplitsApplied.isNotEmpty)
      i18n.t('local.refreshArtistSplitsAppliedGroup', {
        'count': result.artistSplitsApplied.length,
      }),
    if (result.artistSplitSuggestions.isNotEmpty)
      i18n.t('local.refreshArtistSplitSuggestionsGroup', {
        'count': result.artistSplitSuggestions.length,
      }),
    if (result.artistMergeSuggestions.isNotEmpty)
      i18n.t('local.refreshArtistMergeSuggestionsGroup', {
        'count': result.artistMergeSuggestions.length,
      }),
  ];
  return messages.isEmpty
      ? i18n.t('local.refreshNoChange')
      : messages.join(i18n.t('common.comma'));
}

String getRefreshFolderErrorMessage(String error, SmPlayerI18n i18n) {
  const notFoundPrefix = 'Folder not found: ';
  const accessDeniedPrefix = 'Cannot access folder: ';
  if (error.startsWith(notFoundPrefix)) {
    return i18n.t('local.updateFolderNotFound', {
      'path': error.substring(notFoundPrefix.length),
    });
  }
  if (error.startsWith(accessDeniedPrefix)) {
    return i18n.t('local.updateFolderAccessDenied', {
      'path': error.substring(accessDeniedPrefix.length),
    });
  }

  return error;
}

String _getRefreshChangeMessage(
  List<String> paths,
  String singleKey,
  String multipleKey,
  SmPlayerI18n i18n,
) {
  return paths.length == 1
      ? i18n.t(singleKey, {'name': _getFileTitle(paths.single)})
      : i18n.t(multipleKey, {'count': paths.length});
}

String _getFileTitle(String filePath) {
  final fileName = normalizePath(filePath).split('/').last;
  final extensionIndex = fileName.lastIndexOf('.');
  return extensionIndex > 0 ? fileName.substring(0, extensionIndex) : fileName;
}

bool hasRefreshResultChanges(LocalFolderRefreshResult result) {
  return result.hasChanges;
}

enum LocalCompactTreeRowType { folder, song }

class LocalCompactTreeRow {
  const LocalCompactTreeRow.folder({
    required this.key,
    required FolderNode this.folder,
    required this.depth,
    required this.expanded,
    required this.expandable,
  }) : type = LocalCompactTreeRowType.folder,
       song = null,
       songIndex = null;

  const LocalCompactTreeRow.song({
    required this.key,
    required LibrarySong this.song,
    required this.depth,
    required int this.songIndex,
  }) : type = LocalCompactTreeRowType.song,
       folder = null,
       expanded = false,
       expandable = false;

  final String key;
  final LocalCompactTreeRowType type;
  final FolderNode? folder;
  final LibrarySong? song;
  final int depth;
  final bool expanded;
  final bool expandable;
  final int? songIndex;
}

List<LocalCompactTreeRow> buildLocalCompactFolderTreeRows({
  required List<FolderNode> childFolders,
  required Map<String, FolderNode> nodes,
  required Map<int, LibrarySong> songsById,
  required Set<String> expandedFolderPaths,
  required LocalSortMode sortMode,
  required String searchQuery,
}) {
  final rows = <LocalCompactTreeRow>[];
  var songIndex = 0;
  final normalizedSearchQuery = searchQuery.trim().toLowerCase();

  void appendFolder(FolderNode folder, int depth) {
    final nestedFolders = sortFolders(
      folder.childPaths
          .map((childPath) => nodes[childPath]!)
          .where(
            (child) =>
                normalizedSearchQuery.isEmpty ||
                child.name.toLowerCase().contains(normalizedSearchQuery),
          )
          .toList(),
    );
    final nestedSongs = sortSongs(
      folder.directSongIds
          .map((songId) => songsById[songId]!)
          .where((song) => matchesSongSearch(song, searchQuery))
          .toList(),
      sortMode,
      localSortModeFromCriterion(folder.criterion),
    );
    final expanded = expandedFolderPaths.contains(folder.relativePath);
    final expandable = nestedFolders.isNotEmpty || nestedSongs.isNotEmpty;

    rows.add(
      LocalCompactTreeRow.folder(
        key: 'folder:${folder.relativePath}',
        folder: folder,
        depth: depth,
        expanded: expanded,
        expandable: expandable,
      ),
    );

    if (!expanded) {
      return;
    }

    for (final childFolder in nestedFolders) {
      appendFolder(childFolder, depth + 1);
    }
    for (final song in nestedSongs) {
      rows.add(
        LocalCompactTreeRow.song(
          key: 'song:${folder.relativePath}:${song.id}',
          song: song,
          depth: depth + 1,
          songIndex: songIndex,
        ),
      );
      songIndex += 1;
    }
  }

  for (final folder in childFolders) {
    appendFolder(folder, 0);
  }

  return rows;
}

String? getLocalSongDetailLabel(
  LibrarySong song,
  LocalSortMode sortMode,
  LocalSortMode currentSortMode,
  SmPlayerI18n i18n,
) {
  final effectiveSortMode =
      sortMode == LocalSortMode.reverse ? currentSortMode : sortMode;

  if (effectiveSortMode == LocalSortMode.album) {
    return '${getLocalDisplayArtists(song, i18n)} · ${displayAlbum(song, i18n)}';
  }

  return null;
}

String getLocalDisplayArtists(LibrarySong song, SmPlayerI18n i18n) {
  final artists = getSongArtists(song);
  return artists.isEmpty
      ? i18n.t('common.artistUnknown')
      : artists.join(i18n.t('common.artistSeparator'));
}

bool isLocalMoveTargetFolder({
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
    return normalizePath(_fileParentPath(songsById[songId]!.path)) ==
        targetPathKey;
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

String _fileParentPath(String filePath) {
  final normalized = normalizePath(filePath);
  final separatorIndex = normalized.lastIndexOf('/');
  return separatorIndex < 0 ? '' : normalized.substring(0, separatorIndex);
}
