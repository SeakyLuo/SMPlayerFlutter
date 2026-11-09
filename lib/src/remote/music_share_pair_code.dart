class MusicSharePairCode {
  const MusicSharePairCode(this.address, this.fingerprint);

  final String address;
  final String fingerprint;

  String encode() =>
      Uri(
        scheme: 'smplayer-music-pair',
        host: 'connect',
        queryParameters: {
          'v': '1',
          'address': address,
          'fingerprint': fingerprint,
        },
      ).toString();

  static MusicSharePairCode? parse(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'smplayer-music-pair' ||
        uri.host != 'connect' ||
        uri.path.isNotEmpty ||
        uri.queryParameters['v'] != '1') {
      return null;
    }
    final address = uri.queryParameters['address'];
    final fingerprint = uri.queryParameters['fingerprint'];
    if (address == null ||
        fingerprint == null ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(fingerprint)) {
      return null;
    }
    final host = Uri.tryParse(address);
    if (host == null ||
        host.scheme != 'https' ||
        host.host.isEmpty ||
        host.userInfo.isNotEmpty ||
        host.hasQuery ||
        host.hasFragment ||
        (host.path.isNotEmpty && host.path != '/')) {
      return null;
    }
    return MusicSharePairCode(address, fingerprint);
  }
}
