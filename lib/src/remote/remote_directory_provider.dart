import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/system_log.dart';
import 'music_share_identity.dart';
import 'music_share_models.dart';
import 'music_source_providers.dart';

class RemoteDirectoryIndex {
  RemoteDirectoryIndex(Map<String, dynamic> data)
    : rootName = data['rootName'] as String,
      folders = (data['folders'] as List).cast<String>(),
      folderInfo = (data['folderInfo'] as Map).cast<String, dynamic>();

  final String rootName;
  final List<String> folders;
  final Map<String, dynamic> folderInfo;
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
      ref.onDispose(transport.close);
      try {
        SystemLog.info('Remote directory request started: device=${peer.name}');
        final data = await transport.json('/directories');
        if (!data.containsKey('rootName') || !data.containsKey('folderInfo')) {
          throw const MusicShareException('share.directoryUpgradeRequired');
        }
        final directory = RemoteDirectoryIndex(data);
        SystemLog.info(
          'Remote directory loaded: device=${peer.name}; '
          'folders=${directory.folders.length}',
        );
        return directory;
      } catch (error, stack) {
        SystemLog.error(
          'Remote directory request failed: device=${peer.name}',
          error,
          stack,
        );
        if (error is MusicShareException && error.httpStatusCode == 404) {
          throw const MusicShareException('share.directoryUpgradeRequired');
        }
        rethrow;
      } finally {
        transport.close();
      }
    });

Future<RemoteDirectoryIndex> readRemoteDirectory(
  ProviderContainer container,
  String device,
) async {
  final subscription = container.listen(
    remoteDirectoryProvider(device),
    (_, _) {},
  );
  try {
    return await container.read(remoteDirectoryProvider(device).future);
  } finally {
    subscription.close();
  }
}
