part of 'music_share_controller.dart';

mixin _MusicShareAuthorization {
  MusicShareHost get server;
  Set<String> get writeGrants;
  Set<String> get permissionChanges;
  Future<void> _persistHostSettings();
  Future<T> _runHostMutation<T>(Future<T> Function() action);
  void _notify();

  Future<void> approve(String key, bool allow, {bool canWrite = false}) =>
      _runHostMutation(
        () => server.approve(
          key,
          allow,
          persist: _persistHostSettings,
          canWrite: canWrite,
        ),
      );

  Future<void> revoke(String hash) async {
    permissionChanges.add(hash);
    _notify();
    try {
      await _runHostMutation(() async {
        await server.revoke(hash, persist: _persistHostSettings);
      });
    } finally {
      permissionChanges.remove(hash);
      _notify();
    }
  }

  Future<void> setWritePermission(String hash, bool enabled) async {
    permissionChanges.add(hash);
    _notify();
    try {
      await _runHostMutation(
        () => server.setWritePermission(
          hash,
          enabled,
          persist: _persistHostSettings,
        ),
      );
    } finally {
      permissionChanges.remove(hash);
      _notify();
    }
  }
}
