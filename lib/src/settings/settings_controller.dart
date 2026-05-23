import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:smplayer_flutter/src/library/data/library_repository.dart';
import 'package:smplayer_flutter/src/settings/settings_model.dart';

SettingsSnapshot _globalSettingsSnapshot = const SettingsSnapshot.defaults();

SettingsSnapshot get smPlayerGlobalSettingsSnapshot => _globalSettingsSnapshot;

void setSmPlayerGlobalSettingsSnapshot(SettingsSnapshot snapshot) {
  _globalSettingsSnapshot = snapshot;
}

void resetSmPlayerGlobalSettingsSnapshot() {
  _globalSettingsSnapshot = const SettingsSnapshot.defaults();
}

class SettingsController extends ChangeNotifier {
  SettingsController([SettingsSnapshot? initialSnapshot, this.repository])
    : _snapshot = initialSnapshot ?? smPlayerGlobalSettingsSnapshot;

  final LibraryRepository? repository;

  SettingsSnapshot _snapshot;
  Future<void> _playbackSettingsWriteQueue = Future.value();

  SettingsSnapshot get snapshot => _snapshot;

  Future<void> refresh() async {
    final databaseSnapshot = await repository?.getSettingsSnapshot();
    if (databaseSnapshot != null) {
      _snapshot = databaseSnapshot;
      setSmPlayerGlobalSettingsSnapshot(_snapshot);
      notifyListeners();
      return;
    }

    _snapshot = smPlayerGlobalSettingsSnapshot;
    notifyListeners();
  }

  Future<void> updateSettings(AppSettingsUpdate update) async {
    _snapshot = _snapshot.apply(update);
    setSmPlayerGlobalSettingsSnapshot(_snapshot);
    notifyListeners();
    await repository?.updateSettings(update);
  }

  Future<void> savePlaybackSettings(PlaybackSettingsUpdate update) async {
    _snapshot = _snapshot.applyPlaybackSettings(update);
    setSmPlayerGlobalSettingsSnapshot(_snapshot);
    final snapshot = _snapshot;
    notifyListeners();
    _playbackSettingsWriteQueue = _playbackSettingsWriteQueue
        .catchError((_) {})
        .then((_) => _persistPlaybackSettings(update, snapshot));
    await _playbackSettingsWriteQueue;
  }

  PlaybackRuntimeSettings getPlaybackSettingsImmediate() {
    return _snapshot.playbackRuntimeSettings;
  }

  void savePlaybackSettingsImmediate(PlaybackSettingsUpdate update) {
    _snapshot = _snapshot.applyPlaybackSettings(update);
    setSmPlayerGlobalSettingsSnapshot(_snapshot);
    final snapshot = _snapshot;
    notifyListeners();
    unawaited(_persistPlaybackSettings(update, snapshot));
  }

  Future<void> saveViewState({String? lastPage, int? lastPlaylistId}) async {
    _snapshot = _snapshot.copyWith(
      lastPage: lastPage,
      lastPlaylistId: lastPlaylistId,
    );
    setSmPlayerGlobalSettingsSnapshot(_snapshot);
    notifyListeners();
    await repository?.saveViewState(
      lastPage: lastPage,
      lastPlaylistId: lastPlaylistId,
    );
  }

  Future<void> _persistPlaybackSettings(
    PlaybackSettingsUpdate update,
    SettingsSnapshot snapshot,
  ) async {
    setSmPlayerGlobalSettingsSnapshot(snapshot);
    await repository?.savePlaybackSettings(update);
  }
}
