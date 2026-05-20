import 'dart:math';

import '../../i18n/app_i18n.dart';
import '../data/library_models.dart';
import 'artists_page_model.dart';

typedef LocalSortMode = LocalFolderSortCriterion;

class FolderNode {
  FolderNode({
    required this.id,
    required this.relativePath,
    required this.path,
    required this.name,
    required this.childPaths,
    required this.directSongIds,
    required this.subtreeSongIds,
    required this.thumbnailChildPaths,
    required this.thumbnailDirectSongIds,
    required this.thumbnailSubtreeSongIds,
    required this.criterion,
  });

  int id;
  final String relativePath;
  final String path;
  final String name;
  final List<String> childPaths;
  final List<int> directSongIds;
  List<int> subtreeSongIds;
  List<String> thumbnailChildPaths;
  List<int> thumbnailDirectSongIds;
  List<int> thumbnailSubtreeSongIds;
  int criterion;
}

class FolderChainItem {
  const FolderChainItem({
    required this.name,
    required this.path,
    required this.isLastItem,
    required this.isCurrentItem,
    required this.children,
  });

  final String name;
  final String path;
  final bool isLastItem;
  final bool isCurrentItem;
  final List<FolderChainChildItem> children;
}

class FolderChainChildItem {
  const FolderChainChildItem({
    required this.name,
    required this.path,
    required this.isHighlighted,
  });

  final String name;
  final String path;
  final bool isHighlighted;
}

class FolderIndex {
  const FolderIndex({required this.nodes, required this.songsById});

  final Map<String, FolderNode> nodes;
  final Map<int, LibrarySong> songsById;
}

String normalizePath(String value) {
  return value.replaceAll('\\', '/').replaceFirst(RegExp(r'/+$'), '');
}

String getSongFolderRelativePath(String songPath, String rootPath) {
  final normalizedSongPath = normalizePath(songPath);
  final normalizedRootPath = normalizePath(rootPath);
  final relativePath =
      normalizedSongPath.startsWith('$normalizedRootPath/')
          ? normalizedSongPath.substring(normalizedRootPath.length + 1)
          : normalizedSongPath;
  final segments =
      relativePath.split('/').where((segment) => segment.isNotEmpty).toList();

  if (segments.length <= 1) {
    return '';
  }

  return segments.take(segments.length - 1).join('/');
}

FolderNode createFolderNode(String relativePath, String rootPath) {
  return FolderNode(
    id: 0,
    relativePath: relativePath,
    path: _getFolderAbsolutePath(relativePath, rootPath),
    name: _getFolderDisplayName(relativePath, rootPath),
    childPaths: [],
    directSongIds: [],
    subtreeSongIds: [],
    thumbnailChildPaths: [],
    thumbnailDirectSongIds: [],
    thumbnailSubtreeSongIds: [],
    criterion: 0,
  );
}

String getParentPath(String relativePath) {
  final parts =
      relativePath.split('/').where((segment) => segment.isNotEmpty).toList();
  return parts.take(parts.length - 1).join('/');
}

