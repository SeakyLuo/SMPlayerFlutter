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
  Future<void> _viewStateWriteQueue = Future.value();
  Future<void> _displayModeStateWriteQueue = Future.value();

  SettingsSnapshot get snapshot => _snapshot;

  void restoreSnapshot(SettingsSnapshot snapshot) {
    _snapshot = snapshot;
    setSmPlayerGlobalSettingsSnapshot(_snapshot);
    notifyListeners();
  }

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
    _playbackSettingsWriteQueue = _playbackSettingsWriteQueue
        .catchError((_) {})
        .then((_) => _persistPlaybackSettings(update, snapshot));
  }

  Future<void> waitForPendingPlaybackSettings() async {
    await _playbackSettingsWriteQueue;
  }

  Future<void> saveViewState({String? lastPage, int? lastPlaylistId}) async {
    _snapshot = _snapshot.copyWith(
      lastPage: lastPage,
      lastPlaylistId: lastPlaylistId,
    );
    setSmPlayerGlobalSettingsSnapshot(_snapshot);
    final snapshot = _snapshot;
    _viewStateWriteQueue = _viewStateWriteQueue
        .catchError((_) {})
        .then(
          (_) => _persistViewState(
            lastPage: lastPage == null ? null : snapshot.lastPage,
            lastPlaylistId:
                lastPlaylistId == null ? null : snapshot.lastPlaylistId,
          ),
        );
    await _viewStateWriteQueue;
  }

  Future<void> waitForPendingViewState() async {
    await _viewStateWriteQueue;
  }

  Future<void> saveDisplayModeState({
    required SmPlayerDisplayMode lastDisplayMode,
  }) async {
    _snapshot = _snapshot.copyWith(lastDisplayMode: lastDisplayMode);
    setSmPlayerGlobalSettingsSnapshot(_snapshot);
    final snapshot = _snapshot;
    notifyListeners();
    _displayModeStateWriteQueue = _displayModeStateWriteQueue
        .catchError((_) {})
        .then((_) => _persistDisplayModeState(snapshot.lastDisplayMode));
    await _displayModeStateWriteQueue;
  }

  Future<void> waitForPendingDisplayModeState() async {
    await _displayModeStateWriteQueue;
  }

  Future<void> _persistPlaybackSettings(
    PlaybackSettingsUpdate update,
    SettingsSnapshot snapshot,
  ) async {
    setSmPlayerGlobalSettingsSnapshot(snapshot);
    await repository?.savePlaybackSettings(update);
  }

  Future<void> _persistViewState({
    required String? lastPage,
    required int? lastPlaylistId,
  }) async {
    await repository?.saveViewState(
      lastPage: lastPage,
      lastPlaylistId: lastPlaylistId,
    );
  }

  Future<void> _persistDisplayModeState(
    SmPlayerDisplayMode lastDisplayMode,
  ) async {
    await repository?.saveDisplayModeState(lastDisplayMode: lastDisplayMode);
  }
}
