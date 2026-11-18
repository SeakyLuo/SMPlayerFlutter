import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';

import '../library/data/library_repository_paths.dart';
import 'music_share_identity.dart';

/// Serializes configuration updates from the UI and the sharing process.
class MusicShareConnectionStore {
  static const key = 'music-share-connections-v1';
  static const hostKey = 'music-share-host-v1';
  static const _android = MethodChannel(
    'smplayer_flutter/sharing_configuration',
  );

  static Future<Map<String, dynamic>?> readHost() async {
    final value =
        Platform.isAndroid
            ? await _android.invokeMethod<String>('read')
            : await MusicShareIdentity.storage.read(key: hostKey);
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  static Future<void> writeHost(Map<String, dynamic> host) {
    final value = jsonEncode(host);
    return Platform.isAndroid
        ? _android.invokeMethod<void>('write', value)
        : MusicShareIdentity.storage.write(key: hostKey, value: value);
  }

  static Future<void> _pending = Future.value();

  static Future<void> update(Map<String, dynamic> changes) {
    final operation = _pending.then((_) async {
      final directory = Directory(await defaultSmPlayerUserDataPath());
      await directory.create(recursive: true);
      final lock = await File(
        p.join(directory.path, 'sharing-config.lock'),
      ).open(mode: FileMode.append);
      await lock.lock(FileLock.blockingExclusive);
      try {
        final value = await MusicShareIdentity.storage.read(key: key);
        final current =
            value == null
                ? <String, dynamic>{}
                : jsonDecode(value) as Map<String, dynamic>;
        await MusicShareIdentity.storage.write(
          key: key,
          value: jsonEncode({...current, ...changes}),
        );
      } finally {
        await lock.unlock();
        await lock.close();
      }
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }
}
