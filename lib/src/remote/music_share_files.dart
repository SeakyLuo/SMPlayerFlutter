import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../library/data/library_file_relocation_service.dart';
import '../platform/system_log.dart';
import '../library/data/library_repository.dart';
import 'music_share_models.dart';

class _FileAction {
  _FileAction(
    this.owner,
    this.root, {
    this.deleteId,
    this.deletePath,
    this.relocation,
  });
  final String owner;
  final String root;
  final String? deleteId;
  final String? deletePath;
  final SongFileRelocation? relocation;
  late Timer timer;
}

class MusicShareFiles {
  MusicShareFiles(this.repository, this.changed);
  final LibraryRepository repository;
  final void Function() changed;
  final _actions = <String, _FileAction>{};
  Future<void> _pending = Future.value();

  Future<Map<String, dynamic>> handle(
    HttpRequest request,
    String owner,
    bool Function() canWrite,
  ) {
    final result = _pending.then((_) => _handle(request, owner, canWrite));
    // A failed action must not block subsequent requests in the queue.
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> _inside(
    String path,
    String root, {
    bool directory = false,
  }) async {
    final resolved =
        directory
            ? await Directory(path).resolveSymbolicLinks()
            : await File(path).resolveSymbolicLinks();
    if (resolved != root && !p.isWithin(root, resolved)) {
      throw const MusicShareException('share.fileOutsideLibrary');
    }
  }

  void _requireWrite(bool Function() canWrite) {
    if (!canWrite()) {
      throw const MusicShareException('share.readOnlyPermission');
    }
  }

  Future<Map<String, dynamic>> _handle(
    HttpRequest request,
    String owner,
    bool Function() canWrite,
  ) async {
    try {
      Map<String, dynamic> values;
      if (request.method == 'GET') {
        values = request.uri.queryParameters;
      } else if (request.method == 'POST') {
        final bytes = <int>[];
        await for (final chunk in request.timeout(
          const Duration(seconds: 15),
        )) {
          bytes.addAll(chunk);
          if (bytes.length > 64 * 1024) {
            request.response.statusCode = HttpStatus.requestEntityTooLarge;
            return {};
          }
        }
        values = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        if (!canWrite()) {
          request.response.statusCode = HttpStatus.forbidden;
          return {};
        }
      } else {
        request.response.statusCode = HttpStatus.methodNotAllowed;
        return {};
      }
      final operation = values['operation'] as String;
      if (request.method == 'GET' && operation != 'info') {
        request.response.statusCode = HttpStatus.methodNotAllowed;
        return {};
      }
      final snapshot = await repository.getLibraryContentData();
      final root = await Directory(snapshot.rootPath).resolveSymbolicLinks();
      if (operation == 'undo' || operation == 'commit') {
        final ticket = values['ticket'] as String;
        final action = _actions[ticket];
        if (action == null && operation == 'commit') {
          return {};
        }
        if (action == null || action.owner != owner) {
          throw const MusicShareException('share.fileUndoExpired');
        }
        if (action.root != root) {
          throw const MusicShareException('share.fileOutsideLibrary');
        }
        if (operation == 'undo') {
          if (action.relocation case final move?) {
            for (final pair in move.paths) {
              await _inside(pair.$2, root);
              await _inside(p.dirname(pair.$1), root, directory: true);
            }
            _requireWrite(canWrite);
            await repository.undoSharedSongRelocation(move);
          } else {
            await _inside(action.deletePath!, root);
            _requireWrite(canWrite);
            await repository.undoDeleteSongFromDisk(action.deleteId!);
          }
        } else if (action.deleteId case final deleteId?) {
          await _checkDeleteLocation(action);
          _requireWrite(canWrite);
          await repository.commitDeleteSongFromDisk(deleteId);
        }
        action.timer.cancel();
        _actions.remove(ticket);
        _notifyChanged();
        return {};
      }
      final id = int.parse(values['song'].toString());
      final song =
          snapshot.songs
              .where((s) => s.id == id && !isRemoteMusicPath(s.path))
              .firstOrNull;
      if (song == null || !p.isWithin(snapshot.rootPath, song.path)) {
        throw const MusicShareException('share.fileChanged');
      }
      await _inside(song.path, root);
      final folders =
          snapshot.folders
              .where(
                (f) =>
                    f.path == snapshot.rootPath ||
                    p.isWithin(snapshot.rootPath, f.path),
              )
              .toList();
      if (operation == 'info') {
        final relatives = {
          '',
          ...folders.map(
            (f) =>
                f.path == snapshot.rootPath
                    ? ''
                    : p
                        .relative(f.path, from: snapshot.rootPath)
                        .split(p.separator)
                        .join('/'),
          ),
        };
        return {
          'name': p.basenameWithoutExtension(song.path),
          'extension': p.extension(song.path),
          'parent':
              p.dirname(song.path) == snapshot.rootPath
                  ? ''
                  : p
                      .relative(p.dirname(song.path), from: snapshot.rootPath)
                      .split(p.separator)
                      .join('/'),
          'folders': relatives.toList()..sort(),
        };
      }
      late final _FileAction action;
      switch (operation) {
        case 'delete':
          _requireWrite(canWrite);
          final pending = await repository.beginDeleteSongFromDisk(id);
          action = _FileAction(
            owner,
            root,
            deleteId: pending.id,
            deletePath: song.path,
          );
        case 'rename':
        case 'move':
          late final String target;
          if (operation == 'rename') {
            final name = values['name'] as String;
            if (name.isEmpty ||
                name == '.' ||
                name == '..' ||
                name.endsWith('.') ||
                name.endsWith(' ') ||
                RegExp(r'[<>:"/\\|?*\x00-\x1f]').hasMatch(name)) {
              throw const MusicShareException('share.invalidFileName');
            }
            target = p.join(
              p.dirname(song.path),
              '$name${p.extension(song.path)}',
            );
          } else {
            final relative = values['folder'] as String;
            if (p.posix.isAbsolute(relative) ||
                relative.split('/').contains('..') ||
                relative.contains('\\')) {
              throw const MusicShareException('share.fileOutsideLibrary');
            }
            final folder = p.joinAll([
              snapshot.rootPath,
              ...relative.split('/'),
            ]);
            if (folder != snapshot.rootPath &&
                !folders.any((f) => f.path == folder)) {
              throw const MusicShareException('share.fileOutsideLibrary');
            }
            await _inside(folder, root, directory: true);
            target = p.join(folder, p.basename(song.path));
          }
          final targetFolder =
              folders.where((f) => f.path == p.dirname(target)).firstOrNull;
          _requireWrite(canWrite);
          final result = await repository.relocateSharedSong(
            song,
            target,
            targetFolder == null ? 0 : targetFolder.id,
            root,
          );
          action = _FileAction(owner, root, relocation: result);
        default:
          throw const FormatException('Unknown file operation');
      }
      final ticket = newShareSecret();
      _actions[ticket] = action;
      action.timer = Timer(const Duration(minutes: 2), () {
        final cleanup = _pending.then((_) => _finish(ticket));
        _pending = cleanup.then<void>(
          (_) {},
          onError: (Object _, StackTrace __) {},
        );
      });
      _notifyChanged();
      return {'ticket': ticket};
    } on MusicShareException catch (error) {
      if (error.messageKey == 'share.readOnlyPermission') {
        request.response.statusCode = HttpStatus.forbidden;
        return {};
      }
      return {'error': error.messageKey};
    } on FileSystemException catch (error) {
      return {'error': error.message};
    }
  }

  void _notifyChanged() {
    unawaited(
      Future<void>(changed).catchError((Object error, StackTrace stack) {
        SystemLog.error('Remote file cache notification failed', error, stack);
      }),
    );
  }

  Future<void> _checkDeleteLocation(_FileAction action) async {
    if (await FileSystemEntity.type(action.deletePath!, followLinks: false) !=
        FileSystemEntityType.notFound) {
      await _inside(action.deletePath!, action.root);
    }
  }

  Future<void> _finish(String ticket) async {
    final action = _actions.remove(ticket);
    // The client can finish an action while its expiry is already queued.
    if (action == null) return;
    action.timer.cancel();
    if (action.deleteId case final id?) {
      // Failed trash operations stay in the existing persistent pending-delete file.
      try {
        await _checkDeleteLocation(action);
        await repository.commitDeleteSongFromDisk(id);
      } on MusicShareException {
        await repository.undoDeleteSongFromDisk(id);
        _notifyChanged();
      } on Object {
        // The pending-delete file retains this request for normal startup recovery.
      }
    }
  }

  Future<void> close() async {
    for (final action in _actions.values) {
      action.timer.cancel();
    }
    await _pending;
    for (final ticket in _actions.keys.toList()) {
      await _finish(ticket);
    }
  }
}
