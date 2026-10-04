part of 'library_local_move_service.dart';

Future<LocalItemsMoveResult> _runLocalMoveTask(
  _LocalMoveTask task,
  LocalMoveConflictResolver? resolveConflict,
) async {
  final port = ReceivePort();
  task.conflictPort = resolveConflict == null ? null : port.sendPort;
  final subscription = port.listen((message) async {
    final (sourcePath, targetPath, replyPort) =
        message as (String, String, SendPort);
    try {
      replyPort.send(await resolveConflict!(sourcePath, targetPath));
    } catch (error, stackTrace) {
      replyPort.send((error, stackTrace));
    }
  });
  try {
    return await Isolate.run(task.call);
  } finally {
    await subscription.cancel();
    port.close();
  }
}

class _LocalMoveTask {
  _LocalMoveTask(
    this.databasePath,
    this.songIds,
    this.folderPaths,
    this.targetFolderPath,
  );

  final String databasePath;
  final List<int> songIds;
  final List<String> folderPaths;
  final String targetFolderPath;
  SendPort? conflictPort;

  Future<LocalItemsMoveResult> call() {
    return const LibraryLocalMoveService()._moveLocalItemsToFolderInBackground(
      File(databasePath),
      songIds,
      folderPaths,
      targetFolderPath,
      resolveConflict: conflictPort == null ? null : _resolveConflict,
    );
  }

  Future<LocalMoveConflictResolution> _resolveConflict(
    String sourcePath,
    String targetPath,
  ) async {
    final replyPort = ReceivePort();
    try {
      conflictPort!.send((sourcePath, targetPath, replyPort.sendPort));
      final response = await replyPort.first;
      if (response is LocalMoveConflictResolution) return response;
      final (error, stackTrace) = response as (Object, StackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      replyPort.close();
    }
  }
}

class _UndoLocalMoveTask {
  const _UndoLocalMoveTask(this.databasePath, this.result);

  final String databasePath;
  final LocalItemsMoveResult result;

  Future<void> call() => const LibraryLocalMoveService()
      ._undoMoveLocalItemsInBackground(File(databasePath), result);
}
