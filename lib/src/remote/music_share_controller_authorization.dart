part of 'music_share_controller.dart';

mixin _MusicShareAuthorization {
  MusicShareServer get server;
  Set<String> get writeGrants;
  Set<String> get permissionChanges;
  Future<void> save();
  void _notify();

  Future<void> approve(String key, bool allow, {bool canWrite = false}) async {
    await server.approve(key, allow, persist: save, canWrite: canWrite);
  }

  Future<void> revoke(String hash) async {
    permissionChanges.add(hash);
    _notify();
    try {
      await server.revoke(hash);
    } finally {
      try {
        await save();
      } finally {
        permissionChanges.remove(hash);
        _notify();
      }
    }
  }

  Future<void> setWritePermission(String hash, bool enabled) async {
    final previous = writeGrants.contains(hash);
    permissionChanges.add(hash);
    enabled ? writeGrants.add(hash) : writeGrants.remove(hash);
    _notify();
    try {
      await save();
    } catch (_) {
      previous ? writeGrants.add(hash) : writeGrants.remove(hash);
      rethrow;
    } finally {
      permissionChanges.remove(hash);
      _notify();
    }
  }
}
