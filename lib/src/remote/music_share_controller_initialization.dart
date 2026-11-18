part of 'music_share_controller.dart';

extension _MusicShareInitialization on MusicShareController {
  Future<void> _load() async {
    final (snapshot, loadedIdentity, stored, storedHost) =
        await (
          loadLibrary(),
          MusicShareIdentity.load(),
          MusicShareIdentity.storage.read(key: 'music-share-connections-v1'),
          MusicShareConnectionStore.readHost(),
        ).wait;
    databasePath = snapshot.databasePath;
    identity = loadedIdentity;
    if (stored != null) {
      final json = {
        ...jsonDecode(stored) as Map<String, dynamic>,
        ...?storedHost,
      };
      name = json['name'] as String;
      selectedSource = json['source'] as String;
      // Existing configurations default to automatic connection.
      autoConnect =
          json.containsKey('autoConnect') ? json['autoConnect'] as bool : true;
      lastConnectedPeerId = json['lastConnectedPeerId'] as String?;
      if (!json.containsKey('lastConnectedPeerId') &&
          selectedSource != 'local' &&
          selectedSource != 'all') {
        lastConnectedPeerId = selectedSource;
      }
      sharing = json['sharing'] as bool;
      port = json['port'] as int? ?? musicSharePort;
      grants.addAll((json['grants'] as Map).cast<String, String>());
      if (json.containsKey('grantIdentities')) {
        grantIdentities.addAll(
          (json['grantIdentities'] as Map).cast<String, String>(),
        );
      }
      if (json.containsKey('mobileGrants')) {
        mobileGrants.addAll((json['mobileGrants'] as List).cast<String>());
      }
      // Older saved authorizations grant playback only.
      if (json.containsKey('writeGrants')) {
        writeGrants.addAll((json['writeGrants'] as List).cast<String>());
      }
      peers.addAll(
        (json['peers'] as List).map(
          (item) => MusicPeer.fromJson((item as Map).cast<String, dynamic>()),
        ),
      );
      if (json['source'] == 'all') {
        selectedSource = 'local';
        await save();
      }
    }
    final host = storedHost;
    if (host != null) {
      name = host['name'] as String;
      port = host['port'] as int;
      sharing = host['sharing'] as bool;
      backgroundSharing = host['backgroundSharing'] as bool;
      grants
        ..clear()
        ..addAll((host['grants'] as Map).cast<String, String>());
      grantIdentities
        ..clear()
        ..addAll((host['grantIdentities'] as Map).cast<String, String>());
      mobileGrants
        ..clear()
        ..addAll((host['mobileGrants'] as List).cast<String>());
      writeGrants
        ..clear()
        ..addAll((host['writeGrants'] as List).cast<String>());
    }
    server = _localHost(snapshot);
    if (host == null)
      await MusicShareConnectionStore.writeHost(_hostConfiguration);
    await _artworkCache.restore();
    initialized = true;
    _notify();
  }
}