FolderIndex buildFolderIndex(
  List<LibrarySong> songs,
  List<LibraryFolder> folders,
  String rootPath,
) {
  final nodes = <String, FolderNode>{};
  final songsById = {for (final song in songs) song.id: song};

  nodes[''] = createFolderNode('', rootPath);

  for (final folder in folders) {
    final relativePath = _getFolderRelativePath(folder.path, rootPath);
    nodes.putIfAbsent(
      relativePath,
      () => createFolderNode(relativePath, rootPath),
    );
    nodes[relativePath]!
      ..criterion = folder.criterion
      ..id = folder.id;
  }

  for (final relativePath in nodes.keys.toList()) {
    if (relativePath.isEmpty) {
      continue;
    }

    final parentPath = getParentPath(relativePath);
    final parentNode = nodes.putIfAbsent(
      parentPath,
      () => createFolderNode(parentPath, rootPath),
    );
    if (!parentNode.childPaths.contains(relativePath)) {
      parentNode.childPaths.add(relativePath);
    }
  }

  for (final song in songs) {
    final relativeFolderPath = getSongFolderRelativePath(song.path, rootPath);
    final segments =
        relativeFolderPath.isEmpty ? <String>[] : relativeFolderPath.split('/');
    final ancestorPaths = <String>[''];
    var currentPath = '';

    for (final segment in segments) {
      final nextPath = currentPath.isEmpty ? segment : '$currentPath/$segment';
      final parentNode = nodes.putIfAbsent(
        currentPath,
        () => createFolderNode(currentPath, rootPath),
      );
      nodes.putIfAbsent(nextPath, () => createFolderNode(nextPath, rootPath));
      if (!parentNode.childPaths.contains(nextPath)) {
        parentNode.childPaths.add(nextPath);
      }

      currentPath = nextPath;
      ancestorPaths.add(currentPath);
    }

    final folderNode = nodes.putIfAbsent(
      currentPath,
      () => createFolderNode(currentPath, rootPath),
    );
    folderNode.directSongIds.add(song.id);

    for (final ancestorPath in ancestorPaths) {
      final ancestorNode = nodes.putIfAbsent(
        ancestorPath,
        () => createFolderNode(ancestorPath, rootPath),
      );
      ancestorNode.subtreeSongIds.add(song.id);
    }
  }

  for (final node in nodes.values) {
    node.thumbnailChildPaths =
        node.childPaths.toList()
          ..sort((left, right) => nodes[left]!.id.compareTo(nodes[right]!.id));
    node.thumbnailDirectSongIds = node.directSongIds.toList()..sort();
    node.childPaths.sort(
      (left, right) => compareLocalText(nodes[left]!.name, nodes[right]!.name),
    );
    node.directSongIds.sort((left, right) {
      return _compareSongByFolderCriterion(
        songsById[left]!,
        songsById[right]!,
        node.criterion,
      );
    });
  }

  for (final node in nodes.values) {
    node.subtreeSongIds = _getFolderFlattenedSongIds(node, nodes);
  }

  for (final node in nodes.values) {
    node.thumbnailSubtreeSongIds = _getFolderFlattenedThumbnailSongIds(
      node,
      nodes,
    );
  }

  return FolderIndex(nodes: nodes, songsById: songsById);
}

bool matchesSongSearch(LibrarySong song, String searchQuery) {
  final normalizedSearchQuery = searchQuery.trim().toLowerCase();
  if (normalizedSearchQuery.isEmpty) {
    return true;
  }

  return [
    song.title,
    song.artist,
    ...song.artists,
    song.album,
    song.path,
  ].join(' ').toLowerCase().contains(normalizedSearchQuery);
}

List<FolderChainItem> buildFolderChain(
  String currentRelativePath,
  Map<String, FolderNode> nodes,
) {
  final rootNode = nodes['']!;
  final relativeSegments =
      currentRelativePath
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .toList();
  final currentPaths = [
    '',
    for (var index = 0; index < relativeSegments.length; index += 1)
      relativeSegments.take(index + 1).join('/'),
  ];

  return [
    for (var index = 0; index < currentPaths.length; index += 1)
      _buildFolderChainItem(
        path: currentPaths[index],
        fallbackName: index == 0 ? rootNode.name : relativeSegments[index - 1],
        isCurrentItem: index == currentPaths.length - 1,
        currentRelativePath: currentRelativePath,
        nodes: nodes,
      ),
  ];
}

List<FolderNode> sortFolders(List<FolderNode> folders) {
  return folders.toList()
    ..sort((left, right) => compareLocalText(left.name, right.name));
}

