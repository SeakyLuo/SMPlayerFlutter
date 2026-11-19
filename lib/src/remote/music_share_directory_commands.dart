import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../library/data/library_repository.dart';
import '../library/data/library_models.dart';
import '../platform/system_log.dart';
import 'music_share_models.dart';

class MusicShareDirectoryCommands {
  MusicShareDirectoryCommands(this.repository);
  final LibraryRepository repository;
  final _undo = <String, _DirectoryUndo>{};

  Future<Map<String, dynamic>> handle(
    HttpRequest request,
    String rootPath,
    String owner,
    bool Function() canWrite, {
    required void Function(List<int>, String?) onChangedSongs,
  }) async {
    final body = StringBuffer();
    await for (final chunk in utf8.decoder
        .bind(request)
        .timeout(const Duration(seconds: 15))) {
      body.write(chunk);
      if (body.length > 1024 * 1024) {
        throw const FormatException('Directory request too large');
      }
    }
    final values = jsonDecode(body.toString()) as Map<String, dynamic>;
    final root = await Directory(rootPath).resolveSymbolicLinks();
    void write() {
      if (!canWrite()) {
        throw const MusicShareException('share.readOnlyPermission');
      }
    }

    write();
    final operation = values['operation'] as String;
    if (operation == 'undo' || operation == 'commit') {
      final ticket = values['ticket'] as String;
      final action = _undo[ticket];
      if (action == null || action.owner != owner || action.root != root) {
        throw const MusicShareException('share.fileUndoExpired');
      }
      if (operation == 'undo') {
        await action.undo();
        onChangedSongs(action.songIds, null);
      } else {
        await action.commit();
      }
      action.timer.cancel();
      _undo.remove(ticket);
      return {
        if (operation == 'undo')
          if (action.overwrittenSongIds case final ids?)
            'overwrittenSongIds': ids.toList(),
      };
    }

    Future<String> folder(String relative, {bool allowRoot = true}) async {
      if (p.posix.isAbsolute(relative) ||
          relative.contains('\\') ||
          relative.split('/').contains('..')) {
        throw const MusicShareException('share.fileOutsideLibrary');
      }
      final path =
          await Directory(
            p.joinAll([root, ...relative.split('/')]),
          ).resolveSymbolicLinks();
      if ((!allowRoot && path == root) ||
          path != root && !p.isWithin(root, path)) {
        throw const MusicShareException('share.fileOutsideLibrary');
      }
      return path;
    }

    final path = await folder(values['path'] as String);
    String validName() {
      final name = values['name'] as String;
      if (name.isEmpty ||
          name == '.' ||
          name == '..' ||
          RegExp(r'[<>:"/\\|?*\x00-\x1f]').hasMatch(name)) {
        throw const MusicShareException('share.invalidFileName');
      }
      return name;
    }

    write();
    final selectedIds = switch (operation) {
      'hide-song' => [values['song'] as int],
      'delete' || 'move' => (values['songs'] as List).cast<int>(),
      _ => const <int>[],
    };
    final selectedFolders = switch (operation) {
      'rename' || 'hide' || 'refresh' => [path],
      'delete' || 'move' => await Future.wait(
        (values['folders'] as List).cast<String>().map(
          (value) => folder(value, allowRoot: false),
        ),
      ),
      _ => const <String>[],
    };
    final selectionSongs =
        selectedIds.isEmpty && selectedFolders.isEmpty
            ? const <int, String>{}
            : await repository.getLocalStorageReferences(
              selectedIds,
              selectedFolders,
            );
    final affectedIds = selectionSongs.keys.toSet();
    String? refreshedFolder;
    int? itemCount;
    List<int>? deletedSongIds;
    Set<int>? overwrittenSongIds;
    Future<void> Function()? undo;
    Future<void> Function() commit = () async {};
    switch (operation) {
      case 'refresh':
        refreshedFolder = path;
        await repository.refreshLocalFolder(path);
      case 'create':
        await repository.createLocalFolder(
          root,
          p.relative(path, from: root),
          validName(),
        );
      case 'rename':
        if (path == root) {
          throw const MusicShareException('share.fileOutsideLibrary');
        }
        affectedIds.addAll(
          selectionSongs.entries
              .where((song) => p.isWithin(path, song.value))
              .map((song) => song.key),
        );
        final name = validName();
        await repository.renameFolder(path, name);
        undo = () async {
          await folder(
            p.posix.join(p.posix.dirname(values['path'] as String), name),
          );
          await repository.renameFolder(
            p.join(p.dirname(path), name),
            p.basename(path),
          );
        };
      case 'sort':
        await repository.updateLocalFolderSort(
          path,
          LocalFolderSortCriterion.values[values['criterion'] as int],
        );
      case 'hide':
      case 'hide-song':
        if (operation == 'hide') {
          if (path == root) {
            throw const MusicShareException('share.fileOutsideLibrary');
          }
          affectedIds.addAll(
            selectionSongs.entries
                .where((song) => p.isWithin(path, song.value))
                .map((song) => song.key),
          );
          await repository.hideFolder(path);
          undo = () => repository.unhideFolder(path);
        } else {
          final id = values['song'] as int;
          affectedIds.add(id);
          final song = selectionSongs.entries.firstWhere(
            (song) => song.key == id && !isRemoteMusicPath(song.value),
          );
          await _insideFile(song.value, root);
          await repository.hideSong(id);
          undo = () => repository.unhideSong(id);
        }
      case 'delete':
      case 'move':
        final songIds = (values['songs'] as List).cast<int>();
        affectedIds.addAll(songIds);
        final paths = selectedFolders;
        final selected = songIds.toSet();
        final songs =
            selectionSongs.entries
                .where(
                  (song) =>
                      selected.contains(song.key) &&
                      !isRemoteMusicPath(song.value),
                )
                .toList();
        if (songs.length != selected.length) {
          throw const MusicShareException('share.fileChanged');
        }
        await Future.wait(songs.map((song) => _insideFile(song.value, root)));
        write();
        affectedIds.addAll(
          selectionSongs.entries
              .where(
                (song) => paths.any((folder) => p.isWithin(folder, song.value)),
              )
              .map((song) => song.key),
        );
        if (operation == 'delete') {
          final pending = await repository.beginDeleteLocalItems(
            songIds,
            paths,
          );
          deletedSongIds = pending.songIds;
          undo = () => repository.undoDeleteLocalItems(pending.id);
          itemCount = songIds.length + paths.length;
          commit = () async {
            for (final selected in [
              ...songs.map((song) => song.value),
              ...paths,
            ]) {
              final type = await FileSystemEntity.type(
                selected,
                followLinks: false,
              );
              if (type == FileSystemEntityType.notFound) continue;
              final resolved =
                  type == FileSystemEntityType.directory
                      ? await Directory(selected).resolveSymbolicLinks()
                      : await File(selected).resolveSymbolicLinks();
              if (!p.isWithin(root, resolved)) {
                throw const MusicShareException('share.fileOutsideLibrary');
              }
            }
            await repository.commitDeleteLocalItems(pending.id);
          };
        } else {
          final choices = (values['conflicts'] as Map<String, dynamic>?);
          if (choices == null) {
            final conflicts = await _moveConflicts(songs, paths, path, root);
            if (conflicts.isNotEmpty) return {'conflicts': conflicts};
          }
          final result = await repository.moveLocalItemsToFolder(
            songIds,
            paths,
            path,
            resolveConflict: (source, target) async {
              final key = _relative(source, root);
              if (choices == null || !choices.containsKey(key)) {
                throw const MusicShareException('share.fileChanged');
              }
              return LocalMoveConflictResolution.values.byName(
                choices[key] as String,
              );
            },
          );
          itemCount = result.itemCount;
          overwrittenSongIds = result.overwrittenSongIds;
          affectedIds.addAll(overwrittenSongIds);
          undo = () => repository.undoMoveLocalItems(result);
        }
      default:
        throw const FormatException('Unknown directory operation');
    }
    onChangedSongs(affectedIds.toList(), refreshedFolder);
    if (undo == null) return {};
    final ticket = newShareSecret();
    final action = _DirectoryUndo(
      owner,
      root,
      undo,
      commit,
      affectedIds.toList(),
      overwrittenSongIds,
    );
    _undo[ticket] = action;
    action.timer = Timer(const Duration(minutes: 2), () {
      unawaited(
        _finish(ticket).catchError((Object error, StackTrace stack) {
          SystemLog.error('Remote directory cleanup failed', error, stack);
        }),
      );
    });
    return {
      'ticket': ticket,
      if (itemCount != null) 'count': itemCount,
      if (deletedSongIds != null) 'deletedSongIds': deletedSongIds,
      if (overwrittenSongIds != null)
        'overwrittenSongIds': overwrittenSongIds.toList(),
    };
  }

