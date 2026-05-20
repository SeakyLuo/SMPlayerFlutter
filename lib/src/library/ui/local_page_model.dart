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