List<LibrarySong> sortSongs(
  List<LibrarySong> songs,
  LocalSortMode mode, [
  LocalSortMode? baseMode,
]) {
  final effectiveBaseMode = baseMode ?? mode;
  if (mode == LocalSortMode.reverse) {
    return sortSongs(
      songs,
      effectiveBaseMode == LocalSortMode.reverse
          ? LocalSortMode.title
          : effectiveBaseMode,
    ).reversed.toList();
  }

  return songs.toList()..sort((left, right) {
    if (mode == LocalSortMode.artist) {
      return _firstNonZero([
        compareLocalText(
          displayArtistsWithoutI18n(left),
          displayArtistsWithoutI18n(right),
        ),
        compareLocalText(left.title, right.title),
      ]);
    }

    if (mode == LocalSortMode.album) {
      return _firstNonZero([
        compareLocalText(left.album, right.album),
        compareLocalText(left.title, right.title),
      ]);
    }

    return compareLocalText(left.title, right.title);
  });
}

LocalSortMode localSortModeFromCriterion(int criterion) {
  switch (criterion) {
    case 7:
      return LocalSortMode.reverse;
    case 1:
      return LocalSortMode.artist;
    case 2:
      return LocalSortMode.album;
    default:
      return LocalSortMode.title;
  }
}

int toLocalFolderSortValue(LocalSortMode criterion) {
  switch (criterion) {
    case LocalSortMode.artist:
      return 1;
    case LocalSortMode.album:
      return 2;
    case LocalSortMode.reverse:
      return 7;
    case LocalSortMode.title:
      return 0;
  }
}

List<int> shuffleSongIds(List<int> songIds) {
  final shuffledSongIds = songIds.toList();
  final random = Random();

  for (var index = shuffledSongIds.length - 1; index > 0; index -= 1) {
    final randomIndex = random.nextInt(index + 1);
    final current = shuffledSongIds[index];
    shuffledSongIds[index] = shuffledSongIds[randomIndex];
    shuffledSongIds[randomIndex] = current;
  }

  return shuffledSongIds;
}

Map<String, int> buildLocalSongQuickJumpMap(
  List<LibrarySong> songs,
  LocalSortMode sortMode,
  LocalSortMode currentSortMode,
  SmPlayerI18n i18n,
) {
  final indexes = <String, int>{};
  final quickJumpSortMode =
      sortMode == LocalSortMode.reverse ? currentSortMode : sortMode;

  for (var index = 0; index < songs.length; index += 1) {
    final bucket = getLocalTextQuickJumpBucket(
      getLocalSongQuickJumpValue(songs[index], quickJumpSortMode, i18n),
    );
    indexes.putIfAbsent(bucket, () => index);
  }

  return indexes;
}

String getLocalSongQuickJumpValue(
  LibrarySong song,
  LocalSortMode sortMode,
  SmPlayerI18n i18n,
) {
  switch (sortMode) {
    case LocalSortMode.artist:
      return getSongArtists(song).firstOrNull ?? i18n.t('common.artistUnknown');
    case LocalSortMode.album:
      return song.album.isEmpty ? i18n.t('common.albumUnknown') : song.album;
    case LocalSortMode.reverse:
    case LocalSortMode.title:
      return song.title;
  }
}

String getLocalSongQuickJumpBasisName(
  LocalSortMode sortMode,
  LocalSortMode currentSortMode,
  SmPlayerI18n i18n,
) {
  final quickJumpSortMode =
      sortMode == LocalSortMode.reverse ? currentSortMode : sortMode;

  switch (quickJumpSortMode) {
    case LocalSortMode.artist:
      return i18n.t('common.artist');
    case LocalSortMode.album:
      return i18n.t('common.album');
    case LocalSortMode.reverse:
    case LocalSortMode.title:
      return i18n.t('musicLibrary.titleHeader');
  }
}

String getLocalTextQuickJumpBucket(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '#';
  }

  final first = trimmed.substring(0, 1).toUpperCase();
  return RegExp(r'^[A-Z]$').hasMatch(first) ? first : '#';
}

int compareLocalText(String left, String right) {
  final leftBucketIndex = artistQuickJumpKeys.indexOf(
    getLocalTextQuickJumpBucket(left),
  );
  final rightBucketIndex = artistQuickJumpKeys.indexOf(
    getLocalTextQuickJumpBucket(right),
  );
  if (leftBucketIndex != rightBucketIndex) {
    return leftBucketIndex.compareTo(rightBucketIndex);
  }

  return left.toLowerCase().compareTo(right.toLowerCase());
}

