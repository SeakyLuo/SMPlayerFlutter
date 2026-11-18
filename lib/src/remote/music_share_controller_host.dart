part of 'music_share_controller.dart';

extension MusicShareHostManagement on MusicShareController {
  Map<String, dynamic> get _hostConfiguration => {
    'name': name,
    'port': port,
    'sharing': sharing,
    'backgroundSharing': backgroundSharing,
    'backgroundDatabasePath': databasePath,
    'grants': Map<String, String>.of(grants),
    'grantIdentities': Map<String, String>.of(grantIdentities),
    'mobileGrants': mobileGrants.toList(),
    'writeGrants': writeGrants.toList(),
  };

  MusicShareServer _localHost(LibraryContentData snapshot) => MusicShareServer(
    identity: identity,
    repository: repository,
    name: () => name,
    grants: grants,
    grantIdentities: grantIdentities,
    mobileGrants: mobileGrants,
    writeGrants: writeGrants,
    onChanged: _notify,
    onLibraryChanged: () => onCatalogChanged('local'),
    onPeerConnected: (value) {
      incomingConnection = (
        revision: (incomingConnection?.revision ?? 0) + 1,
        name: value,
      );
      _notify();
    },
  )..updateLibrary(snapshot, notify: false);

  MusicShareBackgroundHost _backgroundHost() {
    late MusicShareBackgroundHost host;
    int? dataRevision;
    host = MusicShareBackgroundHost(
      grants: grants,
      grantIdentities: grantIdentities,
      mobileGrants: mobileGrants,
      writeGrants: writeGrants,
      onState: (state) {
        if (!identical(server, host)) return;
        if (state['dataRevision'] case final int revision) {
          if (dataRevision != null && dataRevision != revision) {
            onHostDataChanged((state['changedScopes'] as List).cast<String>());
          }
          dataRevision = revision;
        }
        if (state.containsKey('name')) name = state['name'] as String;
        if (state.containsKey('port')) port = state['port'] as int;
        if (state.containsKey('sharing')) sharing = state['sharing'] as bool;
        _notify();
      },
    );
    return host;
  }

  Future<void> _startSharingHost() async {
    if (!backgroundSharing) {
      await server.start(port: port);
      return;
    }
    server = await _connectBackgroundHost();
    _notify();
  }

