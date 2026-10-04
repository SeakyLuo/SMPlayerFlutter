import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
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
  static Future<File>? _windowsDatabaseFile;

  Future<File> resolveDatabaseFile({
    required WindowsUwpDatabaseResolver windowsUwpDatabaseResolver,
  }) async {
    final resolver = _databaseFileResolver;
    if (resolver != null) {
      return resolver();
    }

    if (Platform.isWindows) {
      return _windowsDatabaseFile ??= _resolveWindowsDatabaseFile(
        windowsUwpDatabaseResolver,
      );
    }

    final databaseFile = File(
      p.join(defaultSmPlayerUserDataPath(), smPlayerDatabaseName),
    );
    await databaseFile.parent.create(recursive: true);
    return databaseFile;
  }

  static Future<File> _resolveWindowsDatabaseFile(
    WindowsUwpDatabaseResolver windowsUwpDatabaseResolver,
  ) async {
    final packageDataPath = await const MethodChannel(
      'smplayer_flutter/desktop_features',
    ).invokeMethod<String>('getApplicationDataPath');
    final File databaseFile;
    if (packageDataPath != null) {
      databaseFile = File(p.join(packageDataPath, smPlayerDatabaseName));
    } else {
      // Unpackaged development builds retain the existing legacy-library
      // selection. Store builds always use their own package's LocalState.
      final uwpDatabase = await Isolate.run(windowsUwpDatabaseResolver);
      databaseFile =
          uwpDatabase ??
          File(p.join(defaultSmPlayerUserDataPath(), smPlayerDatabaseName));
    }
    await databaseFile.parent.create(recursive: true);
    return databaseFile;
  }

  File resolveNowPlayingFile(File databaseFile) {
    final resolver = _nowPlayingFileResolver;
    if (resolver != null) {
      return resolver();
    }
    return File(p.join(databaseFile.parent.path, nowPlayingJsonName));
  }

  Future<File> resolvePendingSongDeletesFile(File databaseFile) async {
    final resolver = _pendingDeleteFileResolver;
    if (resolver != null) {
      return resolver();
    }
    return File(p.join(databaseFile.parent.path, pendingSongDeletesJsonName));
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
