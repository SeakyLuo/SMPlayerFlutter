import '../library/data/library_models.dart';
import 'music_share_models.dart';

Map<String, dynamic> sharedScanResult(
  LocalFolderRefreshResult result,
  String root,
) {
  String relative(String path) => path
      .replaceAll('\\', '/')
      .substring(root.replaceAll('\\', '/').length + 1);
  List<Map<String, dynamic>> splits(List<ArtistSplitResultItem> items) => [
    for (final item in items)
      {
        'song': item.songId,
        'title': item.title,
        'artist': item.artist,
        'artists': item.artists,
      },
  ];
  return {
    'libraryChanged': result.libraryChanged,
    'requiresFullReload': result.requiresFullReload,
    'added': result.filesAdded.map(relative).toList(),
    'updated': result.filesUpdated.map(relative).toList(),
    'removed': result.filesRemoved.map(relative).toList(),
    'moved': result.filesMoved.map(relative).toList(),
    'applied': splits(result.artistSplitsApplied),
    'splits': splits(result.artistSplitSuggestions),
    'merges': splits(result.artistMergeSuggestions),
  };
}

LocalFolderRefreshResult readSharedScanResult(
  Map<String, dynamic> data,
  String device,
  Map<String, int> ids,
) {
  String path(String relative) => '$remoteMusicScheme://$device/$relative';
  List<String> paths(String key) =>
      (data[key] as List).cast<String>().map(path).toList();
  List<ArtistSplitResultItem> splits(String key) => [
    for (final item in (data[key] as List).cast<Map>())
      ArtistSplitResultItem(
        songId: ids['${item['song']}']!,
        title: item['title'] as String,
        artist: item['artist'] as String,
        artists: (item['artists'] as List).cast<String>(),
      ),
  ];
  return LocalFolderRefreshResult(
    libraryChanged: data['libraryChanged'] as bool,
    requiresFullReload: data['requiresFullReload'] as bool,
    filesAdded: paths('added'),
    filesUpdated: paths('updated'),
    filesRemoved: paths('removed'),
    filesMoved: paths('moved'),
    artistSplitsApplied: splits('applied'),
    artistSplitSuggestions: splits('splits'),
    artistMergeSuggestions: splits('merges'),
    songIdsByPath: {
      for (final entry in (data['songPaths'] as Map).entries)
        path(entry.key as String): ids['${entry.value}']!,
    },
  );
}

Map<String, dynamic> sharedScanProgress(LocalFolderRefreshProgress value) => {
  'current': value.current,
  'path': value.currentPath,
  'total': value.total,
  'stage': value.stage.index,
  'checkedFolders': value.checkedFolderCount,
  'folders': value.folderCount,
  'processedSongs': value.processedSongCount,
  'songs': value.songCount,
  'added': value.addedCount,
  'updated': value.updatedCount,
  'missing': value.missingCount,
  'canCancel': value.canCancel,
};

LocalFolderRefreshProgress readSharedScanProgress(Map<String, dynamic> data) =>
    LocalFolderRefreshProgress(
      current: data['current'] as int,
      total: data['total'] as int,
      currentPath: data['path'] as String,
      stage: LocalFolderRefreshStage.values[data['stage'] as int],
      checkedFolderCount: data['checkedFolders'] as int,
      folderCount: data['folders'] as int,
      processedSongCount: data['processedSongs'] as int,
      songCount: data['songs'] as int,
      addedCount: data['added'] as int,
      updatedCount: data['updated'] as int,
      missingCount: data['missing'] as int,
      canCancel: data['canCancel'] as bool,
    );
