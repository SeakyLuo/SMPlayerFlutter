import '../library/data/library_models.dart';
import 'music_share_event_hub.dart';
import 'music_share_models.dart';

/// Management boundary shared by the in-app listener and the background host.
abstract interface class MusicShareHost {
  bool get running;
  Map<String, MusicPairRequest> get requests;
  MusicShareEventHub get events;
  Future<void> start({int port = musicSharePort});
  Future<void> changePort(int port);
  Future<void> stop();
  Future<void> disconnect();
  void updateLibrary(LibraryContentData snapshot, {bool notify = true});
  void markCatalogChanged();
  Future<void> approve(
    String key,
    bool allow, {
    required Future<void> Function() persist,
    bool canWrite = false,
  });
  Future<void> revoke(String hash, {required Future<void> Function() persist});
  Future<void> setWritePermission(
    String hash,
    bool enabled, {
    required Future<void> Function() persist,
  });
}
