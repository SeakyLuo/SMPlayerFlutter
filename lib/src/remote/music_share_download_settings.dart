import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'music_share_identity.dart';
import 'music_share_models.dart';

enum MusicShareDownloadLocation { library, directory }

final musicShareDownloadSettingsProvider =
    ChangeNotifierProvider<MusicShareDownloadSettings>((ref) {
      return MusicShareDownloadSettings();
    });

/// Download preferences belong to this device, independent of the remote host.
class MusicShareDownloadSettings extends ChangeNotifier {
  MusicShareDownloadSettings() {
    ready = _load();
  }

  static const _storageKey = 'music-share-download-settings-v1';
  late final Future<void> ready;
  var location = MusicShareDownloadLocation.directory;
  String? customDirectory;
  var initialized = false;
  var saving = false;
  var _disposed = false;

  Future<void> _load() async {
    final stored = await MusicShareIdentity.storage.read(key: _storageKey);
    if (_disposed) return;
    if (stored != null) {
      final values = jsonDecode(stored) as Map<String, dynamic>;
      location = MusicShareDownloadLocation.values.byName(
        values['location'] as String,
      );
      customDirectory = values['directory'] as String?;
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> setLocation(MusicShareDownloadLocation value) =>
      _save(value, customDirectory);

  Future<void> setDirectory(String value) =>
      _save(MusicShareDownloadLocation.directory, value);

  Future<void> _save(MusicShareDownloadLocation next, String? directory) async {
    await ready;
    saving = true;
    notifyListeners();
    try {
      await MusicShareIdentity.storage.write(
        key: _storageKey,
        value: jsonEncode({'location': next.name, 'directory': directory}),
      );
      location = next;
      customDirectory = directory;
    } finally {
      saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<String> systemDownloadsDirectory() async {
    final directory = await getDownloadsDirectory();
    if (directory == null) {
      throw const MusicShareException('share.downloadDirectoryUnavailable');
    }
    return directory.path;
  }

  /// Resolves at download time, so changing the music library takes effect too.
  Future<String> resolveDirectory({required String libraryRoot}) async {
    await ready;
    if (location == MusicShareDownloadLocation.library) {
      if (libraryRoot.isEmpty) {
        throw const MusicShareException('app.chooseFolderFirst');
      }
      return libraryRoot;
    }
    return customDirectory ?? await systemDownloadsDirectory();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