  Future<void> _insideFile(String path, String root) async {
    final resolved = await File(path).resolveSymbolicLinks();
    if (!p.isWithin(root, resolved)) {
      throw const MusicShareException('share.fileOutsideLibrary');
    }
  }

  String _relative(String path, String root) =>
      p.relative(path, from: root).split(p.separator).join('/');

  Future<List<Map<String, String>>> _moveConflicts(
    List<MapEntry<int, String>> songs,
    List<String> folders,
    String target,
    String root,
  ) async {
    final files = <String, String>{};
    for (final song in songs) {
      if (p.dirname(song.value) != target) {
        files[song.value] = p.join(target, p.basename(song.value));
      }
    }
    for (final source in folders) {
      if (p.dirname(source) == target ||
          source == target ||
          p.isWithin(source, target)) {
        continue;
      }
      await for (final entry in Directory(
        source,
      ).list(recursive: true, followLinks: false)) {
        if (entry is File) {
          await _insideFile(entry.path, root);
          files[entry.path] = p.join(
            target,
            p.basename(source),
            p.relative(entry.path, from: source),
          );
        }
      }
    }
    final conflicts = <Map<String, String>>[];
    for (final entry in files.entries) {
      if (await FileSystemEntity.type(entry.value) !=
          FileSystemEntityType.notFound) {
        conflicts.add({
          'source': _relative(entry.key, root),
          'target': _relative(entry.value, root),
        });
      }
    }
    return conflicts;
  }

  Future<void> _finish(String ticket) async {
    final action = _undo.remove(ticket);
    if (action == null) return;
    action.timer.cancel();
    await action.commit();
  }

  Future<void> close() async {
    await Future.wait(_undo.keys.toList().map(_finish));
  }
}

class _DirectoryUndo {
  _DirectoryUndo(
    this.owner,
    this.root,
    this.undo,
    this.commit,
    this.songIds,
    this.overwrittenSongIds,
  );
  final String owner;
  final String root;
  final List<int> songIds;
  final Set<int>? overwrittenSongIds;
  final Future<void> Function() undo;
  final Future<void> Function() commit;
  late final Timer timer;
}