String displayArtistsWithoutI18n(LibrarySong song) {
  return getSongArtists(song).join(' / ');
}

String _getFolderDisplayName(String relativePath, String rootPath) {
  if (relativePath.isEmpty) {
    final normalizedRootPath = normalizePath(rootPath);
    final parts =
        normalizedRootPath
            .split('/')
            .where((segment) => segment.isNotEmpty)
            .toList();
    return parts.isEmpty ? 'Library root' : parts.last;
  }

  return relativePath.split('/').last;
}

String _getFolderAbsolutePath(String relativePath, String rootPath) {
  if (relativePath.isEmpty) {
    return rootPath;
  }

  final separator = rootPath.contains('\\') ? '\\' : '/';
  return '${rootPath.replaceFirst(RegExp(r'[\\/]+$'), '')}$separator${relativePath.split('/').join(separator)}';
}

String _getFolderRelativePath(String folderPath, String rootPath) {
  final normalizedFolderPath = normalizePath(folderPath);
  final normalizedRootPath = normalizePath(rootPath);

  if (normalizedFolderPath == normalizedRootPath) {
    return '';
  }

  return normalizedFolderPath.substring(normalizedRootPath.length + 1);
}

List<int> _getFolderFlattenedSongIds(
  FolderNode node,
  Map<String, FolderNode> nodes,
) {
  return [
    for (final childPath in node.childPaths)
      ..._getFolderFlattenedSongIds(nodes[childPath]!, nodes),
    ...node.directSongIds,
  ];
}

List<int> _getFolderFlattenedThumbnailSongIds(
  FolderNode node,
  Map<String, FolderNode> nodes,
) {
  return [
    for (final childPath in node.thumbnailChildPaths)
      ..._getFolderFlattenedThumbnailSongIds(nodes[childPath]!, nodes),
    ...node.thumbnailDirectSongIds,
  ];
}

int _compareSongByFolderCriterion(
  LibrarySong left,
  LibrarySong right,
  int criterion,
) {
  switch (criterion) {
    case 1:
      return _firstNonZero([
        compareLocalText(
          displayArtistsWithoutI18n(left),
          displayArtistsWithoutI18n(right),
        ),
        compareLocalText(left.title, right.title),
      ]);
    case 2:
      return _firstNonZero([
        compareLocalText(left.album, right.album),
        compareLocalText(left.title, right.title),
      ]);
    case 3:
      return left.duration.compareTo(right.duration);
    case 4:
      return left.playCount.compareTo(right.playCount);
    case 5:
      return left.dateAdded.compareTo(right.dateAdded);
    case 7:
      return -_compareSongByFolderCriterion(left, right, 0);
    case 0:
    case 6:
      return compareLocalText(left.title, right.title);
    default:
      return left.id.compareTo(right.id);
  }
}

FolderChainItem _buildFolderChainItem({
  required String path,
  required String fallbackName,
  required bool isCurrentItem,
  required String currentRelativePath,
  required Map<String, FolderNode> nodes,
}) {
  final node = nodes[path];
  return FolderChainItem(
    name: node?.name ?? fallbackName,
    path: path,
    isLastItem: !isCurrentItem,
    isCurrentItem: isCurrentItem,
    children: [
      for (final childPath in node?.childPaths ?? const <String>[])
        FolderChainChildItem(
          name: nodes[childPath]!.name,
          path: nodes[childPath]!.relativePath,
          isHighlighted:
              currentRelativePath == nodes[childPath]!.relativePath ||
              currentRelativePath.startsWith(
                '${nodes[childPath]!.relativePath}/',
              ),
        ),
    ],
  );
}

int _firstNonZero(List<int> values) {
  for (final value in values) {
    if (value != 0) {
      return value;
    }
  }
  return 0;
}
