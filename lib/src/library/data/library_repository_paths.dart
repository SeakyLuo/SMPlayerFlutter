import 'dart:io';

import 'package:path/path.dart' as p;

const smPlayerDatabaseName = 'SMPlayerSettings.db';
const nowPlayingJsonName = 'NowPlaying.json';
const pendingSongDeletesJsonName = 'pending-song-deletes.json';
const macOsBundleIdentifier = 'com.seaky.smplayerFlutter';

typedef WindowsUwpDatabaseResolver = File? Function();

class LibraryRepositoryPaths {
  const LibraryRepositoryPaths({
    Future<File> Function()? databaseFileResolver,
    File Function()? nowPlayingFileResolver,
    Future<File> Function()? pendingDeleteFileResolver,
  }) : _databaseFileResolver = databaseFileResolver,
       _nowPlayingFileResolver = nowPlayingFileResolver,
       _pendingDeleteFileResolver = pendingDeleteFileResolver;

  final Future<File> Function()? _databaseFileResolver;
  final File Function()? _nowPlayingFileResolver;
  final Future<File> Function()? _pendingDeleteFileResolver;

  Future<File> resolveDatabaseFile({
    required WindowsUwpDatabaseResolver windowsUwpDatabaseResolver,
  }) async {
    final resolver = _databaseFileResolver;
    if (resolver != null) {
      return resolver();
    }

    if (Platform.isWindows) {
      final uwpDatabase = windowsUwpDatabaseResolver();
      if (uwpDatabase != null) {
        return uwpDatabase;
      }
    }

    final databaseFile = File(
      p.join(defaultSmPlayerUserDataPath(), smPlayerDatabaseName),
    );
    await databaseFile.parent.create(recursive: true);
    return databaseFile;
  }

  File resolveNowPlayingFile() {
    final resolver = _nowPlayingFileResolver;
    if (resolver != null) {
      return resolver();
    }
    return File(p.join(defaultSmPlayerUserDataPath(), nowPlayingJsonName));
  }

  Future<File> resolvePendingSongDeletesFile() async {
    final resolver = _pendingDeleteFileResolver;
    if (resolver != null) {
      return resolver();
    }
    return File(
      p.join(defaultSmPlayerUserDataPath(), pendingSongDeletesJsonName),
    );
  }
}

String defaultSmPlayerUserDataPath() {
  if (Platform.isWindows) {
    return p.join(Platform.environment['APPDATA']!, 'simple-melody-player');
  }

  if (Platform.isMacOS) {
    return p.join(
      _macOsSandboxDataPath(),
      'Library',
      'Application Support',
      'Simple Melody Player',
    );
  }

  return p.join(
    Platform.environment['HOME']!,
    '.config',
    'simple-melody-player',
  );
}

String _macOsSandboxDataPath() {
  final home = Platform.environment['HOME']!;
  final normalizedHome = p.normalize(home);
  final sandboxSuffix = p.join(
    'Library',
    'Containers',
    macOsBundleIdentifier,
    'Data',
  );
  if (normalizedHome.endsWith(sandboxSuffix)) {
    return home;
  }
  return p.join(home, 'Library', 'Containers', macOsBundleIdentifier, 'Data');
}
