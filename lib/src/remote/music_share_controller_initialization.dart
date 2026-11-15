part of 'music_share_controller.dart';

extension _MusicShareInitialization on MusicShareController {
  Future<void> _load() async {
    final (snapshot, loadedIdentity, stored) =
        await (
          loadLibrary(),
          MusicShareIdentity.load(),
          MusicShareIdentity.storage.read(key: 'music-share-connections-v1'),
        ).wait;
    databasePath = snapshot.databasePath;
    identity = loadedIdentity;
    if (stored != null) {
      final json = jsonDecode(stored) as Map<String, dynamic>;
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
    server = MusicShareServer(
      onLibraryChanged: () => onCatalogChanged('local'),
      onPeerConnected: (name) {
        incomingConnection = (
          revision: (incomingConnection?.revision ?? 0) + 1,
          name: name,
        );
        _notify();
      },
      identity: identity,
      repository: repository,
      name: () => name,
      grants: grants,
      grantIdentities: grantIdentities,
      mobileGrants: mobileGrants,
      writeGrants: writeGrants,
      onChanged: () {
        _notify();
      },
    );
    server.updateLibrary(snapshot);
    await _artworkCache.restore();
    initialized = true;
    _notify();
  }
}
