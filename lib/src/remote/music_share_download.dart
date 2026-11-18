import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../app/undoable_notification.dart';
import '../i18n/app_i18n.dart';
import '../library/data/library_providers.dart';
import '../library/data/library_repository.dart';
import '../library/ui/library_page_actions.dart';
import 'music_share_download_settings.dart';
import 'music_share_identity.dart';
import 'music_share_models.dart';
import 'music_source_providers.dart';

Future<void> downloadRemoteMusic(
  BuildContext context,
  String device, {
  String? folder,
  List<int>? songs,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final peer = container
      .read(musicShareProvider)
      .peerFor(remoteMusicPath(device, 0));
  final library = container.read(libraryContentDataProvider).requireValue;
  final destination = await container
      .read(musicShareDownloadSettingsProvider)
      .resolveDirectory(libraryRoot: library.rootPath);
  final transport = MusicShareTransport(
    peer.address,
    fingerprint: peer.fingerprint,
    token: peer.token,
  );
  var count = 0;
  try {
    final manifest = await transport.json(
      Uri(
        path: '/downloads',
        queryParameters: {
          if (folder != null) 'folder': folder,
          if (songs != null) 'songs': songs.join(','),
        },
      ).toString(),
    );
    final name = manifest['name'] as String;
    if (name.contains('/') ||
        name.contains('\\') ||
        name == '..' ||
        name == '.') {
      throw const MusicShareException('share.fileOutsideLibrary');
    }
    final base = folder == null ? destination : p.join(destination, name);
    Future<String> targetPath(String relative) async {
      if (p.posix.isAbsolute(relative) ||
          relative.split('/').contains('..') ||
          relative.contains('\\')) {
        throw const MusicShareException('share.fileOutsideLibrary');
      }
      final target = p.joinAll([base, ...relative.split('/')]);
      final root = await Directory(destination).resolveSymbolicLinks();
      var existing = p.dirname(target);
      while (!await Directory(existing).exists()) {
        existing = p.dirname(existing);
      }
      final resolved = await Directory(existing).resolveSymbolicLinks();
      if (resolved != root && !p.isWithin(root, resolved)) {
        throw const MusicShareException('share.fileOutsideLibrary');
      }
      await Directory(p.dirname(target)).create(recursive: true);
      final parent = await Directory(p.dirname(target)).resolveSymbolicLinks();
      if (parent != root && !p.isWithin(root, parent)) {
        throw const MusicShareException('share.fileOutsideLibrary');
      }
      return target;
    }

    await Directory(destination).create(recursive: true);
    for (final directory in (manifest['folders'] as List).cast<String>()) {
      await Directory(await targetPath(directory)).create(recursive: true);
    }
    for (final entry in (manifest['files'] as List).cast<Map>()) {
      var target = await targetPath(entry['path'] as String);
      if (await FileSystemEntity.type(target) !=
          FileSystemEntityType.notFound) {
        if (!context.mounted) return;
        final choice = await requestLocalMoveConflictResolution(
          context: context,
          i18n: context.smPlayerI18n,
          sourcePath: entry['path'] as String,
          targetPath: target,
        );
        if (choice == LocalMoveConflictResolution.skip) continue;
        if (choice == LocalMoveConflictResolution.keepBoth) {
          final original = target;
          var index = 1;
          do {
            target = p.join(
              p.dirname(original),
              '${p.basenameWithoutExtension(original)} ($index)${p.extension(original)}',
            );
            index++;
          } while (await FileSystemEntity.type(target) !=
              FileSystemEntityType.notFound);
        }
      }
      final temporary = File('$target.${newShareSecret()}.part');
      try {
        final response = await transport.open('/songs/${entry['song']}/audio');
        if (response.statusCode != HttpStatus.ok) {
          await response.drain<void>();
          throw const MusicShareException('share.fileChanged');
        }
        final sink = temporary.openWrite();
        try {
          await sink.addStream(response.timeout(const Duration(seconds: 30)));
        } finally {
          await sink.close();
        }
        if (response.contentLength >= 0 &&
            await temporary.length() != response.contentLength) {
          throw const MusicShareException('share.fileChanged');
        }
        await temporary.rename(target);
        count++;
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
    }
    if (count > 0 &&
        (p.equals(destination, library.rootPath) ||
            p.isWithin(library.rootPath, destination))) {
      final result = await container
          .read(libraryRepositoryProvider)
          .refreshLocalFolder(base);
      await updateLibraryAfterFolderScan(container, result);
    }
    if (context.mounted) {
      showAppNotification(
        context: context,
        message: context.smPlayerI18n.t('share.downloadComplete', {
          'count': count,
        }),
      );
    }
  } on TimeoutException {
    throw const MusicShareException('share.requestTimedOut');
  } on FileSystemException {
    throw const MusicShareException('share.downloadSaveFailed');
  } on MusicShareException catch (error) {
    if (error.httpStatusCode == 404) {
      throw const MusicShareException('share.directoryUpgradeRequired');
    }
    rethrow;
  } finally {
    transport.close();
  }
}
