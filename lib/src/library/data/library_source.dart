sealed class LibrarySource {
  const LibrarySource();

  factory LibrarySource.fromPath(String path) {
    if (!path.startsWith('smplayer-music://')) {
      return const LocalLibrarySource();
    }
    return RemoteLibrarySource(Uri.parse(path).host);
  }

  factory LibrarySource.fromDevice(String device) =>
      device == 'local'
          ? const LocalLibrarySource()
          : RemoteLibrarySource(device);
}

final class LocalLibrarySource extends LibrarySource {
  const LocalLibrarySource();

  @override
  bool operator ==(Object other) => other is LocalLibrarySource;
  @override
  int get hashCode => runtimeType.hashCode;
}

final class RemoteLibrarySource extends LibrarySource {
  const RemoteLibrarySource(this.deviceId);
  final String deviceId;
  String get rootPath => 'smplayer-music://$deviceId/0';

  @override
  bool operator ==(Object other) =>
      other is RemoteLibrarySource && other.deviceId == deviceId;
  @override
  int get hashCode => Object.hash(RemoteLibrarySource, deviceId);
}
