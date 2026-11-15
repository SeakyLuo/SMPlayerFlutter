import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/app_i18n.dart';
import '../../remote/music_share_models.dart';
import '../../remote/remote_directory_provider.dart';
import '../data/library_models.dart';
import '../data/library_providers.dart';
import '../data/library_repository.dart';
import 'library_page_actions.dart' show requestLocalMoveConflictResolution;

/// Presentation invalidation and conflict dialogs; storage dispatch belongs to LibraryDataSource.
class LibraryStorageActions {
  LibraryStorageActions(WidgetRef ref)
    : container = ProviderScope.containerOf(ref.context, listen: false);
  final ProviderContainer container;
  LibraryRepository get repository => container.read(libraryRepositoryProvider);

  void _changed(LibrarySource source) {
    invalidateLibraryQueries(container.invalidate, source: source.deviceId);
    container.invalidate(remoteDirectoryProvider(source.deviceId));
  }

  Future<LibraryStorageChange> _change(
    Future<LibraryStorageChange> action,
  ) async {
    final change = await action;
    _changed(change.source);
    return LibraryStorageChange(
      source: change.source,
      count: change.count,
      undo: () async {
        await change.undo();
        _changed(change.source);
      },
      commit: change.commit,
    );
  }

  LibraryDataSource _sourceOf(Map<int, String> songs, List<String> folders) {
    final sources = {
      ...songs.values.map(LibrarySource.fromPath),
      ...folders.map(LibrarySource.fromPath),
    };
    if (sources.length != 1) {
      throw const MusicShareException('share.sameDeviceSongs');
    }
    return repository.dataSource(sources.single);
  }

  Future<LibraryStorageChange> delete(LibrarySong song) => _change(
    repository.dataSource(song.source).deleteStorageItems({
      song.id: song.path,
    }, const []),
  );

  Future<LibraryStorageChange> hide(LibrarySong song) =>
      _change(repository.dataSource(song.source).hideSongFile(song));

  Future<LibraryStorageChange> move(
    BuildContext context,
    LibrarySong song,
    String target,
  ) => _move(context, {song.id: song.path}, const [], target);

  Future<LibraryStorageChange> deleteItems(
    List<int> ids,
    List<String> folders,
  ) async {
    final songs =
        ids.isEmpty ? <int, String>{} : await repository.songReferences(ids);
    return _change(
      _sourceOf(songs, folders).deleteStorageItems(songs, folders),
    );
  }

  Future<LibraryStorageChange> moveItems(
    BuildContext context,
    List<int> ids,
    List<String> folders,
    String target,
  ) async {
    final songs =
        ids.isEmpty ? <int, String>{} : await repository.songReferences(ids);
    if (!context.mounted) {
      return LibraryStorageChange(
        source: LibrarySource.fromPath(target),
        count: 0,
        undo: () async {},
        commit: () async {},
      );
    }
    return _move(context, songs, folders, target);
  }

  Future<LibraryStorageChange> _move(
    BuildContext context,
    Map<int, String> songs,
    List<String> folders,
    String target,
  ) {
    final dataSource = _sourceOf(songs, folders);
    if (LibrarySource.fromPath(target) != dataSource.source) {
      throw const MusicShareException('share.sameDeviceSongs');
    }
    return _change(
      dataSource.moveStorageItems(
        songs,
        folders,
        target,
        resolveConflict: (from, to) async {
          if (!context.mounted) throw const LocalFolderScanCanceledException();
          return requestLocalMoveConflictResolution(
            context: context,
            i18n: context.smPlayerI18n,
            sourcePath: from,
            targetPath: to,
          );
        },
      ),
    );
  }

  Future<void> createFolder(String root, String parent, String name) async {
    final source = LibrarySource.fromPath(root);
    await repository.dataSource(source).createStorageFolder(root, parent, name);
    _changed(source);
  }

  Future<LibraryStorageChange> renameFolder(String path, String name) =>
      _change(
        repository
            .dataSource(LibrarySource.fromPath(path))
            .renameStorageFolder(path, name),
      );

  Future<LibraryStorageChange> hideFolder(String path) => _change(
    repository.dataSource(LibrarySource.fromPath(path)).hideStorageFolder(path),
  );

  Future<void> updateFolderSort(
    String path,
    LocalFolderSortCriterion criterion,
  ) async {
    final source = LibrarySource.fromPath(path);
    await repository
        .dataSource(source)
        .updateStorageFolderSort(path, criterion);
    _changed(source);
  }

  Future<List<HiddenStorageItem>> hiddenItems(LibrarySource source) =>
      repository.dataSource(source).getHiddenStorageItems();

  Future<void> resumeHiddenItem(
    LibrarySource source,
    HiddenStorageItem item,
  ) async {
    await repository.dataSource(source).resumeHiddenStorageItem(item);
    _changed(source);
  }

  Future<LocalFolderRefreshResult> refreshFolder(
    String path, {
    required LocalFolderScanCancellation cancellation,
    required void Function(LocalFolderRefreshProgress) onProgress,
    Future<void> Function(LocalFolderRefreshResult)? onLibraryCommitted,
  }) async {
    final source = LibrarySource.fromPath(path);
    final result = await repository
        .dataSource(source)
        .refreshStorageFolder(
          path,
          cancellation: cancellation,
          onProgress: onProgress,
          onLibraryCommitted: onLibraryCommitted,
        );
    container.invalidate(remoteDirectoryProvider(source.deviceId));
    return result;
  }
}
