import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/system_log.dart';
import 'music_share_identity.dart';
import 'music_share_controller.dart';
import 'music_share_models.dart';
import 'music_source_providers.dart';

class RemoteDirectoryIndex {
  RemoteDirectoryIndex(Map<String, dynamic> data)
    : folders = (data['folders'] as List).cast<String>(),
      songFolders = (data['songs'] as Map).cast<String, String>(),
      catalog =
          (data['catalog'] as List)
              .map((song) => (song as Map).cast<String, dynamic>())
              .toList();

  final List<Map<String, dynamic>> catalog;
  final List<String> folders;
  final Map<String, String> songFolders;
}

// This request depends only on the device, not on connection notifications or
// the local library snapshot. Rebuilding the page does not restart the request.
final remoteDirectoryProvider = FutureProvider.autoDispose
    .family<RemoteDirectoryIndex, String>((ref, device) async {
      final share = ref.read(musicShareProvider);
      await share.ready;
      final peer = share.peers.firstWhere((peer) => peer.id == device);
      final transport = MusicShareTransport(
        peer.address,
        fingerprint: peer.fingerprint,
        token: peer.token,
      );
      var active = true;
      ref.onDispose(() {
        active = false;
        transport.close();
      });
      try {
        SystemLog.info('Remote directory request started: device=${peer.name}');
        final directory = RemoteDirectoryIndex(
          await transport.json('/directories'),
        );
        await share.applyPageCatalog(
          device,
          directory.catalog,
          isCurrent: () => active,
        );
        return directory;
      } on MusicShareException catch (error, stack) {
        SystemLog.error(
          'Remote directory request failed: device=${peer.name}',
          error,
          stack,
        );
        if (error.httpStatusCode == 404) {
          throw const MusicShareException('share.directoryUpgradeRequired');
        }
        rethrow;
      } finally {
        transport.close();
      }
    });
