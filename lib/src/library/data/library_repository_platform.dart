part of 'library_repository.dart';

bool _isLikelyArtworkImage(List<int> data) {
  if (data.length < 12) {
    return false;
  }
  if (data[0] == 0xff && data[1] == 0xd8 && data[2] == 0xff) {
    return true;
  }
  if (data[0] == 0x89 &&
      data[1] == 0x50 &&
      data[2] == 0x4e &&
      data[3] == 0x47 &&
      data[4] == 0x0d &&
      data[5] == 0x0a &&
      data[6] == 0x1a &&
      data[7] == 0x0a) {
    return true;
  }
  if (data[0] == 0x52 &&
      data[1] == 0x49 &&
      data[2] == 0x46 &&
      data[3] == 0x46 &&
      data[8] == 0x57 &&
      data[9] == 0x45 &&
      data[10] == 0x42 &&
      data[11] == 0x50) {
    return true;
  }
  if (data[0] == 0x47 &&
      data[1] == 0x49 &&
      data[2] == 0x46 &&
      data[3] == 0x38) {
    return true;
  }
  if (data[0] == 0x42 && data[1] == 0x4d) {
    return true;
  }
  return false;
}

typedef TrashPath = Future<void> Function(String path);
Future<void> trashPathIfExists(String targetPath) async {
  final type = FileSystemEntity.typeSync(targetPath);
  if (type == FileSystemEntityType.notFound) {
    return;
  }
  if (Platform.isMacOS) {
    await _runTrashCommand('osascript', [
      '-e',
      'tell application "Finder" to delete POSIX file ${_appleScriptString(targetPath)}',
    ], targetPath: targetPath);
    return;
  }
  if (Platform.isWindows) {
    final command =
        type == FileSystemEntityType.directory
            ? 'Add-Type -AssemblyName Microsoft.VisualBasic; '
                '[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(${_powerShellString(targetPath)}, '
                "'OnlyErrorDialogs', 'SendToRecycleBin')"
            : 'Add-Type -AssemblyName Microsoft.VisualBasic; '
                '[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(${_powerShellString(targetPath)}, '
                "'OnlyErrorDialogs', 'SendToRecycleBin')";
    await _runTrashCommand('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      command,
    ], targetPath: targetPath);
    return;
  }
  if (Platform.isLinux) {
    await _runTrashCommand('gio', [
      'trash',
      targetPath,
    ], targetPath: targetPath);
    return;
  }

  if (type == FileSystemEntityType.directory) {
    await Directory(targetPath).delete(recursive: true);
  } else if (type == FileSystemEntityType.file) {
    await File(targetPath).delete();
  }
}

Future<ShellThumbnail?> resolveShellThumbnail(String filePath) async {
  if (Platform.isMacOS) {
    return _resolveMacQuickLookThumbnail(filePath);
  }
  return null;
}

Future<ShellThumbnail?> _resolveMacQuickLookThumbnail(String filePath) async {
  final thumbnailDirectory = await Directory.systemTemp.createTemp(
    'smplayer-shell-thumbnail-',
  );
  try {
    final result = await Process.run('qlmanage', [
      '-t',
      '-s',
      '512',
      '-o',
      thumbnailDirectory.path,
      filePath,
    ]);
    if (result.exitCode != 0) {
      return null;
    }
    for (final entity in thumbnailDirectory.listSync()) {
      if (entity is! File) {
        continue;
      }
      final data = await entity.readAsBytes();
      if (_isLikelyArtworkImage(data)) {
        return ShellThumbnail(data: data, extension: p.extension(entity.path));
      }
    }
    return null;
  } finally {
    if (thumbnailDirectory.existsSync()) {
      await thumbnailDirectory.delete(recursive: true);
    }
  }
}

Future<void> _runTrashCommand(
  String executable,
  List<String> arguments, {
  required String targetPath,
}) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0) {
    throw FileSystemException(
      'Failed to move item to system trash',
      targetPath,
      OSError('${result.stderr}', result.exitCode),
    );
  }
}

String _appleScriptString(String value) {
  return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
}

String _powerShellString(String value) {
  return "'${value.replaceAll("'", "''")}'";
}
