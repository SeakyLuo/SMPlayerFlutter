import 'dart:io';

import 'package:path/path.dart' as p;

import 'library_models.dart';

const _audioFileExtensions = {
  '.aac',
  '.aiff',
  '.alac',
  '.ape',
  '.flac',
  '.m4a',
  '.mp3',
  '.ogg',
  '.opus',
  '.wav',
  '.wma',
};

List<LocalMovedAudioFile> detectMovedLocalAudioFiles({
  required List<String> addedPaths,
  required List<String> removedPaths,
}) {
  final movedFiles = <LocalMovedAudioFile>[];
  for (final addedPath in addedPaths) {
    final fileName = _localRefreshFileName(addedPath).toLowerCase();
    final matchingRemoved =
        removedPaths
            .where(
              (removedPath) =>
                  _localRefreshFileName(removedPath).toLowerCase() == fileName,
            )
            .toList();
    final matchingAdded =
        addedPaths
            .where(
              (candidatePath) =>
                  _localRefreshFileName(candidatePath).toLowerCase() ==
                  fileName,
            )
            .toList();
    if (matchingRemoved.length == 1 && matchingAdded.length == 1) {
      movedFiles.add(
        LocalMovedAudioFile(
          oldPath: matchingRemoved.single,
          newPath: addedPath,
        ),
      );
    }
  }
  return movedFiles;
}

String _localRefreshFileName(String filePath) {
  final separatorIndex = filePath.lastIndexOf(RegExp(r'[\\/]'));
  return separatorIndex < 0 ? filePath : filePath.substring(separatorIndex + 1);
}

class LocalMovedAudioFile {
  const LocalMovedAudioFile({required this.oldPath, required this.newPath});

  final String oldPath;
  final String newPath;
}

Future<List<String>> findScannableAudioFiles(
  String folderPath, {
  List<String> hiddenFolderPaths = const [],
  List<String> hiddenFilePaths = const [],
  LocalFolderScanCancellation? cancellation,
  void Function(String folderPath)? onFolder,
}) async {
  final audioFiles = <String>[];
  final hiddenFolderKeys =
      hiddenFolderPaths.map(localScanPathComparisonKey).toList();
  final hiddenFileKeys =
      hiddenFilePaths.map(localScanPathComparisonKey).toSet();

  Future<void> walk(Directory directory) async {
    cancellation?.throwIfCanceled();
    onFolder?.call(directory.path);
    await for (final entry in directory.list(followLinks: false)) {
      cancellation?.throwIfCanceled();
      if (entry is Link) {
        continue;
      }
      if (entry is Directory) {
        if (p.basename(entry.path).endsWith('.logicx') ||
            _isHiddenFolderPath(entry.path, hiddenFolderKeys)) {
          continue;
        }
        await walk(entry);
        continue;
      }
      if (entry is! File) {
        continue;
      }
      if (!isScannableAudioFile(entry.path)) {
        continue;
      }
      if (hiddenFileKeys.contains(localScanPathComparisonKey(entry.path))) {
        continue;
      }
      audioFiles.add(entry.path);
    }
  }

  await walk(Directory(folderPath));
  return audioFiles;
}

Future<int> countScannableFolders(
  String folderPath,
  List<String> hiddenFolderPaths,
) async {
  final hiddenFolderKeys =
      hiddenFolderPaths.map(localScanPathComparisonKey).toList();

  Future<int> walk(Directory directory) async {
    var count = 0;
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is Link) {
        continue;
      }
      if (entry is! Directory) {
        continue;
      }
      if (p.basename(entry.path).endsWith('.logicx') ||
          _isHiddenFolderPath(entry.path, hiddenFolderKeys)) {
        continue;
      }
      count += 1 + await walk(entry);
    }
    return count;
  }

  return walk(Directory(folderPath));
}

bool isScannableAudioFile(String filePath) {
  return !p.basename(filePath).startsWith('._') &&
      _audioFileExtensions.contains(p.extension(filePath).toLowerCase());
}

bool _isHiddenFolderPath(String folderPath, List<String> hiddenFolderKeys) {
  final folderKey = localScanPathComparisonKey(folderPath);
  return hiddenFolderKeys.any((hiddenFolderKey) {
    return folderKey == hiddenFolderKey ||
        folderKey.startsWith('$hiddenFolderKey/');
  });
}

List<String> nonEmptyScannedFolders(String rootPath, List<String> audioFiles) {
  final rootKey = localScanPathComparisonKey(rootPath);
  final foldersByKey = <String, String>{rootKey: rootPath};
  for (final audioFile in audioFiles) {
    var folderPath = p.dirname(audioFile);
    while (true) {
      final folderKey = localScanPathComparisonKey(folderPath);
      foldersByKey.putIfAbsent(folderKey, () => folderPath);
      if (folderKey == rootKey || folderPath == p.dirname(folderPath)) {
        break;
      }
      folderPath = p.dirname(folderPath);
    }
  }
  return foldersByKey.values.toList();
}

int localScanPathDepth(String path) {
  return localScanPathComparisonKey(
    path,
  ).split('/').where((part) => part.isNotEmpty).length;
}

String localScanPathComparisonKey(String path) {
  return path.replaceAll('\\', '/').toLowerCase();
}