  Future<MusicShareBackgroundHost> _connectBackgroundHost() async {
    final host = _backgroundHost();
    await host.connect();
    try {
      final library = await repository.queryLibrary(
        const LibraryDataQuery(LibraryQueryKind.context),
      );
      await host.configure(
        name: name,
        port: port,
        databasePath: databasePath,
        rootPath: library.rootPath,
      );
      await aiAgentRemoteController.attachBackground(host);
      return host;
    } catch (error, stack) {
      try {
        await host.handoff();
      } catch (cleanupError, cleanupStack) {
        SystemLog.error(
          'Stopping failed sharing host failed',
          cleanupError,
          cleanupStack,
        );
        await host.disconnect();
        await MusicShareBackgroundPlatform.stop();
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<void> _saveConnections() {
    final client = {
      'source': selectedSource,
      'autoConnect': autoConnect,
      'lastConnectedPeerId': lastConnectedPeerId,
      'peers': peers.map((peer) => peer.toJson()).toList(),
    };
    final operation = _savePending.then((_) async {
      await MusicShareConnectionStore.update(client);
    });
    _savePending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  Future<void> _setSharing(bool enabled) async {
    if (!initialized) await ready;
    await startup;
    busy = true;
    _notify();
    final previousSharing = sharing;
    try {
      if (enabled) {
        if (backgroundSharing) {
          await aiAgentRemoteController.prepareBackground();
          await MusicShareBackgroundPlatform.setLoginEnabled(true);
          sharing = true;
          await MusicShareConnectionStore.writeHost(_hostConfiguration);
        }
        await _startSharingHost();
      } else {
        if (backgroundSharing) {
          await aiAgentRemoteController.restoreForeground();
        }
        await server.stop();
        if (MusicShareBackgroundPlatform.supported &&
            await MusicShareBackgroundPlatform.available()) {
          await MusicShareBackgroundPlatform.setLoginEnabled(false);
        }
        server = _localHost(
          await repository.queryLibrary(
            const LibraryDataQuery(LibraryQueryKind.context),
          ),
        );
      }
      sharing = enabled;
      await _persistHostSettings();
    } catch (error, stack) {
      sharing = previousSharing;
      if (backgroundSharing) {
        await MusicShareConnectionStore.writeHost(_hostConfiguration);
        final awaitingApproval =
            error is PlatformException &&
            error.code == 'background_approval_required';
        if (!awaitingApproval) {
          await MusicShareBackgroundPlatform.setLoginEnabled(previousSharing);
        }
        if (previousSharing) {
          await aiAgentRemoteController.prepareBackground();
          if (!server.running) {
            server = await _connectBackgroundHost();
          } else {
            await aiAgentRemoteController.attachBackground(
              server as MusicShareBackgroundHost,
            );
          }
        } else {
          await aiAgentRemoteController.restoreForeground();
        }
      } else {
        if (!previousSharing && server.running) await server.stop();
        if (previousSharing && !server.running) await server.start(port: port);
        await _persistHostSettings();
      }
      Error.throwWithStackTrace(error, stack);
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> _setBackgroundSharing(bool enabled) async {
    if (enabled == backgroundSharing) return;
    updatingBackgroundSharing = true;
    _notify();
    final previous = server;
    final original = backgroundSharing;
    try {
      if (enabled) {
        // Registration must succeed before handing away the working listener.
        await MusicShareBackgroundPlatform.setLoginEnabled(true);
        await aiAgentRemoteController.prepareBackground();
        await previous.stop();
        await MusicShareConnectionStore.writeHost({
          ..._hostConfiguration,
          'backgroundSharing': true,
        });
        server = await _connectBackgroundHost();
      } else {
        await aiAgentRemoteController.restoreForeground();
        await (previous as MusicShareBackgroundHost).handoff();
        await MusicShareBackgroundPlatform.setLoginEnabled(false);
        server = _localHost(
          await repository.queryLibrary(
            const LibraryDataQuery(LibraryQueryKind.context),
          ),
        );
        await server.start(port: port);
      }
      backgroundSharing = enabled;
      await _persistHostSettings();
    } catch (error, stack) {
      SystemLog.error('Sharing host handoff failed', error, stack);
      backgroundSharing = original;
      if (!original) {
        final awaitingApproval =
            error is PlatformException &&
            error.code == 'background_approval_required';
        if (!awaitingApproval) {
          await MusicShareBackgroundPlatform.setLoginEnabled(false);
        }
        await MusicShareBackgroundPlatform.stop();
        await aiAgentRemoteController.restoreForeground();
        await MusicShareConnectionStore.writeHost(_hostConfiguration);
        server = previous;
        if (sharing && !previous.running) await previous.start(port: port);
      } else {
        if (server is MusicShareServer) await server.stop();
        await aiAgentRemoteController.prepareBackground();
        await MusicShareConnectionStore.writeHost(_hostConfiguration);
        await MusicShareBackgroundPlatform.setLoginEnabled(true);
        server = await _connectBackgroundHost();
      }
      rethrow;
    } finally {
      updatingBackgroundSharing = false;
      _notify();
    }
  }

  Future<T> _withSharingSuspended<T>(Future<T> Function() operation) async {
    await startup;
    final resume = sharing;
    busy = true;
    _notify();
    try {
      if (server.running) {
        if (server case final MusicShareBackgroundHost host) {
          await host.suspend();
        } else {
          await server.stop();
        }
      }
      return await operation();
    } finally {
      try {
        if (resume) {
          await _syncSharingConfiguration();
          if (!server.running) await server.start(port: port);
        }
      } catch (error, stack) {
        // A successful import remains successful if resuming sharing fails.
        hostFailure = (error: error, stack: stack);
        SystemLog.error(
          'Resuming music sharing after database operation failed',
          error,
          stack,
        );
      } finally {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> _syncSharingConfiguration() async {
    if (!initialized) return;
    final library = await repository.queryLibrary(
      const LibraryDataQuery(LibraryQueryKind.context),
    );
    databasePath = library.databasePath;
    if (server case final MusicShareBackgroundHost host) {
      await host.configure(
        name: name,
        port: port,
        databasePath: databasePath,
        rootPath: library.rootPath,
      );
    } else {
      server.updateLibrary(library);
    }
  }

  Future<void> _setHostName(String value) async {
    final previous = name;
    try {
      if (server case final MusicShareBackgroundHost host) {
        await host.configure(
          name: value,
          port: port,
          databasePath: databasePath,
        );
      }
      name = value;
      await _persistHostSettings();
    } catch (_) {
      name = previous;
      rethrow;
    }
  }

  Future<void> _setPort(int value) async {
    busy = true;
    _notify();
    final previous = port;
    try {
      if (server.running) await server.changePort(value);
      port = value;
      try {
        await _persistHostSettings();
      } catch (_) {
        port = previous;
        if (server.running) await server.changePort(previous);
        rethrow;
      }
    } finally {
      busy = false;
      _notify();
    }
  }
}
